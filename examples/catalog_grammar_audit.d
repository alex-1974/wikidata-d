/**
 * M5.8: Audit grammatical feature combinations of the matched A1 lexemes.
 * Usage: catalog_grammar_audit <M5.5-category-coverage.json> <audit.json>
 * The original catalogue and previous coverage reports are read-only.
 */
import core.thread : Thread;
import core.time : dur;
import std.file : mkdirRecurse, readText, rename, write;
import std.format : format;
import std.json : JSONValue, parseJSON;
import std.net.curl : CurlTimeoutException, HTTPStatusException;
import std.path : buildPath;
import std.stdio : stderr, writeln;

import wikidata.batch_cache : loadCachedBatch, saveCachedBatch,
    validateBatchResponse;
import wikidata.client : WikidataClient;
import wikidata.grammar_audit : AuditForm, auditLexemes,
    buildGrammarAuditQuery, parseGrammarAuditResponse, buildGrammarAuditReport;

int main(string[] args)
{
    if (args.length != 3)
    {
        writeln("Usage: catalog_grammar_audit "
            ~ "<M5.5-category-coverage.json> <M5.8-audit.json>");
        return 2;
    }

    JSONValue coverage;
    try
        coverage = parseJSON(readText(args[1]));
    catch (Exception e)
    {
        stderr.writeln("Cannot read M5.5 coverage report: ", e.msg);
        return 1;
    }

    auto lexemes = auditLexemes(coverage);
    if (lexemes.length == 0)
    {
        stderr.writeln("No matched Lexemes available for grammar audit");
        return 1;
    }

    enum size_t batchSize = 20;
    auto batchCount = (lexemes.length + batchSize - 1) / batchSize;
    auto checkpointDir = args[2] ~ ".batches";
    mkdirRecurse(checkpointDir);
    writeln("Unique matched Lexemes: ", lexemes.length);
    writeln("SPARQL batches: ", batchCount);
    writeln("Checkpoints: ", checkpointDir);
    auto client = WikidataClient("wikidata-d/0.1 "
        ~ "(https://github.com/alex-1974)");

    AuditForm[] allForms;
    for (size_t begin = 0, n = 0; begin < lexemes.length;
        begin += batchSize, ++n)
    {
        auto end = begin + batchSize;
        if (end > lexemes.length) end = lexemes.length;
        auto part = lexemes[begin .. end];
        auto query = buildGrammarAuditQuery(part);
        auto cachePath = buildPath(checkpointDir,
            format("batch-%03d.json", n + 1));
        JSONValue response;
        try
        {
            if (loadCachedBatch(cachePath, query, response))
            {
                writeln("Audit batch ", n + 1, "/", batchCount,
                    " (cached)");
            }
            else
            {
                writeln("Audit batch ", n + 1, "/", batchCount,
                    " (network)");
                bool completed;
                foreach (attempt; 0 .. 3)
                {
                    try
                    {
                        response = client.query(query);
                        validateBatchResponse(response);
                        // Verify data before checkpointing any response.
                        auto checkedForms =
                            parseGrammarAuditResponse(response, part);
                        saveCachedBatch(cachePath, query, response);
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
                            ". Honor Retry-After and resume later.");
                        return 1;
                    }
                }
                if (!completed)
                {
                    stderr.writeln("INCOMPLETE: Resume from saved batches.");
                    return 1;
                }
                Thread.sleep(dur!"seconds"(2));
            }
            allForms ~= parseGrammarAuditResponse(response, part);
        }
        catch (Exception e)
        {
            stderr.writeln("Audit batch failed: ", e.msg);
            return 1;
        }
    }

    JSONValue audit;
    try
        audit = buildGrammarAuditReport(coverage, lexemes, allForms);
    catch (Exception e)
    {
        stderr.writeln("Audit aggregation failed: ", e.msg);
        return 1;
    }

    // Write a complete report only after all batches have passed.
    auto tmp = args[2] ~ ".tmp";
    write(tmp, audit.toPrettyString());
    rename(tmp, args[2]);

    writeln("=== M5.8 GRAMMATICAL FEATURE AUDIT ===");
    auto summary = audit["summary"];
    writeln("Catalog entries: ", summary["catalogEntries"].integer);
    writeln("Unique matched Lexemes: ", summary["uniqueLexemes"].integer);
    writeln("Lexemes with returned Forms: ",
        summary["lexemesWithReturnedForms"].integer);
    writeln("Forms returned: ", summary["formsReturned"].integer);
    writeln("Forms without feature statements: ",
        summary["formsWithoutFeatures"].integer);
    writeln("Category-specific feature patterns: ",
        summary["categoryFeaturePatterns"].integer);
    foreach (category; audit["lexicalCategories"].array)
    {
        writeln("  ", category["lexicalCategoryId"].str,
            ": lexemes=", category["lexemes"].integer,
            " forms=", category["formsReturned"].integer,
            " patterns=", category["patterns"].array.length);
    }
    writeln("Report: ", args[2]);
    return 0;
}
