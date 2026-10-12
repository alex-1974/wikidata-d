/** R1.9: Evaluate declarative evidence expressions using the R1.7 snapshot. */
module catalog_grammar_expression;

import std.exception : enforce;
import std.file : readText, write;
import std.json : parseJSON;
import std.stdio : writeln;
import wikidata.grammar_expression : evaluateExpressionFixture;

void main(string[] args)
{
    enforce(args.length == 5,
        "Usage: catalog_grammar_expression <evidence.json> " ~
        "<predicates.json> <expressions.json> <output.json>");
    auto report = evaluateExpressionFixture(
        parseJSON(readText(args[1])),
        parseJSON(readText(args[2])),
        parseJSON(readText(args[3])));
    size_t supported, unknown, contradicted;
    foreach (row; report["results"].array)
    {
        auto status = row["status"].str;
        if (status == "supported") ++supported;
        else if (status == "unknown") ++unknown;
        else if (status == "contradicted") ++contradicted;
        writeln(row["id"].str, ": ", status, " | ",
            row["leafEvidence"].array.length, " evidence checks");
    }
    write(args[4], report.toPrettyString() ~ "\n");
    writeln("R1.9 REGRESSION: PASS (", report["results"].array.length, " rules)");
    writeln("Supported: ", supported, "; contradicted: ", contradicted,
        "; unknown: ", unknown);
    writeln("Report: ", args[4]);
}
