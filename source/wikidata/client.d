/**
 * Wikidata SPARQL and entity HTTP client. No GUI or storage dependency.
 *
 * M1 deliberately returns the original JSON shape. Typed lexical graphs and
 * persistence are separate, later milestones.
 */
module wikidata.client;

import std.exception : enforce;
import std.json : JSONValue, JSONType, parseJSON;
import std.net.curl : HTTP, get;
import std.uri : encodeComponent;
import core.time : dur;

import wikidata.query : buildLexemeQuery, isEntityId;

struct WikidataClient
{
    /// Provide an honest, identifiable application User-Agent, including contact URL/email.
    string userAgent;
    string sparqlEndpoint = "https://query.wikidata.org/sparql";
    string entityEndpoint = "https://www.wikidata.org/w/api.php";

    this(string userAgent)
    {
        enforce(userAgent.length != 0, "Wikidata requires an identifying User-Agent");
        this.userAgent = userAgent;
    }

    /// Execute SELECT/ASK queries and return SPARQL JSON results.
    JSONValue query(string sparql)
    {
        enforce(sparql.length != 0, "SPARQL query must not be empty");
        auto url = sparqlEndpoint ~ "?query=" ~ encodeComponent(sparql)
                 ~ "&format=json";
        return requestJson(url, "application/sparql-results+json");
    }

    /// Find exact lemma candidates; language and optional POS are explicit.
    JSONValue findLexemes(
        string languageCode,
        string languageEntity,
        const(string)[] lemmas,
        string categoryEntity = "")
    {
        return query(buildLexemeQuery(
            languageCode, languageEntity, lemmas, categoryEntity));
    }

    /// Fetch one full Q-, L-, or P-entity; Forms and Senses are included for lexemes.
    JSONValue getEntity(string id)
    {
        enforce(isEntityId(id), "Invalid Wikidata entity ID");
        auto url = entityEndpoint
                 ~ "?action=wbgetentities&format=json&ids=" ~ id;
        auto data = requestJson(url, "application/json");
        enforce(data.type == JSONType.object, "Malformed Wikidata API response");
        if (auto error = "error" in data.object)
            throw new Exception("Wikidata API error: " ~ (*error).toString());
        enforce("entities" in data.object, "Missing entities in API response");
        auto entities = data["entities"];
        enforce(entities.type == JSONType.object, "Invalid entities structure");
        enforce(id in entities.object, "Entity missing from API response: " ~ id);
        auto entity = entities[id];
        enforce(entity.type == JSONType.object, "Invalid entity structure");
        enforce(!("missing" in entity.object), "Entity not found: " ~ id);
        return entity;
    }

    private JSONValue requestJson(string url, string accept)
    {
        auto http = HTTP(url);
        http.setUserAgent(userAgent);
        http.addRequestHeader("Accept", accept);
        http.connectTimeout = dur!"seconds"(10);
        http.operationTimeout = dur!"seconds"(30);
        auto payload = get(url, http);
        return parseJSON(payload.idup);
    }
}
