/**
 * M5.6: Find Wikidata Forms for entries unresolved by M5.5, preserving
 * existing coverage and storing Form candidates in a separate local report.
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
import wikidata.catalog : loadCatalog;
import wikidata.client : WikidataClient;
import wikidata.form_lookup : FormCandidate, buildFormLookupQuery,
    parseFormLookupResponse, buildFormCandidatesReport;

int main(string[] args)
{
    if (args.length != 4)
    {
        writeln("Usage: catalog_form_coverage <catalog.json> "
            ~ "<M5.5-category-report.json> <form-candidates.json>");
        return 2;
    }
    auto catalog = loadCatalog(args[1]);
    auto previous = parseJSON(readText(args[2]));
    auto oldEntries = previous["entries"];
    if (oldEntries.array.length != catalog.entries.length ||
        previous["catalogId"].str != catalog.id)
    {
        stderr.writeln("M5.5 report does not match this catalogue");
        return 1;
    }

    string[] words;
    foreach (i, entry; catalog.entries)
    {
        if (oldEntries.array[i]["catalogEntryId"].str != entry.id)
        {
            stderr.writeln("M5.5 entries do not match catalogue ordering");
            return 1;
        }
        if (oldEntries.array[i]["status"].str != "noMatch") continue;
        foreach (target; entry.lookupTargets)
            if (!words.canFind(target.lemma)) words ~= target.lemma;
    }
    const size_t batchSize = 15;
    auto checkpointDir = args[3] ~ ".batches";
    mkdirRecurse(checkpointDir);
    FormCandidate[] all;
    auto client = WikidataClient("wikidata-d/0.1 "
        ~ "(https://github.com/alex-1974)");
    size_t total = (words.length + batchSize - 1) / batchSize;
    writeln("Unresolved lookup spellings: ", words.length);
    writeln("Form query batches: ", total);

    for (size_t begin = 0, batch = 0; begin < words.length;
        begin += batchSize, ++batch)
    {
        auto end = begin + batchSize;
        if (end > words.length) end = words.length;
        auto part = words[begin .. end];
        auto query = buildFormLookupQuery(catalog.languageCode,
            catalog.languageEntityId, part);
        auto path = buildPath(checkpointDir,
            format("batch-%03d.json", batch + 1));
        JSONValue response;
        if (loadCachedBatch(path, query, response))
        {
            writeln("Form batch ", batch + 1, "/", total, " (cached)");
        }
        else
        {
            writeln("Form batch ", batch + 1, "/", total, " (network)");
            bool completed;
            foreach (attempt; 0 .. 3)
            {
                try
                {
                    response = client.query(query);
                    validateBatchResponse(response);
                    saveCachedBatch(path, query, response);
                    completed = true;
                    break;
                }
                catch (CurlTimeoutException e)
                {
                    stderr.writeln("Timeout at batch ", batch + 1,
                        " attempt ", attempt + 1, "/3: ", e.msg);
                    if (attempt < 2)
                        Thread.sleep(dur!"seconds"(10 * (attempt + 1)));
                }
                catch (HTTPStatusException e)
                {
                    stderr.writeln("HTTP error: ", e.msg,
                        ". Honor Retry-After when throttled; resume later.");
                    return 1;
                }
                catch (Exception e)
                {
                    stderr.writeln("Form lookup failed: ", e.msg);
                    return 1;
                }
            }
            if (!completed)
            {
                stderr.writeln("INCOMPLETE: successful Form checkpoints "
                    ~ "preserved. Resume later.");
                return 1;
            }
            Thread.sleep(dur!"seconds"(2));
        }
        all ~= parseFormLookupResponse(response, part);
    }

    auto report = buildFormCandidatesReport(catalog, previous, all);
    auto tmp = args[3] ~ ".tmp";
    write(tmp, report.toPrettyString());
    rename(tmp, args[3]);
    writeln("=== M5.6 FORM CANDIDATES ===");
    writeln("Unresolved in M5.5: ",
        report["summary"]["unresolvedEntries"].integer);
    writeln("Entries with Form candidates: ",
        report["summary"]["entriesWithFormCandidates"].integer);
    writeln("Entries without Form candidates: ",
        report["summary"]["entriesWithoutFormCandidates"].integer);
    foreach (row; report["entries"].array)
    {
        writeln(row["lemma"].str, ": ", row["candidates"].array.length,
            " candidate(s)");
        foreach (candidate; row["candidates"].array)
            writeln("  ", candidate["word"].str, " => ",
                candidate["lexemeId"].str, " / ",
                candidate["formId"].str, " (lemma=",
                candidate["lemma"].str, ", POS=",
                candidate["lexicalCategoryId"].str, ")");
    }
    writeln("Report: ", args[3]);
    return 0;
}
