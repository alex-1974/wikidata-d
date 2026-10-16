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

/**
 * Coverage information for one unchanged vocabulary-catalogue entry.
 *
 * Observed categories describe returned lemma hits before part-of-speech
 * filtering, while candidates contain accepted Lexeme matches.
 * See_Also: CoverageReport, buildCoverageReport
 */
struct CoverageEntry
{
    string catalogEntryId; /// Original catalogue entry ID.
    string lemma; /// Original source spelling, not necessarily a lookup target.
    CatalogMatchStatus status; /// Accepted Lexeme match outcome.
    LexemeCandidate[] candidates; /// Accepted Lexemes; not verified translations.
    bool anyLemmaHit; /// At least one queried spelling has a result binding.
    string[] observedCategories; /// Categories observed before POS filtering.
}

/**
 * Complete offline Wikidata coverage summary for a source catalogue.
 *
 * Counts describe successful supplied SPARQL results, not absolute Wikidata
 * completeness. The original source catalogue remains unchanged.
 * See_Also: buildCoverageReport, coverageJson
 */
struct CoverageReport
{
    string catalogId; /// Identifier of the original source catalogue.
    string languageCode; /// Language code carried from the catalogue.
    string level; /// Learning level carried from the catalogue.
    CoverageEntry[] entries; /// One entry per source entry, in source order.
    size_t matched; /// Entries with exactly one accepted candidate.
    size_t multipleCandidates; /// Entries with multiple accepted candidates.
    size_t noMatch; /// Entries with no accepted candidates.
    size_t noLemmaHit; /// No-match entries without an observed lemma binding.
    size_t posMismatch; /// No-match entries with lemma bindings but rejected POS.
}

/// Read a mandatory string-valued SPARQL binding.
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

/// Extract an entity identifier from a Wikidata category URI.
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
 * Summarize complete Lexeme lookup results for every source-catalogue entry.
 *
 * Combine the original catalogue, the query batches and their successful
 * responses with the matching outcomes. Entries stay in source order, even
 * if no Wikidata candidate was accepted. A $(D noLemmaHit) counts entries
 * without a lemma binding; $(D posMismatch) counts entries with a lemma
 * binding but no accepted lexical category. Both are subsets of $(D noMatch).
 *
 * Params:
 *   catalog = Complete original vocabulary catalogue.
 *   batches = Lookup batches for the catalogue.
 *   responses = One complete parsed SPARQL JSON response per batch.
 *   matches = One source-ordered match result per original catalogue entry.
 * Returns: Detailed entry outcomes and totals for the supplied results.
 * Throws: $(D Exception) when responses are incomplete or malformed,
 *         results contain unrequested lemmas, or match order/count differs
 *         from the catalogue.
 * Notes: A failed query must never be replaced with an empty response.
 *        Results describe the supplied data, not all possible Wikidata
 *        Lexemes or Senses. The source catalogue is not changed.
 * See_Also: coverageJson, matchCatalog, CoverageReport
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

    // Research F2-B: validation-first compact category observation chains.
    // The one contiguous array contains only category and next-index data.
    struct CategoryHit
    {
        string category;
        size_t next;
    }
    struct LemmaChain
    {
        size_t first;
        size_t last;
    }
    LemmaChain[string] categoryChains;
    size_t validHitCount;
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
            qId(bindingValue(row, "category"));
            ++validHitCount;
        }
    }

    CategoryHit[] categoryHits;
    categoryHits.length = validHitCount;
    size_t nextHit;
    foreach (response; responses)
        foreach (row; response["results"]["bindings"].array)
        {
            auto lemma = bindingValue(row, "lemma");
            auto category = qId(bindingValue(row, "category"));
            const hitIndex = nextHit++;
            categoryHits[hitIndex] = CategoryHit(category, size_t.max);
            auto chain = lemma in categoryChains;
            if (chain is null)
                categoryChains[lemma] = LemmaChain(hitIndex, hitIndex);
            else
            {
                categoryHits[(*chain).last].next = hitIndex;
                (*chain).last = hitIndex;
            }
        }
    assert(nextHit == validHitCount);

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
        {
            auto chain = target.lemma in categoryChains;
            if (chain is null)
                continue;
            for (size_t hitIndex = (*chain).first;
                hitIndex != size_t.max; hitIndex = categoryHits[hitIndex].next)
            {
                const category = categoryHits[hitIndex].category;
                entry.anyLemmaHit = true;
                if (!entry.observedCategories.canFind(category))
                    entry.observedCategories ~= category;
            }
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

///
unittest
{
    import wikidata.catalog : parseCatalog;
    import wikidata.catalog_matcher : buildCatalogLookupBatches, matchCatalog;
    // Report absence in supplied complete results, never delete catalogue data.
    auto catalog = parseCatalog(`{"schemaVersion":1,"id":"demo",
      "languageCode":"it","languageEntityId":"Q652","level":"A1",
      "source":{},"entries":[{"id":"a","lemma":"gatto"}]}`);
    auto batches = buildCatalogLookupBatches(catalog);
    JSONValue[] responses = [parseJSON(`{"results":{"bindings":[]}}`)];
    auto matches = matchCatalog(catalog, batches, responses);
    auto report = buildCoverageReport(catalog, batches, responses, matches);
    assert(report.entries.length == catalog.entries.length);
    assert(report.noMatch == 1 && report.noLemmaHit == 1);
}


/**
 * Convert a completed coverage report to a structured JSON document.
 *
 * Use this for local inspection or serialization without modifying the
 * independent vocabulary catalogue. Output contains schemaVersion 1,
 * catalogue metadata, summary totals and an entry for each source record.
 *
 * Params:
 *   report = Previously calculated coverage report.
 * Returns: JSON object with summary and per-entry candidate details.
 * Notes: The output reflects the supplied report; this function does not
 *        re-run matching, consult Wikidata or independently verify counts.
 * See_Also: buildCoverageReport, CoverageEntry
 */
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

///
unittest
{
    import wikidata.catalog : parseCatalog;
    import wikidata.catalog_matcher : buildCatalogLookupBatches, matchCatalog;
    // JSON serialization keeps the source entry even without any hit.
    auto catalog = parseCatalog(`{"schemaVersion":1,"id":"demo",
      "languageCode":"it","languageEntityId":"Q652","level":"A1",
      "source":{},"entries":[{"id":"a","lemma":"gatto"}]}`);
    auto batches = buildCatalogLookupBatches(catalog);
    JSONValue[] responses = [parseJSON(`{"results":{"bindings":[]}}`)];
    auto matches = matchCatalog(catalog, batches, responses);
    auto report = buildCoverageReport(catalog, batches, responses, matches);
    auto json = coverageJson(report);
    assert(json["entries"].array.length == 1);
    assert(json["summary"]["catalogEntries"].integer == 1);
}


///
unittest
{
    import wikidata.catalog : parseCatalog;
    import wikidata.catalog_matcher : buildCatalogLookupBatches, matchCatalog;
    // One source entry remains visible even when a successful query is empty.
    auto catalog = parseCatalog(`{"schemaVersion":1,"id":"demo",
      "languageCode":"it","languageEntityId":"Q652","level":"A1",
      "source":{},"entries":[{"id":"1","lemma":"gatto"}]}`);
    auto batches = buildCatalogLookupBatches(catalog);
    JSONValue[] responses = [parseJSON(`{"results":{"bindings":[]}}`)];
    auto matches = matchCatalog(catalog, batches, responses);
    auto report = buildCoverageReport(catalog, batches, responses, matches);
    assert(report.entries.length == 1);
    assert(report.noMatch == 1 && report.noLemmaHit == 1);
    assert(report.posMismatch == 0);
    auto json = coverageJson(report);
    assert(json["summary"]["catalogEntries"].integer == 1);
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
