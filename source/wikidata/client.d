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
import core.time : Duration, dur;

import wikidata.query : buildLexemeQuery, isEntityId;

/**
 * HTTP client for Wikidata SPARQL queries and entity retrieval.
 *
 * Create a client with an identifying User-Agent, then use $(D query) for
 * SPARQL JSON or $(D getEntity) for a single Wikibase entity object.
 * Methods perform real network requests and may fail; results are not cached.
 * The caller is responsible for service limits, retries and offline storage.
 * See_Also: query, findLexemes, getEntity
 */
struct WikidataClient
{
    /// Identifying HTTP User-Agent supplied by the application, with contact details.
    string userAgent;
    /// SPARQL endpoint URL. Change only when targeting a compatible service.
    string sparqlEndpoint = "https://query.wikidata.org/sparql";
    /// Wikibase entity API endpoint URL for $(D wbgetentities).
    string entityEndpoint = "https://www.wikidata.org/w/api.php";
    /// Timeout for SPARQL operations (default 70 seconds); not a service guarantee.
    Duration sparqlTimeout = dur!"seconds"(70);

    /**
     * Create a client with an identifying application User-Agent.
     *
     * Params:
     *   userAgent = Nonempty application identification, ideally with a
     *               contact URL or email address.
     * Throws: $(D Exception) if $(D userAgent) is empty.
     * Notes: Construction makes no network request.
     */
    this(string userAgent)
    {
        enforce(userAgent.length != 0, "Wikidata requires an identifying User-Agent");
        this.userAgent = userAgent;
    }

    ///
    unittest
    {
        import std.exception : assertThrown;
        // Client construction does not send an HTTP request.
        auto client = WikidataClient("VocabularyTrainer/0.1 (contact: dev@example.org)");
        assert(client.userAgent.length != 0);
        assertThrown!Exception(WikidataClient(""));
    }


    /**
     * Execute SPARQL text against the configured query endpoint.
     *
     * Params:
     *   sparql = Nonempty SPARQL query text.
     * Returns: Parsed JSON response returned by the endpoint.
     * Throws: $(D Exception) for empty query text; transport, timeout and
     *         JSON parsing failures may also propagate.
     * Notes: An HTTP failure is not evidence that a Lexeme does not exist.
     *        The service is called over the network, without caching.
     * See_Also: findLexemes, getEntity
     */
    JSONValue query(string sparql)
    {
        enforce(sparql.length != 0, "SPARQL query must not be empty");
        auto url = sparqlEndpoint ~ "?query=" ~ encodeComponent(sparql)
                 ~ "&format=json";
        return requestJson(url, "application/sparql-results+json", sparqlTimeout);
    }

    /**
     * Search Lexemes by exact written lemmas and optional lexical category.
     *
     * Params:
     *   languageCode = Representation language tag, such as $(D "it").
     *   languageEntity = Wikidata language item ID, such as $(D "Q652").
     *   lemmas = Nonempty exact written lemma spellings to search for.
     *   categoryEntity = Optional lexical-category Q-ID; empty means no filter.
     * Returns: Unmodified parsed SPARQL result JSON with candidate bindings.
     * Throws: $(D Exception) for invalid query inputs or propagated HTTP,
     *         timeout and JSON parse errors.
     * Notes: Candidates are not verified translations or Sense assignments.
     *        This method performs a network request.
     * See_Also: query, getEntity
     */
    JSONValue findLexemes(
        string languageCode,
        string languageEntity,
        const(string)[] lemmas,
        string categoryEntity = "")
    {
        return query(buildLexemeQuery(
            languageCode, languageEntity, lemmas, categoryEntity));
    }

    /**
     * Fetch one Wikidata Q-, L- or P-entity by identifier.
     *
     * Params:
     *   id = Entity identifier, for example $(D "L5577").
     * Returns: The requested entity JSON object, not the surrounding
     *          $(D entities) response envelope. Lexeme Forms and Senses
     *          remain in the returned original JSON.
     * Throws: $(D Exception) for invalid ID syntax, missing entity, API
     *         error response or invalid envelope; network, timeout and JSON
     *         parsing failures may also propagate.
     * Notes: A valid-looking ID does not guarantee an existing entity.
     *        This method performs a network request.
     * See_Also: query, findLexemes
     */
    JSONValue getEntity(string id)
    {
        enforce(isEntityId(id), "Invalid Wikidata entity ID");
        auto url = entityEndpoint
                 ~ "?action=wbgetentities&format=json&ids=" ~ id;
        auto data = requestJson(url, "application/json", dur!"seconds"(30));
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

    /// Request and parse JSON, propagating transport and decoding errors.
    private JSONValue requestJson(string url, string accept, Duration timeout)
    {
        auto http = HTTP(url);
        http.setUserAgent(userAgent);
        http.addRequestHeader("Accept", accept);
        http.connectTimeout = dur!"seconds"(10);
        http.operationTimeout = timeout;
        auto payload = get(url, http);
        return parseJSON(payload.idup);
    }
}

///
unittest
{
    // Construct and configure a client without contacting a server.
    auto client = WikidataClient("VocabularyTrainer/0.1 (contact: dev@example.org)");
    assert(client.userAgent.length != 0);
    assert(client.sparqlEndpoint == "https://query.wikidata.org/sparql");
    assert(client.entityEndpoint == "https://www.wikidata.org/w/api.php");
    // Calling query, findLexemes or getEntity would perform a real HTTP request.
}
