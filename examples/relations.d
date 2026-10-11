/** Live smoke test for Sense neighbours. Requires network access. */
module relations;

import std.stdio : writeln;
import wikidata.client : WikidataClient;
import wikidata.relations : buildSenseRelationsQuery, parseSenseRelations;

void main()
{
    auto client = WikidataClient(
        "wikidata-d-research/0.1 (https://github.com/alex-1974)");

    foreach (senseId; ["L5577-S1", "L38246-S1"])
    {
        // Bound to German (Q188) to limit work on the public query service.
        enum size_t rowLimit = 100;
        auto query = buildSenseRelationsQuery(senseId, "Q188", rowLimit);
        auto neighbours = parseSenseRelations(client.query(query), senseId);
        writeln("Sense ", senseId, " | German relations: ", neighbours.length);
        foreach (edge; neighbours)
            writeln("  ", edge.propertyId, " (", edge.direction, ")",
                edge.viaId.length ? " via " ~ edge.viaId : "",
                " => ", edge.targetLemma,
                " [", edge.targetLexemeId, ", ", edge.targetSenseId, "]");
        if (neighbours.length == rowLimit)
            writeln("  WARNING: row limit reached; result may be incomplete");
    }
}
