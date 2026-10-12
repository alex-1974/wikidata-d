/** R1.10: perform real (offline) R1.7 Wikidata evidence binding checks. */
module catalog_grammar_binding_attested;

import std.exception : enforce;
import std.file : readText, write;
import std.json : parseJSON;
import std.stdio : writeln;
import wikidata.grammar_binding : evaluateAttestedBindingFixture;

void main(string[] args)
{
    enforce(args.length == 4 || args.length == 5,
        "Usage: catalog_grammar_binding_attested EVIDENCE.json " ~
        "PREDICATES.json CHECKS.json [REPORT.json]");
    auto report = evaluateAttestedBindingFixture(
        parseJSON(readText(args[1])), parseJSON(readText(args[2])),
        parseJSON(readText(args[3])));
    foreach (row; report["results"].array)
    {
        writeln(row["id"].str, ": ", row["status"].str,
            " | ", row["matches"].integer, " witness(es)");
    }
    writeln("R1.10 ATTESTED BINDING REGRESSION: PASS (",
        report["results"].array.length, " checks)");
    if (args.length == 5) write(args[4], report.toPrettyString() ~ "\n");
}
