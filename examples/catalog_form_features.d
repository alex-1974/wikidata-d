/**
 * M5.7: Enrich M5.6 Form candidates with Wikidata grammatical features.
 * Writes a separate report, without promoting candidates to matches.
 */
import core.thread : Thread;
import core.time : dur;
import std.algorithm.searching : canFind;
import std.file : mkdirRecurse, readText, rename, write;
import std.format : format;
import std.json : JSONValue, parseJSON;
import std.net.curl : CurlTimeoutException, HTTPStatusException;
import std.path : buildPath;
import std.stdio : stderr, writeln;

import wikidata.batch_cache : loadCachedBatch, saveCachedBatch,
    validateBatchResponse;
import wikidata.client : WikidataClient;
import wikidata.form_features : FormFeatureRecord, buildFormFeatureQuery,
    parseFormFeatureResponse, buildFormFeatureReport;

int main(string[] args)
{
    if (args.length != 3)
    {
        writeln("Usage: catalog_form_features <M5.6-form-candidates.json> "
            ~ "<M5.7-form-feature-report.json>");
        return 2;
    }
    JSONValue previous;
    try
    {
        previous = parseJSON(readText(args[1]));
    }
    catch (Exception e)
    {
        stderr.writeln("Cannot read M5.6 report: ", e.msg);
        return 1;
    }
    string[] ids;
    foreach (row; previous["entries"].array)
        foreach (candidate; row["candidates"].array)
        {
            auto id = candidate["formId"].str;
            if (!ids.canFind(id)) ids ~= id;
        }
    if (ids.length == 0)
    {
        stderr.writeln("No Form candidates to enrich");
        return 1;
    }
    auto checkpointDir = args[2] ~ ".batches";
    mkdirRecurse(checkpointDir);
    enum size_t batchSize = 20;
    auto count = (ids.length + batchSize - 1) / batchSize;
    writeln("Unique Form IDs: ", ids.length);
    writeln("SPARQL batches: ", count);
    FormFeatureRecord[] all;
    auto client = WikidataClient("wikidata-d/0.1 "
        ~ "(https://github.com/alex-1974)");
    for (size_t begin = 0, n = 0; begin < ids.length;
        begin += batchSize, ++n)
    {
        auto end = begin + batchSize;
        if (end > ids.length) end = ids.length;
        auto part = ids[begin .. end];
        auto query = buildFormFeatureQuery(part);
        auto path = buildPath(checkpointDir,
            format("batch-%03d.json", n + 1));
        JSONValue response;
        if (loadCachedBatch(path, query, response))
        {
            writeln("Feature batch ", n + 1, "/", count, " (cached)");
        }
        else
        {
            writeln("Feature batch ", n + 1, "/", count, " (network)");
            bool completed;
            foreach (attempt; 0 .. 3)
            {
                try
                {
                    response = client.query(query);
                    validateBatchResponse(response);
                    // Parse and verify the response BEFORE saving the checkpoint.
                    auto validated = parseFormFeatureResponse(response, part);
                    saveCachedBatch(path, query, response);
                    completed = true;
                    break;
                }
                catch (CurlTimeoutException e)
                {
                    stderr.writeln("Timeout at batch ", n + 1,
                        ", attempt ", attempt + 1, "/3: ", e.msg);
                    if (attempt < 2)
                        Thread.sleep(dur!"seconds"(10 * (attempt + 1)));
                }
                catch (HTTPStatusException e)
                {
                    stderr.writeln("HTTP error: ", e.msg,
                        ". Honor Retry-After; resume later.");
                    return 1;
                }
                catch (Exception e)
                {
                    stderr.writeln("Feature query failed: ", e.msg);
                    return 1;
                }
            }
            if (!completed)
            {
                stderr.writeln("INCOMPLETE: cached batches remain reusable.");
                return 1;
            }
            Thread.sleep(dur!"seconds"(2));
        }
        all ~= parseFormFeatureResponse(response, part);
    }
    auto report = buildFormFeatureReport(previous, all);
    auto tmp = args[2] ~ ".tmp";
    write(tmp, report.toPrettyString());
    rename(tmp, args[2]);
    writeln("=== M5.7 FORM FEATURES ===");
    writeln("Entries with Form candidates: ",
        report["summary"]["entriesWithCandidates"].integer);
    writeln("Form candidates: ",
        report["summary"]["formCandidates"].integer);
    writeln("Candidates with features: ",
        report["summary"]["candidatesWithFeatures"].integer);
    writeln("Confirmed new Lexeme matches: 0 (all require review)");
    foreach (row; report["entries"].array)
    {
        if (row["candidates"].array.length == 0) continue;
        writeln(row["lemma"].str);
        foreach (candidate; row["candidates"].array)
        {
            writeln("  ", candidate["word"].str,
                " => ", candidate["lexemeId"].str,
                " / ", candidate["formId"].str,
                " | ", candidate["lexicalCategoryId"].str,
                " | features=", candidate["grammaticalFeatureIds"].toString());
        }
    }
    writeln("Report: ", args[2]);
    return 0;
}
