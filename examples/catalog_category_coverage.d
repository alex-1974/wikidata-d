/**
 * M5.5: Re-evaluate a complete catalogue using Wikidata lexical-category
 * subclass relationships. Reuses M5.4 lexeme-search checkpoints offline.
 */
import std.algorithm.searching : canFind;
import std.file : rename, write;
import std.format : format;
import std.json : JSONValue;
import std.path : buildPath;
import std.stdio : stderr, writeln;
import std.net.curl : CurlTimeoutException, HTTPStatusException;

import wikidata.client : WikidataClient;
import wikidata.catalog : loadCatalog;
import wikidata.catalog_matcher : buildCatalogLookupBatches, matchCatalog,
    matchCatalogWithCategories, CatalogMatchStatus;
import wikidata.coverage : buildCoverageReport, coverageJson;
import wikidata.lexical_categories : buildCategoryCompatibilityQuery,
    parseCategoryCompatibility;
import wikidata.batch_cache : loadCachedBatch, saveCachedBatch,
    validateBatchResponse;

int main(string[] args)
{
    if (args.length != 4)
    {
        writeln("Usage: catalog_category_coverage <catalog.json> "
            ~ "<M5.4-report.json> <new-report.json>");
        return 2;
    }
    auto catalog = loadCatalog(args[1]);
    auto batches = buildCatalogLookupBatches(catalog, 20);
    auto checkpointDir = args[2] ~ ".batches";
    JSONValue[] responses;
    foreach (i, batch; batches)
    {
        auto path = buildPath(checkpointDir,
            format("batch-%03d.json", i + 1));
        JSONValue response;
        if (!loadCachedBatch(path, batch.sparql, response))
        {
            stderr.writeln("Missing or outdated M5.4 checkpoint: ", path);
            stderr.writeln("Run catalog_coverage before this analysis.");
            return 1;
        }
        responses ~= response;
    }

    auto initialMatches = matchCatalog(catalog, batches, responses);
    auto initial = buildCoverageReport(catalog, batches, responses,
        initialMatches);
    string[] observed;
    string[] expected;
    foreach (i, entry; initial.entries)
    {
        if (entry.status != CatalogMatchStatus.noMatch ||
            !entry.anyLemmaHit)
            continue;
        foreach (id; entry.observedCategories)
            if (!observed.canFind(id))
                observed ~= id;
        foreach (target; catalog.entries[i].lookupTargets)
            if (target.lexicalCategoryId.length &&
                !expected.canFind(target.lexicalCategoryId))
                expected ~= target.lexicalCategoryId;
    }
    writeln("Initial noMatch: ", initial.noMatch,
        " (POS mismatch: ", initial.posMismatch,
        ", no lemma: ", initial.noLemmaHit, ")");
    if (observed.length == 0 || expected.length == 0)
    {
        writeln("No POS mismatches to re-evaluate.");
        return 0;
    }

    auto sparql = buildCategoryCompatibilityQuery(observed, expected);
    auto cachePath = args[3] ~ ".categories.json";
    JSONValue response;
    if (loadCachedBatch(cachePath, sparql, response))
        writeln("Lexical-category relations: cached");
    else
    {
        writeln("Lexical-category relations: Wikidata P279 query");
        auto client = WikidataClient(
            "wikidata-d/0.1 (https://github.com/alex-1974)");
        try
        {
            response = client.query(sparql);
            validateBatchResponse(response);
            saveCachedBatch(cachePath, sparql, response);
        }
        catch (CurlTimeoutException e)
        {
            stderr.writeln("Category query timed out: ", e.msg);
            return 1;
        }
        catch (HTTPStatusException e)
        {
            stderr.writeln("HTTP error: ", e.msg,
                ". If throttled, honor Retry-After and retry later.");
            return 1;
        }
    }

    auto compatibility = parseCategoryCompatibility(response);
    auto updatedMatches = matchCatalogWithCategories(catalog,
        batches, responses, compatibility);
    auto updated = buildCoverageReport(catalog, batches, responses,
        updatedMatches);
    auto temporary = args[3] ~ ".tmp";
    write(temporary, coverageJson(updated).toPrettyString());
    rename(temporary, args[3]);

    writeln("=== M5.5 CATEGORY COVERAGE ===");
    writeln("Catalog entries: ", updated.entries.length);
    writeln("Matched: ", updated.matched);
    writeln("Multiple candidates: ", updated.multipleCandidates);
    writeln("No match: ", updated.noMatch);
    writeln("  No exact lemma: ", updated.noLemmaHit);
    writeln("  POS mismatch: ", updated.posMismatch);
    writeln("Report: ", args[3]);
    return 0;
}
