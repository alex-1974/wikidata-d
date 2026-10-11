/**
 * Exact catalogue-to-Wikidata Lexeme candidate matching.
 * Query results do not alter the catalogue and do not assign A1 to Senses.
 */
module wikidata.catalog_matcher;

import std.algorithm.searching : canFind, startsWith;
import std.exception : enforce;
import std.json : JSONValue, JSONType, parseJSON;
import wikidata.catalog : VocabularyCatalog;
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
        foreach (lemma; entry.lookupLemmas)
            if ((lemma in seen) is null)
            {
                seen[lemma] = true;
                lemmas ~= lemma;
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
            if (!entry.lookupLemmas.canFind(hit.lemma))
                continue;
            if (entry.lexicalCategoryId.length &&
                entry.lexicalCategoryId != hit.candidate.lexicalCategoryId)
                continue;
            size_t index = match.candidates.length;
            foreach (i, candidate; match.candidates)
                if (candidate.lexemeId == hit.candidate.lexemeId)
                {
                    index = i;
                    break;
                }
            if (index == match.candidates.length)
                match.candidates ~= hit.candidate;
            else
                foreach (sense; hit.candidate.senseIds)
                    if (!match.candidates[index].senseIds.canFind(sense))
                        match.candidates[index].senseIds ~= sense;
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
}
