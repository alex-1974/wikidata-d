/**
 * Offline coverage report derived from complete Wikidata SPARQL batch results.
 * A source catalog is never shortened or mutated by this module.
 */
module wikidata.coverage;

import std.algorithm.searching : canFind;
import std.exception : enforce;
import std.json : JSONValue, JSONType, parseJSON;

import wikidata.catalog : VocabularyCatalog;
import wikidata.catalog_matcher : CatalogLookupBatch, CatalogMatch,
    CatalogMatchStatus, LexemeCandidate;

struct CoverageEntry
{
    string catalogEntryId;
    string lemma;
    CatalogMatchStatus status;
    LexemeCandidate[] candidates;
    bool anyLemmaHit;       /// A SPARQL hit exists for one of the lookup lemmas.
    string[] observedCategories; /// Wikidata categories before POS filtering.
}

struct CoverageReport
{
    string catalogId;
    string languageCode;
    string level;
    CoverageEntry[] entries;
    size_t matched;
    size_t multipleCandidates;
    size_t noMatch;
    size_t noLemmaHit;
    size_t posMismatch;
}

private string bindingValue(JSONValue row, string key)
{
    enforce(row.type == JSONType.object, "Binding must be a JSON object");
    auto term = key in row.object;
    enforce(term !is null && (*term).type == JSONType.object,
        "Missing binding: " ~ key);
    auto value = "value" in (*term).object;
    enforce(value !is null && (*value).type == JSONType.string,
        "Invalid binding: " ~ key);
    return (*value).str;
}

private string qId(string value)
{
    enum http = "http://www.wikidata.org/entity/";
    enum https = "https://www.wikidata.org/entity/";
    import std.algorithm.searching : startsWith;
    if (value.startsWith(http)) return value[http.length .. $];
    if (value.startsWith(https)) return value[https.length .. $];
    throw new Exception("Unexpected Wikidata category URI: " ~ value);
}

/**
 * Each batch must have a complete response. Network or SPARQL failures must
 * abort the process upstream, never become false "no Wikidata match" claims.
 *
 * `noLemmaHit` means no exact-lemma result in the returned SPARQL results,
 * not proof that the lexical expression is absent from all Wikidata data.
 * `posMismatch` means an exact-lemma hit exists but its category does not
 * match any of the catalog's search targets.
 */
CoverageReport buildCoverageReport(
    ref const VocabularyCatalog catalog,
    const(CatalogLookupBatch)[] batches,
    JSONValue[] responses,
    const(CatalogMatch)[] matches)
{
    enforce(batches.length == responses.length,
        "A complete SPARQL response is required for every batch");
    enforce(matches.length == catalog.entries.length,
        "Every source entry requires exactly one mapping result");

    struct Hit { string lemma; string category; }
    Hit[] hits;
    foreach (i, response; responses)
    {
        enforce(response.type == JSONType.object, "Invalid SPARQL response");
        auto results = "results" in response.object;
        enforce(results !is null && (*results).type == JSONType.object,
            "SPARQL response missing results");
        auto bindings = "bindings" in (*results).object;
        enforce(bindings !is null && (*bindings).type == JSONType.array,
            "SPARQL response missing bindings");
        foreach (row; (*bindings).array)
        {
            auto lemma = bindingValue(row, "lemma");
            enforce(batches[i].lemmas.canFind(lemma),
                "SPARQL result lemma was not requested");
            hits ~= Hit(lemma, qId(bindingValue(row, "category")));
        }
    }

    CoverageReport report;
    report.catalogId = catalog.id;
    report.languageCode = catalog.languageCode;
    report.level = catalog.level;

    foreach (i, sourceEntry; catalog.entries)
    {
        enforce(matches[i].catalogEntryId == sourceEntry.id,
            "Mismatch between catalogue and lookup response ordering");
        CoverageEntry entry;
        entry.catalogEntryId = sourceEntry.id;
        entry.lemma = sourceEntry.lemma;
        entry.status = matches[i].status;
        // Build an independent snapshot without discarding transitive const.
        foreach (candidate; matches[i].candidates)
        {
            LexemeCandidate copy;
            copy.lexemeId = candidate.lexemeId.idup;
            copy.lexicalCategoryId = candidate.lexicalCategoryId.idup;
            copy.matchMethod = candidate.matchMethod.idup;
            foreach (senseId; candidate.senseIds)
                copy.senseIds ~= senseId.idup;
            entry.candidates ~= copy;
        }
        foreach (target; sourceEntry.lookupTargets)
            foreach (hit; hits)
                if (target.lemma == hit.lemma)
                {
                    entry.anyLemmaHit = true;
                    if (!entry.observedCategories.canFind(hit.category))
                        entry.observedCategories ~= hit.category;
                }
        final switch (entry.status)
        {
            case CatalogMatchStatus.matched:
                ++report.matched;
                break;
            case CatalogMatchStatus.multipleCandidates:
                ++report.multipleCandidates;
                break;
            case CatalogMatchStatus.noMatch:
                ++report.noMatch;
                if (entry.anyLemmaHit)
                    ++report.posMismatch;
                else
                    ++report.noLemmaHit;
                break;
        }
        report.entries ~= entry;
    }
    enforce(report.entries.length == report.matched +
        report.multipleCandidates + report.noMatch,
        "Coverage accounting failure");
    return report;
}

/// Human/machine-readable local JSON report. No catalogue records are removed.
JSONValue coverageJson(ref const CoverageReport report)
{
    JSONValue output = JSONValue.emptyObject;
    output["schemaVersion"] = 1;
    output["catalogId"] = report.catalogId;
    output["languageCode"] = report.languageCode;
    output["level"] = report.level;

    JSONValue totals = JSONValue.emptyObject;
    totals["catalogEntries"] = cast(long) report.entries.length;
    totals["matched"] = cast(long) report.matched;
    totals["multipleCandidates"] = cast(long) report.multipleCandidates;
    totals["noMatch"] = cast(long) report.noMatch;
    totals["noLemmaHit"] = cast(long) report.noLemmaHit;
    totals["posMismatch"] = cast(long) report.posMismatch;
    output["summary"] = totals;

    JSONValue rows = JSONValue.emptyArray;
    foreach (entry; report.entries)
    {
        JSONValue row = JSONValue.emptyObject;
        row["catalogEntryId"] = entry.catalogEntryId;
        row["lemma"] = entry.lemma;
        final switch (entry.status)
        {
            case CatalogMatchStatus.matched:
                row["status"] = "matched";
                break;
            case CatalogMatchStatus.multipleCandidates:
                row["status"] = "multipleCandidates";
                break;
            case CatalogMatchStatus.noMatch:
                row["status"] = "noMatch";
                break;
        }
        row["anyLemmaHit"] = entry.anyLemmaHit;
        JSONValue cats = JSONValue.emptyArray;
        foreach (category; entry.observedCategories)
            cats.array ~= JSONValue(category);
        row["observedCategories"] = cats;
        JSONValue candidates = JSONValue.emptyArray;
        foreach (candidate; entry.candidates)
        {
            JSONValue c = JSONValue.emptyObject;
            c["lexemeId"] = candidate.lexemeId;
            c["lexicalCategoryId"] = candidate.lexicalCategoryId;
            c["matchMethod"] = candidate.matchMethod;
            JSONValue senses = JSONValue.emptyArray;
            foreach (sense; candidate.senseIds)
                senses.array ~= JSONValue(sense);
            c["senseIds"] = senses;
            candidates.array ~= c;
        }
        row["candidates"] = candidates;
        rows.array ~= row;
    }
    output["entries"] = rows;
    return output;
}

unittest
{
    import wikidata.catalog : parseCatalog;
    import wikidata.catalog_matcher : buildCatalogLookupBatches, matchCatalog;
    enum fixture = `{"schemaVersion":1,"id":"it-A1-test",
      "languageCode":"it","languageEntityId":"Q652","level":"A1",
      "source":{},"entries":[
        {"id":"1","lemma":"nero","lexicalCategoryId":"Q34698"},
        {"id":"2","lemma":"nero","lexicalCategoryId":"Q1084"},
        {"id":"3","lemma":"ci","lexicalCategoryId":"Q184943"},
        {"id":"4","lemma":"ciao","lexicalCategoryId":"Q83034"}
      ]}`;
    auto catalog = parseCatalog(fixture);
    auto batches = buildCatalogLookupBatches(catalog, 20);
    assert(batches.length == 1);
    JSONValue[] responses = [parseJSON(`{"results":{"bindings":[
      {"lemma":{"value":"nero"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L711417"},
       "category":{"value":"http://www.wikidata.org/entity/Q34698"}},
      {"lemma":{"value":"nero"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L1219303"},
       "category":{"value":"http://www.wikidata.org/entity/Q1084"}},
      {"lemma":{"value":"ci"},
       "lexeme":{"value":"http://www.wikidata.org/entity/L999"},
       "category":{"value":"http://www.wikidata.org/entity/Q36224"}}
      ]}}`)];
    auto matches = matchCatalog(catalog, batches, responses);
    auto report = buildCoverageReport(catalog, batches, responses, matches);
    assert(report.entries.length == 4);
    assert(report.matched == 2);
    assert(report.multipleCandidates == 0);
    assert(report.noMatch == 2);
    assert(report.noLemmaHit == 1);
    assert(report.posMismatch == 1);
    assert(report.entries[2].observedCategories == ["Q36224"]);
    auto json = coverageJson(report);
    assert(json["summary"]["catalogEntries"].integer == 4);
    assert(json["entries"].array.length == 4);
}
