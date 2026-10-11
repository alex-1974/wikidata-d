/** Read and inspect complete Wikidata lexemes (requires Internet access). */
module inspect;

import std.stdio : writeln;
import wikidata.client : WikidataClient;
import wikidata.lexeme : parseLexeme;

void main()
{
    auto client = WikidataClient(
        "wikidata-d-research/0.1 (https://github.com/alex-1974)");

    foreach (id; ["L38246", "L1219303", "L711417", "L5577"])
    {
        auto lexeme = parseLexeme(client.getEntity(id));
        writeln(lexeme.id, " | language=", lexeme.languageId,
            " | category=", lexeme.lexicalCategoryId,
            " | forms=", lexeme.forms.length,
            " | senses=", lexeme.senses.length);
        foreach (sense; lexeme.senses)
        {
            foreach (statement; sense.statements)
            {
                if (statement.targetId.length != 0)
                    writeln("  ", sense.id, " ", statement.propertyId,
                        " -> ", statement.targetId);
            }
        }
    }
}
