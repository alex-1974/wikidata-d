/**
 * M5.10: add literal spellings to all M5.8 grammar-audit Forms.
 *
 * Usage: catalog_form_representations <M5.5-coverage.json>
 *        <M5.8-grammar-audit.json> <M5.10-representations.json>
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
import wikidata.grammar_audit : auditLexemes;
import wikidata.form_representations : WrittenForm,
    buildRepresentationQuery, parseRepresentationResponse,
    buildRepresentationReport;

int main(string[] args)
{
    if (args.length != 4)
    {
        writeln("Usage: catalog_form_representations "
            ~ "<M5.5-coverage.json> <M5.8-audit.json> <output.json>");
        return 2;
    }

    JSONValue coverage;
    JSONValue audit;
    try
    {
        coverage = parseJSON(readText(args[1]));
        audit = parseJSON(readText(args[2]));
        if (coverage["catalogId"].str != audit["catalogId"].str ||
            coverage["languageCode"].str != audit["languageCode"].str ||
            coverage["level"].str != audit["level"].str)
            throw new Exception("M5.5 and M5.8 metadata mismatch");
    }
    catch (Exception e)
    {
        stderr.writeln("Cannot load compatible reports: ", e.msg);
        return 1;
    }

    auto lexemes = auditLexemes(coverage);
    if (!lexemes.length ||
        lexemes.length != cast(size_t) audit["summary"]["uniqueLexemes"].integer)
    {
        stderr.writeln("M5.5/M5.8 unique Lexeme count mismatch");
        return 1;
    }

    enum size_t batchSize = 20;
    auto batchCount = (lexemes.length + batchSize - 1) / batchSize;
    auto checkpointDir = args[3] ~ ".batches";
    mkdirRecurse(checkpointDir);
    writeln("Unique Lexemes: ", lexemes.length);
    writeln("SPARQL batches: ", batchCount);
    writeln("Checkpoints: ", checkpointDir);
    auto client = WikidataClient("wikidata-d/0.1 "
        ~ "(https://github.com/alex-1974)");

    WrittenForm[] discovered;
    for (size_t begin = 0, n = 0; begin < lexemes.length;
        begin += batchSize, ++n)
    {
        auto end = begin + batchSize;
        if (end > lexemes.length) end = lexemes.length;
        auto part = lexemes[begin .. end];
        auto query = buildRepresentationQuery(part);
        auto cachePath = buildPath(checkpointDir,
            format("batch-%03d.json", n + 1));
        JSONValue response;
        try
        {
            if (loadCachedBatch(cachePath, query, response))
                writeln("Representation batch ", n + 1, "/", batchCount,
                    " (cached)");
            else
            {
                writeln("Representation batch ", n + 1, "/", batchCount,
                    " (network)");
                bool completed;
                foreach (attempt; 0 .. 3)
                {
                    try
                    {
                        response = client.query(query);
                        validateBatchResponse(response);
                        auto checked = parseRepresentationResponse(response,
                            part);
                        saveCachedBatch(cachePath, query, response);
                        completed = true;
                        break;
                    }
                    catch (CurlTimeoutException e)
                    {
                        stderr.writeln("Timeout in batch ", n + 1,
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
                    stderr.writeln("INCOMPLETE: Resume from checkpoints.");
                    return 1;
                }
                Thread.sleep(dur!"seconds"(2));
            }
            discovered ~= parseRepresentationResponse(response, part);
        }
        catch (Exception e)
        {
            stderr.writeln("Representation batch failed: ", e.msg);
            return 1;
        }
    }

    JSONValue report;
    try
        report = buildRepresentationReport(audit, discovered);
    catch (Exception e)
    {
        stderr.writeln("Report aggregation failed: ", e.msg);
        return 1;
    }
    try
    {
        auto tmp = args[3] ~ ".tmp";
        write(tmp, report.toPrettyString());
        rename(tmp, args[3]);
    }
    catch (Exception e)
    {
        stderr.writeln("Report write failed: ", e.msg);
        return 1;
    }

    writeln("=== M5.10 FORM REPRESENTATIONS ===");
    auto s = report["summary"];
    writeln("Lexemes queried: ", s["uniqueLexemes"].integer);
    writeln("Audit Forms: ", s["auditForms"].integer);
    writeln("Forms with spellings: ", s["formsWithRepresentation"].integer);
    writeln("Forms without spellings: ",
        s["formsWithoutRepresentation"].integer);
    writeln("Forms with multiple spellings: ",
        s["formsWithMultipleRepresentations"].integer);
    writeln("Representations without language tag: ",
        s["representationsWithoutLanguageTag"].integer);
    writeln("Form IDs missing in latest query: ",
        s["missingFromLatestQuery"].integer);
    writeln("New Form IDs not in M5.8 audit: ",
        s["newSinceAudit"].integer);
    writeln("Report: ", args[3]);
    return 0;
}
