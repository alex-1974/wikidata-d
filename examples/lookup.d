// Live smoke example. Requires network access. See README for build command.
module lookup;

import std.stdio : writeln;
import wikidata.client : WikidataClient;

void main()
{
    // Replace contact address with your actual project URL before use.
    auto client = WikidataClient("wikidata-d-research/0.1 (https://example.org/contact)");
    auto result = client.findLexemes("it", "Q652", ["gatto", "nero", "andare"]);
    auto results = result["results"];
    auto bindings = results["bindings"];
    foreach (row; bindings.array)
    {
        writeln(row["lemma"]["value"].str, "\t", row["lexeme"]["value"].str);
    }

    auto gatto = client.getEntity("L5577");
    writeln("Loaded entity: ", gatto["id"].str);
}
