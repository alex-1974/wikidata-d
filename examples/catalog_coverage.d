/** Live M5.4 coverage report with persistent checkpoints. */
import core.thread : Thread;
import core.time : dur;
import std.file : mkdirRecurse, rename, write;
import std.format : format;
import std.json : JSONValue;
import std.net.curl : CurlTimeoutException, HTTPStatusException;
import std.path : buildPath;
import std.stdio : stderr, writeln;

import wikidata.client : WikidataClient;
import wikidata.catalog : loadCatalog;
import wikidata.catalog_matcher : buildCatalogLookupBatches, matchCatalog;
import wikidata.coverage : buildCoverageReport, coverageJson;
import wikidata.batch_cache : loadCachedBatch, saveCachedBatch,
    validateBatchResponse;

int main(string[] args)
{
    if (args.length != 3)
    {
        writeln("Usage: catalog_coverage <catalog.json> <report.json>");
        return 2;
    }
    auto catalog = loadCatalog(args[1]);
    auto batches = buildCatalogLookupBatches(catalog, 20);
    auto checkpointDir = args[2] ~ ".batches";
    mkdirRecurse(checkpointDir);

    writeln("Catalog entries: ", catalog.entries.length);
    writeln("SPARQL batches: ", batches.length);
    writeln("Checkpoints: ", checkpointDir);

    auto client = WikidataClient(
        "wikidata-d/0.1 (https://github.com/alex-1974)");
    JSONValue[] responses;
    foreach (i, batch; batches)
    {
        auto checkpointPath = buildPath(checkpointDir,
            format("batch-%03d.json", i + 1));
        JSONValue response;

        if (loadCachedBatch(checkpointPath, batch.sparql, response))
        {
            writeln("Query batch ", i + 1, "/", batches.length,
                " (cached)");
            responses ~= response;
            continue;
        }

        writeln("Query batch ", i + 1, "/", batches.length,
            " (network)");
        bool completed = false;
        foreach (attempt; 0 .. 3)
        {
            try
            {
                response = client.query(batch.sparql);
                validateBatchResponse(response);
                saveCachedBatch(checkpointPath, batch.sparql, response);
                completed = true;
                break;
            }
            catch (CurlTimeoutException e)
            {
                stderr.writeln("Timeout at batch ", i + 1,
                    ", attempt ", attempt + 1, "/3: ", e.msg);
                if (attempt < 2)
                    Thread.sleep(dur!"seconds"(10 * (attempt + 1)));
            }
            catch (HTTPStatusException e)
            {
                // In particular, do not blindly retry HTTP 429.
                stderr.writeln("HTTP error at batch ", i + 1,
                    ": ", e.msg);
                stderr.writeln("Resume later; honor Retry-After for HTTP 429.");
                return 1;
            }
            catch (Exception e)
            {
                stderr.writeln("Batch ", i + 1, " failed: ", e.msg);
                return 1;
            }
        }
        if (!completed)
        {
            stderr.writeln("INCOMPLETE: batch ", i + 1,
                " failed. Successful checkpoints were preserved.");
            return 1;
        }
        responses ~= response;
        // Avoid a burst of consecutive queries against the public endpoint.
        Thread.sleep(dur!"seconds"(2));
    }

    auto matches = matchCatalog(catalog, batches, responses);
    auto coverage = buildCoverageReport(catalog, batches, responses, matches);
    auto json = coverageJson(coverage);
    auto temporary = args[2] ~ ".tmp";
    write(temporary, json.toPrettyString());
    rename(temporary, args[2]);

    writeln("=== COVERAGE ===");
    writeln("Catalog entries: ", coverage.entries.length);
    writeln("Matched: ", coverage.matched);
    writeln("Multiple candidates: ", coverage.multipleCandidates);
    writeln("No match: ", coverage.noMatch);
    writeln("  No exact lemma found: ", coverage.noLemmaHit);
    writeln("  POS mismatch: ", coverage.posMismatch);
    writeln("Report: ", args[2]);
    return 0;
}
