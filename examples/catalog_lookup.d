/** Live M4 demo: does not modify the source catalogue. */
import std.stdio : writeln;
import std.json : JSONValue;
import wikidata.client : WikidataClient;
import wikidata.catalog : loadCatalog;
import wikidata.catalog_matcher : buildCatalogLookupBatches, matchCatalog;

void main()
{
    auto catalog = loadCatalog("catalogs/it-A1-demo.json");
    auto client = WikidataClient(
        "wikidata-d/0.1 (https://github.com/alex-1974)");
    auto batches = buildCatalogLookupBatches(catalog);
    JSONValue[] responses;
    foreach (batch; batches)
        responses ~= client.query(batch.sparql);
    auto matches = matchCatalog(catalog, batches, responses);
    foreach (i, match; matches)
    {
        writeln(catalog.entries[i].lemma, " [", match.catalogEntryId,
            "] status=", match.status);
        foreach (candidate; match.candidates)
            writeln("  ", candidate.lexemeId, " category=",
                candidate.lexicalCategoryId, " senses=",
                candidate.senseIds.length);
    }
}
