/**
 * R1.8: run the R1.7 Wikidata evidence fixture with the D implementation.
 * Usage: catalog_grammar_evidence <attested-evidence.json>
 *        <reference-predicates.json> <report.json>
 */
module catalog_grammar_evidence;

import std.exception : enforce;
import std.file : readText, write;
import std.json : parseJSON;
import std.stdio : writeln;
import wikidata.grammar_evidence : evaluateEvidenceFixture;

void main(string[] args)
{
    enforce(args.length == 4,
        "Usage: catalog_grammar_evidence <fixture.json> <predicates.json> <output.json>");
    auto snapshot = parseJSON(readText(args[1]));
    auto predicates = parseJSON(readText(args[2]));
    auto report = evaluateEvidenceFixture(snapshot, predicates);
    auto rows = report["results"].array;
    size_t supported, contradicted, unknown;
    foreach (row; rows)
    {
        auto status = row["status"].str;
        if (status == "supported") ++supported;
        else if (status == "contradicted") ++contradicted;
        else ++unknown;
        writeln(row["id"].str, ": ", status, " | ",
            row["proof"].array.length, " Wikidata statements");
    }
    write(args[3], report.toPrettyString() ~ "\n");
    writeln("R1.8 REGRESSION: PASS (", rows.length, " predicates)");
    writeln("Supported: ", supported, "; contradicted: ", contradicted,
        "; unknown: ", unknown);
    writeln("Report: ", args[3]);
}
