/** R1.10 isolated, synthetic-only bind regression; no Wikidata API calls. */
module catalog_grammar_binding;

import std.file : readText, write;
import std.json : parseJSON;
import std.stdio : writeln;
import std.exception : enforce;
import wikidata.grammar_binding : evaluateSyntheticBindingFixture;

void main(string[] args)
{
    enforce(args.length == 2 || args.length == 3,
        "Usage: catalog_grammar_binding RESEARCH_CASES.json [REPORT.json]");
    auto report = evaluateSyntheticBindingFixture(parseJSON(readText(args[1])));
    foreach (row; report["results"].array)
        writeln(row["id"].str, ": ", row["status"].str,
            " (", row["matches"].integer, " witness(es))");
    writeln("R1.10 SYNTHETIC BINDING REGRESSION: PASS (",
        report["results"].array.length, " cases)");
    if (args.length == 3) write(args[2], report.toPrettyString());
}
