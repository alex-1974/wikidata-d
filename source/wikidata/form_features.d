/**
 * M5.7: Retrieve grammatical features for existing Wikidata Form candidates.
 * Evidence only. This module does NOT promote any Form hit to a catalogue
 * Lexeme match and never changes the source catalogue or M5.5/M5.6 reports.
 */
module wikidata.form_features;

import std.algorithm.searching : canFind, startsWith;
import std.exception : enforce;
import std.json : JSONValue, JSONType, parseJSON;
import wikidata.form_lookup : isFormId;
import wikidata.query : isEntityId;

struct FormFeatureRecord
{
    string formId;
    string[] featureIds;
}

/// Fetch existing Forms and all their available Wikidata grammatical features.
string buildFormFeatureQuery(const(string)[] formIds)
{
    enforce(formIds.length > 0 && formIds.length <= 30,
        "Form feature batch size must be 1..30");
    string query =
        "PREFIX wd: <http://www.wikidata.org/entity/>\n"
        ~ "PREFIX wikibase: <http://wikiba.se/ontology#>\n"
        ~ "PREFIX ontolex: <http://www.w3.org/ns/lemon/ontolex#>\n"
        ~ "SELECT DISTINCT ?form ?feature WHERE {\n"
        ~ "  VALUES ?form {\n";
    string[] seen;
    foreach (formId; formIds)
    {
        enforce(isFormId(formId), "Invalid Form ID");
        if (!seen.canFind(formId))
        {
            seen ~= formId;
            query ~= "    wd:" ~ formId ~ "\n";
        }
    }
    query ~= "  }\n"
        ~ "  ?lexeme ontolex:lexicalForm ?form .\n"
        ~ "  OPTIONAL { ?form wikibase:grammaticalFeature ?feature . }\n"
        ~ "}\n";
    return query;
}

private string bindingId(JSONValue row, string key, bool optional = false)
{
    enforce(row.type == JSONType.object, "Invalid SPARQL binding row");
    auto term = key in row.object;
    if (term is null && optional)
        return "";
    enforce(term !is null && (*term).type == JSONType.object,
        "Missing SPARQL binding: " ~ key);
    auto value = "value" in (*term).object;
    enforce(value !is null && (*value).type == JSONType.string,
        "Invalid SPARQL binding: " ~ key);
    auto uri = (*value).str;
    enum http = "http://www.wikidata.org/entity/";
    enum https = "https://www.wikidata.org/entity/";
    if (uri.startsWith(http)) return uri[http.length .. $];
    if (uri.startsWith(https)) return uri[https.length .. $];
    throw new Exception("Unexpected entity URI: " ~ uri);
}

/** All requested Form IDs must exist. A missing Form is an error, not evidence
 * of a form having no grammatical features.
 */
FormFeatureRecord[] parseFormFeatureResponse(JSONValue response,
    const(string)[] requestedFormIds)
{
    enforce(response.type == JSONType.object, "Invalid query response");
    auto results = "results" in response.object;
    enforce(results !is null && (*results).type == JSONType.object,
        "Missing results object");
    auto bindings = "bindings" in (*results).object;
    enforce(bindings !is null && (*bindings).type == JSONType.array,
        "Missing bindings array");
    FormFeatureRecord[] outRecords;
    foreach (row; (*bindings).array)
    {
        auto formId = bindingId(row, "form");
        enforce(isFormId(formId) && requestedFormIds.canFind(formId),
            "Unexpected Form ID returned");
        size_t idx = outRecords.length;
        foreach (i, record; outRecords)
            if (record.formId == formId) { idx = i; break; }
        if (idx == outRecords.length)
        {
            FormFeatureRecord fresh;
            fresh.formId = formId;
            outRecords ~= fresh;
        }
        auto feature = bindingId(row, "feature", true);
        if (feature.length)
        {
            enforce(isEntityId(feature) && feature[0] == 'Q',
                "Invalid Wikidata grammatical feature");
            if (!outRecords[idx].featureIds.canFind(feature))
                outRecords[idx].featureIds ~= feature;
        }
    }
    foreach (requested; requestedFormIds)
    {
        bool found;
        foreach (record; outRecords)
            if (record.formId == requested) { found = true; break; }
        enforce(found, "Form not found in feature response: " ~ requested);
    }
    return outRecords;
}

/// Produce a separate report; M5.6 remains unmodified on disk.
JSONValue buildFormFeatureReport(JSONValue formCandidatesReport,
    const(FormFeatureRecord)[] featureRecords)
{
    enforce(formCandidatesReport.type == JSONType.object,
        "Invalid M5.6 report");
    auto rows = "entries" in formCandidatesReport.object;
    enforce(rows !is null && (*rows).type == JSONType.array,
        "M5.6 report has no entries");
    // Construct new JSON values, never mutate the source report.
    JSONValue outRows = JSONValue.emptyArray;
    long entryCount;
    long candidateCount;
    long featureCount;
    foreach (row; (*rows).array)
    {
        JSONValue outRow = JSONValue.emptyObject;
        outRow["catalogEntryId"] = row["catalogEntryId"].str;
        outRow["lemma"] = row["lemma"].str;
        JSONValue outCandidates = JSONValue.emptyArray;
        foreach (candidate; row["candidates"].array)
        {
            string formId = candidate["formId"].str;
            const(FormFeatureRecord)* found = null;
            foreach (ref record; featureRecords)
                if (record.formId == formId)
                {
                    found = &record;
                    break;
                }
            enforce(found !is null,
                "Missing feature evidence for Form: " ~ formId);
            JSONValue outCandidate = JSONValue.emptyObject;
            outCandidate["word"] = candidate["word"].str;
            outCandidate["lexemeId"] = candidate["lexemeId"].str;
            outCandidate["formId"] = formId;
            outCandidate["lemma"] = candidate["lemma"].str;
            outCandidate["lexicalCategoryId"] =
                candidate["lexicalCategoryId"].str;
            JSONValue features = JSONValue.emptyArray;
            foreach (feature; (*found).featureIds)
                features.array ~= JSONValue(feature);
            outCandidate["grammaticalFeatureIds"] = features;
            outCandidate["reviewStatus"] = "pending";
            outCandidates.array ~= outCandidate;
            ++candidateCount;
            if (features.array.length) ++featureCount;
        }
        if (outCandidates.array.length) ++entryCount;
        outRow["candidates"] = outCandidates;
        outRows.array ~= outRow;
    }
    JSONValue report = JSONValue.emptyObject;
    report["schemaVersion"] = 1;
    report["catalogId"] = formCandidatesReport["catalogId"].str;
    report["sourceReport"] = "M5.6-form-candidates";
    JSONValue summary = JSONValue.emptyObject;
    summary["entriesWithCandidates"] = entryCount;
    summary["formCandidates"] = candidateCount;
    summary["candidatesWithFeatures"] = featureCount;
    summary["confirmedLexemeMatchesAdded"] = 0;
    report["summary"] = summary;
    report["entries"] = outRows;
    return report;
}

unittest
{
    import std.exception : assertThrown;
    auto query = buildFormFeatureQuery(["L8366-F10", "L21271-F3"]);
    assert(query.canFind("wd:L8366-F10"));
    assert(query.canFind("wikibase:grammaticalFeature"));
    assert(query.canFind("?lexeme ontolex:lexicalForm ?form"));
    assert(!query.canFind("?form a wikibase:Form"));
    auto answer = parseJSON(`{"results":{"bindings":[
      {"form":{"value":"http://www.wikidata.org/entity/L8366-F10"},
       "feature":{"value":"http://www.wikidata.org/entity/Q146786"}},
      {"form":{"value":"http://www.wikidata.org/entity/L8366-F10"},
       "feature":{"value":"http://www.wikidata.org/entity/Q146786"}},
      {"form":{"value":"http://www.wikidata.org/entity/L21271-F3"}}
    ]}}`);
    auto found = parseFormFeatureResponse(answer,
        ["L8366-F10", "L21271-F3"]);
    assert(found.length == 2);
    assert(found[0].featureIds.length == 1);
    assert(found[1].featureIds.length == 0);
    auto before = parseJSON(`{"catalogId":"it-A1-test","entries":[
      {"catalogEntryId":"1","lemma":"gli","candidates":[
        {"word":"gli","lexemeId":"L8366","formId":"L8366-F10",
         "lemma":"il","lexicalCategoryId":"Q2865743"}]}
    ]}`);
    auto report = buildFormFeatureReport(before, found);
    assert(report["summary"]["confirmedLexemeMatchesAdded"].integer == 0);
    assert(report["entries"].array[0]["candidates"].array[0]
        ["grammaticalFeatureIds"].array.length == 1);
    assert(("reviewStatus" in before["entries"].array[0]["candidates"].array[0].object) is null);
    assertThrown!Exception(parseFormFeatureResponse(
        parseJSON(`{"results":{"bindings":[]}}`), ["L8366-F10"]));
}
