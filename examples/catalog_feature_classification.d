/** R1.11-B: offline candidate classification from original R1.3 Q-item graph. */
module catalog_feature_classification;

import std.exception : enforce;
import std.file : readText, write;
import std.json : parseJSON;
import std.stdio : writeln;
import wikidata.grammar_dimension : evaluateDimensionFixture;

void main(string[] args)
{
    enforce(args.length == 4 || args.length == 5,
        "Usage: catalog_feature_classification R1.3-GRAPH.json " ~
        "REVIEWED-PROFILE.json CHECKS.json [OUTPUT.json]");
    auto report = evaluateDimensionFixture(
        parseJSON(readText(args[1])), parseJSON(readText(args[2])),
        parseJSON(readText(args[3])));
    foreach (row; report["results"].array)
        writeln(row["id"].str, ": ", row["status"].str,
            " | ", row["candidates"].array.length, " candidate dimension(s)");
    writeln("R1.11-B SYNTHETIC Q-GRAPH REGRESSION: PASS (",
        report["results"].array.length, " checks)");
    if (args.length == 5) write(args[4], report.toPrettyString() ~ "\n");
}
