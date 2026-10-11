/**
 * Exact catalogue-to-Wikidata Lexeme candidate matching.
 * Query results do not alter the catalogue and do not assign A1 to Senses.
 */
module wikidata.catalog_matcher;

import std.algorithm.searching : canFind, startsWith;
import std.exception : enforce;
import std.json : JSONValue, JSONType, parseJSON;
import wikidata.catalog : VocabularyCatalog;
import wikidata.lexical_categories : CategoryCompatibility;
import wikidata.query : buildLexemeQuery, isEntityId;
import wikidata.relations : isSenseId;

struct CatalogLookupBatch
{
    string[] lemmas;
    string sparql;
}

struct LexemeCandidate
{
    string lexemeId;
    string lexicalCategoryId;
    string[] senseIds;
    string matchMethod; // "exact" or "subclass"; empty in legacy callers
}

enum CatalogMatchStatus { noMatch, matched, multipleCandidates }

struct CatalogMatch
{
    string catalogEntryId;
    CatalogMatchStatus status;
    LexemeCandidate[] candidates;
}

/// Deduplicate lookup spellings without discarding any catalogue entries.
CatalogLookupBatch[] buildCatalogLookupBatches(
    ref const VocabularyCatalog catalog, size_t batchSize = 20)
{
    enforce(batchSize >= 1 && batchSize <= 100, "Batch size must be 1..100");
    bool[string] seen;
    string[] lemmas;
    foreach (entry; catalog.entries)
        foreach (target; entry.lookupTargets)
            if ((target.lemma in seen) is null)
            {
                seen[target.lemma] = true;
                lemmas ~= target.lemma;
            }
    CatalogLookupBatch[] batches;
    for (size_t begin = 0; begin < lemmas.length; begin += batchSize)
    {
        size_t end = begin + batchSize;
        if (end > lemmas.length)
            end = lemmas.length;
        auto part = lemmas[begin .. end].dup;
        batches ~= CatalogLookupBatch(part,
            buildLexemeQuery(catalog.languageCode,
                catalog.languageEntityId, part));
    }
    return batches;
}

private string bindingValue(JSONValue row, string key, bool optional = false)
{
    enforce(row.type == JSONType.object, "Invalid result binding row");
    auto term = key in row.object;
    if (term is null && optional)
        return "";
    enforce(term !is null && (*term).type == JSONType.object,
        "Missing binding: " ~ key);
    auto value = "value" in (*term).object;
    enforce(value !is null && (*value).type == JSONType.string,
        "Invalid binding: " ~ key);
    return (*value).str;
}

private string entityId(string uri)
{
    enum http = "http://www.wikidata.org/entity/";
    enum https = "https://www.wikidata.org/entity/";
    if (uri.startsWith(http))
        return uri[http.length .. $];
    if (uri.startsWith(https))
        return uri[https.length .. $];
    throw new Exception("Invalid Wikidata entity URI: " ~ uri);
}

private struct SearchHit
{
    string lemma;
    LexemeCandidate candidate;
}

/**
 * One successful SPARQL response is required for every generated batch.
 * A network error must abort the caller, never be treated as a missing word.
 * A source entry with no candidates is retained with `noMatch`.
 */
CatalogMatch[] matchCatalog(
    ref const VocabularyCatalog catalog,
    const(CatalogLookupBatch)[] batches,
    JSONValue[] responses)
{
    CategoryCompatibility empty;
    return matchCatalogWithCategories(catalog, batches, responses, empty);
}

/// Match with explicit P279 subclass relations retrieved from Wikidata.
CatalogMatch[] matchCatalogWithCategories(
    ref const VocabularyCatalog catalog,
    const(CatalogLookupBatch)[] batches,
    JSONValue[] responses,
    ref const CategoryCompatibility categories)
{
    enforce(batches.length == responses.length,
        "One complete response is required per query batch");
    SearchHit[] hits;
    foreach (n, response; responses)
    {
        enforce(response.type == JSONType.object, "Invalid SPARQL response");
        auto results = "results" in response.object;
        enforce(results !is null && (*results).type == JSONType.object,
            "Missing SPARQL results");
        auto bindings = "bindings" in (*results).object;
        enforce(bindings !is null && (*bindings).type == JSONType.array,
            "Missing SPARQL bindings");
        foreach (row; (*bindings).array)
        {
            SearchHit hit;
            hit.lemma = bindingValue(row, "lemma");
            enforce(batches[n].lemmas.canFind(hit.lemma),
                "Result lemma not requested by this batch");
            hit.candidate.lexemeId = entityId(bindingValue(row, "lexeme"));
            hit.candidate.lexicalCategoryId = entityId(
                bindingValue(row, "category"));
            auto sense = bindingValue(row, "sense", true);
            if (sense.length)
                hit.candidate.senseIds = [entityId(sense)];
            enforce(isEntityId(hit.candidate.lexemeId) &&
                hit.candidate.lexemeId[0] == 'L', "Invalid Lexeme ID");
            enforce(isEntityId(hit.candidate.lexicalCategoryId) &&
                hit.candidate.lexicalCategoryId[0] == 'Q', "Invalid POS ID");
            if (hit.candidate.senseIds.length)
                enforce(isSenseId(hit.candidate.senseIds[0]),
                    "Invalid Sense ID");
            hits ~= hit;
        }
    }

    CatalogMatch[] matches;
    foreach (entry; catalog.entries)
    {
        CatalogMatch match;
        match.catalogEntryId = entry.id;
        foreach (hit; hits)
        {
            // POS restrictions apply to each lookup variant independently.
            // Do not discard the source entry if one variant is unmatched.
            bool targetMatches = false;
            string matchMethod;
            foreach (target; entry.lookupTargets)
            {
                if (target.lemma != hit.lemma)
                    continue;
                bool exact = target.lexicalCategoryId.length == 0 ||
                    target.lexicalCategoryId == hit.candidate.lexicalCategoryId;
                if (exact)
                {
                    targetMatches = true;
                    matchMethod = "exact";
                    break;
                }
                if (categories.compatible(hit.candidate.lexicalCategoryId,
                    target.lexicalCategoryId))
                {
                    targetMatches = true;
                    matchMethod = "subclass";
                }
            }
            if (!targetMatches)
                continue;
            size_t index = match.candidates.length;
            foreach (i, candidate; match.candidates)
                if (candidate.lexemeId == hit.candidate.lexemeId)
                {
                    index = i;
                    break;
                }
            if (index == match.candidates.length)
            {
                auto added = hit.candidate;
                added.matchMethod = matchMethod;
                match.candidates ~= added;
            }
            else
            {
                if (matchMethod == "exact")
                    match.candidates[index].matchMethod = "exact";
                foreach (sense; hit.candidate.senseIds)
                    if (!match.candidates[index].senseIds.canFind(sense))
                        match.candidates[index].senseIds ~= sense;
            }
        }
        if (match.candidates.length == 1)
            match.status = CatalogMatchStatus.matched;
        else if (match.candidates.length > 1)
            match.status = CatalogMatchStatus.multipleCandidates;
        else
            match.status = CatalogMatchStatus.noMatch;
        matches ~= match;
    }
    return matches;
}

unittest
{
    import wikidata.catalog : parseCatalog;
    import std.exception : assertThrown;
    auto catalog = parseCatalog(`{
      "schemaVersion":1,"id":"it-A1-test","languageCode":"it",
      "languageEntityId":"Q652","level":"A1","source":{},
      "entries":[
        {"id":"1","lemma":"nero","lexicalCategoryId":"Q34698"},
        {"id":"2","lemma":"nero","lexicalCategoryId":"Q1084"},
        {"id":"3","lemma":"gatto","lexicalCategoryId":"Q1084"},
        {"id":"4","lemma":"absent","lexicalCategoryId":"Q1084"}
      ]}`);
    auto batches = buildCatalogLookupBatches(catalog, 2);
    assert(batches.length == 2);
    assert(batches[0].lemmas.length == 2);
    assert(batches[0].lemmas[0] == "nero");
    assert(batches[0].lemmas[1] == "gatto");
    enum first = `{"results":{"bindings":[
      {"lemma":{"value":"nero"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L711417"},
       "category":{"value":"http://www.wikidata.org/entity/Q34698"},
       "sense":{"value":"http://www.wikidata.org/entity/L711417-S1"}},
      {"lemma":{"value":"nero"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L1219303"},
       "category":{"value":"http://www.wikidata.org/entity/Q1084"},
       "sense":{"value":"http://www.wikidata.org/entity/L1219303-S1"}},
      {"lemma":{"value":"nero"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L1219303"},
       "category":{"value":"http://www.wikidata.org/entity/Q1084"},
       "sense":{"value":"http://www.wikidata.org/entity/L1219303-S2"}},
      {"lemma":{"value":"gatto"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L5577"},
       "category":{"value":"http://www.wikidata.org/entity/Q1084"},
       "sense":{"value":"http://www.wikidata.org/entity/L5577-S1"}},
      {"lemma":{"value":"gatto"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L5577"},
       "category":{"value":"http://www.wikidata.org/entity/Q1084"},
       "sense":{"value":"http://www.wikidata.org/entity/L5577-S2"}}
    ]}}`;
    JSONValue[] answers = [parseJSON(first),
        parseJSON(`{"results":{"bindings":[]}}`)];
    auto mappings = matchCatalog(catalog, batches, answers);
    assert(mappings.length == 4); // The reference catalogue was not filtered.
    assert(mappings[0].status == CatalogMatchStatus.matched);
    assert(mappings[0].candidates[0].lexemeId == "L711417");
    assert(mappings[1].candidates[0].lexemeId == "L1219303");
    assert(mappings[1].candidates[0].senseIds.length == 2);
    assert(mappings[2].candidates[0].senseIds.length == 2);
    assert(mappings[3].status == CatalogMatchStatus.noMatch);
    assertThrown!Exception(matchCatalog(catalog, batches, answers[0 .. 1]));

    // A single source row may legitimately select two lexical categories.
    auto extended = parseCatalog(`{
      "schemaVersion":1,"id":"it-A1-extended","languageCode":"it",
      "languageEntityId":"Q652","level":"A1","source":{},
      "entries":[
        {"id":"334","lemma":"piacere","lookupTargets":[
           {"lemma":"piacere","lexicalCategoryId":"Q24905"},
           {"lemma":"piacere","lexicalCategoryId":"Q1084"}]},
        {"id":"18","lemma":"amico/a","lookupTargets":[
           {"lemma":"amico","lexicalCategoryId":"Q1084"},
           {"lemma":"amica","lexicalCategoryId":"Q1084"}]}
      ]}`);
    auto expandedBatches = buildCatalogLookupBatches(extended, 20);
    assert(expandedBatches.length == 1);
    assert(expandedBatches[0].lemmas.length == 3);
    JSONValue[] expandedResponses = [parseJSON(`{"results":{"bindings":[
      {"lemma":{"value":"piacere"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L10"},
       "category":{"value":"http://www.wikidata.org/entity/Q24905"}},
      {"lemma":{"value":"piacere"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L11"},
       "category":{"value":"http://www.wikidata.org/entity/Q1084"}},
      {"lemma":{"value":"amico"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L12"},
       "category":{"value":"http://www.wikidata.org/entity/Q1084"}},
      {"lemma":{"value":"amica"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L13"},
       "category":{"value":"http://www.wikidata.org/entity/Q1084"}}
    ]}}`)];
    auto expanded = matchCatalog(extended, expandedBatches, expandedResponses);
    assert(expanded.length == 2);
    assert(expanded[0].candidates.length == 2);
    assert(expanded[1].candidates.length == 2);
}


unittest
{
    import std.json : parseJSON;
    import wikidata.catalog : parseCatalog;
    auto catalog = parseCatalog(`{"schemaVersion":1,"id":"test","languageCode":"it",
      "languageEntityId":"Q652","level":"A1","source":{},"entries":[
      {"id":"one","lemma":"io","lexicalCategoryId":"Q36224"},
      {"id":"two","lemma":"i","lexicalCategoryId":"Q103184"}
    ]}`);
    auto batches = buildCatalogLookupBatches(catalog, 20);
    JSONValue[] responses = [parseJSON(`{"results":{"bindings":[
      {"lemma":{"value":"io"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L101"},
       "category":{"value":"http://www.wikidata.org/entity/Q468801"},
       "sense":{"value":"http://www.wikidata.org/entity/L101-S1"}},
      {"lemma":{"value":"i"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L102"},
       "category":{"value":"http://www.wikidata.org/entity/Q9788"}}
    ]}}`)];
    auto baseline = matchCatalog(catalog, batches, responses);
    assert(baseline[0].status == CatalogMatchStatus.noMatch);
    CategoryCompatibility compatibility;
    compatibility.add("Q468801", "Q36224");
    auto extended = matchCatalogWithCategories(catalog, batches,
        responses, compatibility);
    assert(extended[0].status == CatalogMatchStatus.matched);
    assert(extended[0].candidates[0].matchMethod == "subclass");
    assert(extended[0].candidates[0].senseIds == ["L101-S1"]);
    assert(extended[1].status == CatalogMatchStatus.noMatch);
}
