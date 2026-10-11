/**
 * M5.6: Discover Wikidata Form representations for unresolved catalogue words.
 * Form hits are *candidates*, never automatic Lexeme or Sense matches.
 * The source catalogue and the M5.5 coverage report remain unchanged.
 */
module wikidata.form_lookup;

import std.algorithm.searching : canFind, startsWith;
import std.exception : enforce;
import std.json : JSONType, JSONValue, parseJSON;
import wikidata.catalog : VocabularyCatalog;
import wikidata.query : isEntityId, sparqlString;

struct FormCandidate
{
    string word;                /// Exact requested representation.
    string lexemeId;            /// Owning Lexeme.
    string formId;              /// Form subentity, e.g. L123-F2.
    string lemma;               /// Canonical Wikidata lemma, not source lemma.
    string lexicalCategoryId;   /// Wikidata POS; not yet validated against catalogue.
}

/// Validate a Wikidata Form subentity identifier.
bool isFormId(string id)
{
    if (id.length < 5 || id[0] != 'L') return false;
    size_t index = 1;
    while (index < id.length && id[index] >= '0' && id[index] <= '9')
        ++index;
    if (index + 2 >= id.length || id[index] != '-' || id[index + 1] != 'F')
        return false;
    if (!isEntityId(id[0 .. index])) return false;
    index += 2;
    if (id[index] < '1' || id[index] > '9') return false;
    for (++index; index < id.length; ++index)
        if (id[index] < '0' || id[index] > '9') return false;
    return true;
}

/**
 * Search exact language-tagged Form representations. Do not constrain POS
 * at query time: the catalog's absence may stem from category differences.
 * Query only bounded, distinct batches. Other lexemes may share a Form string.
 */
string buildFormLookupQuery(string languageCode, string languageEntityId,
    const(string)[] words)
{
    enforce(words.length >= 1 && words.length <= 25,
        "Form query batch size must be 1..25");
    enforce(isEntityId(languageEntityId) && languageEntityId[0] == 'Q',
        "Invalid language Q-ID");
    enforce(languageCode.length >= 2 && languageCode.length <= 20,
        "Invalid language code length");
    foreach (char ch; languageCode)
        enforce((ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') ||
            ch == '-', "Invalid language code");
    string sparql =
        "PREFIX wd: <http://www.wikidata.org/entity/>\n"
        ~ "PREFIX ontolex: <http://www.w3.org/ns/lemon/ontolex#>\n"
        ~ "PREFIX dct: <http://purl.org/dc/terms/>\n"
        ~ "PREFIX wikibase: <http://wikiba.se/ontology#>\n"
        ~ "SELECT DISTINCT ?word ?lexeme ?form ?lemma ?category WHERE {\n"
        ~ "  VALUES ?word {\n";
    foreach (word; words)
    {
        enforce(word.length != 0, "Empty Form search string");
        sparql ~= "    " ~ sparqlString(word) ~ "@" ~ languageCode ~ "\n";
    }
    sparql ~= "  }\n"
        ~ "  ?lexeme dct:language wd:" ~ languageEntityId ~ " ;\n"
        ~ "    wikibase:lemma ?lemma ;\n"
        ~ "    wikibase:lexicalCategory ?category ;\n"
        ~ "    ontolex:lexicalForm ?form .\n"
        ~ "  ?form ontolex:representation ?word .\n"
        ~ "}\n";
    return sparql;
}

private string bindingString(JSONValue row, string key)
{
    enforce(row.type == JSONType.object, "Invalid binding row");
    auto term = key in row.object;
    enforce(term !is null && (*term).type == JSONType.object,
        "Missing binding: " ~ key);
    auto value = "value" in (*term).object;
    enforce(value !is null && (*value).type == JSONType.string,
        "Invalid binding: " ~ key);
    return (*value).str;
}

private string wikidataId(string uri)
{
    enum http = "http://www.wikidata.org/entity/";
    enum https = "https://www.wikidata.org/entity/";
    if (uri.startsWith(http)) return uri[http.length .. $];
    if (uri.startsWith(https)) return uri[https.length .. $];
    throw new Exception("Unexpected Wikidata entity URI: " ~ uri);
}

/// Parse strictly: errors must not be silently turned into empty search results.
FormCandidate[] parseFormLookupResponse(JSONValue response,
    const(string)[] requestedWords)
{
    enforce(response.type == JSONType.object, "Invalid SPARQL response");
    auto results = "results" in response.object;
    enforce(results !is null && (*results).type == JSONType.object,
        "Missing SPARQL results");
    auto bindings = "bindings" in (*results).object;
    enforce(bindings !is null && (*bindings).type == JSONType.array,
        "Missing SPARQL bindings");
    FormCandidate[] candidates;
    foreach (row; (*bindings).array)
    {
        FormCandidate candidate;
        candidate.word = bindingString(row, "word");
        enforce(requestedWords.canFind(candidate.word),
            "Form result not present in query batch");
        candidate.lexemeId = wikidataId(bindingString(row, "lexeme"));
        candidate.formId = wikidataId(bindingString(row, "form"));
        candidate.lemma = bindingString(row, "lemma");
        candidate.lexicalCategoryId = wikidataId(bindingString(row, "category"));
        enforce(isEntityId(candidate.lexemeId) && candidate.lexemeId[0] == 'L',
            "Invalid owning Lexeme ID");
        enforce(isFormId(candidate.formId), "Invalid Form ID");
        enforce(candidate.formId.startsWith(candidate.lexemeId ~ "-F"),
            "Form does not belong to returned Lexeme");
        enforce(isEntityId(candidate.lexicalCategoryId) &&
            candidate.lexicalCategoryId[0] == 'Q', "Invalid category ID");
        bool duplicate = false;
        foreach (earlier; candidates)
            if (earlier.word == candidate.word &&
                earlier.formId == candidate.formId)
            {
                duplicate = true;
                break;
            }
        if (!duplicate)
            candidates ~= candidate;
    }
    return candidates;
}

/**
 * Enrich ONLY unresolved records from a separate M5.5 report with Form
 * candidates. This is a supplementary report, not changed coverage numbers.
 */
JSONValue buildFormCandidatesReport(ref const VocabularyCatalog catalog,
    JSONValue categoryCoverage, const(FormCandidate)[] candidates)
{
    enforce(categoryCoverage.type == JSONType.object,
        "Invalid category coverage report");
    auto entryRows = categoryCoverage["entries"];
    enforce(entryRows.type == JSONType.array &&
        entryRows.array.length == catalog.entries.length,
        "M5.5 report/catalog length mismatch");
    enforce(categoryCoverage["catalogId"].str == catalog.id,
        "M5.5 report/catalog ID mismatch");

    JSONValue rows = JSONValue.emptyArray;
    size_t unresolved;
    size_t withForms;
    foreach (i, entry; catalog.entries)
    {
        auto old = entryRows.array[i];
        enforce(old["catalogEntryId"].str == entry.id,
            "M5.5 report/catalog entry ordering mismatch");
        if (old["status"].str != "noMatch") continue;
        ++unresolved;
        JSONValue row = JSONValue.emptyObject;
        row["catalogEntryId"] = entry.id;
        row["lemma"] = entry.lemma;
        row["previousStatus"] = "noMatch";
        JSONValue hits = JSONValue.emptyArray;
        foreach (candidate; candidates)
        {
            bool requested = false;
            foreach (target; entry.lookupTargets)
                if (target.lemma == candidate.word)
                {
                    requested = true;
                    break;
                }
            if (!requested) continue;
            JSONValue hit = JSONValue.emptyObject;
            hit["word"] = candidate.word;
            hit["lexemeId"] = candidate.lexemeId;
            hit["formId"] = candidate.formId;
            hit["lemma"] = candidate.lemma;
            hit["lexicalCategoryId"] = candidate.lexicalCategoryId;
            hit["matchMethod"] = "formCandidate";
            hits.array ~= hit;
        }
        if (hits.array.length != 0) ++withForms;
        row["candidates"] = hits;
        rows.array ~= row;
    }
    JSONValue outJson = JSONValue.emptyObject;
    outJson["schemaVersion"] = 1;
    outJson["catalogId"] = catalog.id;
    outJson["sourceCoverage"] = "M5.5";
    JSONValue totals = JSONValue.emptyObject;
    totals["unresolvedEntries"] = cast(long) unresolved;
    totals["entriesWithFormCandidates"] = cast(long) withForms;
    totals["entriesWithoutFormCandidates"] = cast(long) (unresolved - withForms);
    outJson["summary"] = totals;
    outJson["entries"] = rows;
    return outJson;
}

unittest
{
    import wikidata.catalog : parseCatalog;
    import std.exception : assertThrown;
    assert(isFormId("L5577-F1"));
    assert(!isFormId("L5577-S1"));
    assert(!isFormId("L0-F2"));
    auto query = buildFormLookupQuery("it", "Q652", ["gli", "la"]);
    assert(query.canFind("\"gli\"@it"));
    assert(query.canFind("ontolex:lexicalForm ?form"));
    assert(query.canFind("ontolex:representation ?word"));
    enum answer = `{"results":{"bindings":[
      {"word":{"value":"gli"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L100"},
       "form":{"value":"http://www.wikidata.org/entity/L100-F2"},
       "lemma":{"value":"il"},
       "category":{"value":"http://www.wikidata.org/entity/Q103184"}}
    ]}}`;
    auto candidates = parseFormLookupResponse(parseJSON(answer), ["gli"]);
    assert(candidates.length == 1);
    assert(candidates[0].formId == "L100-F2");
    assert(candidates[0].lemma == "il");
    auto catalog = parseCatalog(`{"schemaVersion":1,"id":"it-A1-test",
      "languageCode":"it","languageEntityId":"Q652","level":"A1",
      "source":{},"entries":[
      {"id":"1","lemma":"gli","lexicalCategoryId":"Q103184"},
      {"id":"2","lemma":"gatto","lexicalCategoryId":"Q1084"}]}`);
    auto previous = parseJSON(`{"catalogId":"it-A1-test","entries":[
      {"catalogEntryId":"1","status":"noMatch"},
      {"catalogEntryId":"2","status":"matched"}]}`);
    auto result = buildFormCandidatesReport(catalog, previous, candidates);
    assert(result["entries"].array.length == 1);
    assert(result["summary"]["unresolvedEntries"].integer == 1);
    assert(result["summary"]["entriesWithFormCandidates"].integer == 1);
    assert(result["entries"].array[0]["candidates"].array[0]["formId"].str
        == "L100-F2");
    assertThrown!Exception(parseFormLookupResponse(parseJSON(answer), ["la"]));
}
