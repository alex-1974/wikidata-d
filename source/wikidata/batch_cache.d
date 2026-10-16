/**
 * Checkpoint successful SPARQL batch responses by exact query text.
 * Failed responses must never be interpreted as missing lexemes.
 */
module wikidata.batch_cache;

import std.exception : enforce;
import std.file : exists, readText, rename, write;
import std.json : JSONValue, JSONType, parseJSON;

/**
 * Require the successful SPARQL SELECT-result shape for a cached batch.
 *
 * Params:
 *   response = Parsed SPARQL JSON expected to contain results.bindings.
 * Throws: $(D Exception) if the root, results or bindings has invalid shape.
 * Notes: This checks structure, not the factual completeness of server data.
 *        Do not treat failures as an empty result set.
 * See_Also: makeBatchEnvelope, loadCachedBatch
 */
void validateBatchResponse(JSONValue response)
{
    enforce(response.type == JSONType.object, "Invalid SPARQL response");
    auto results = "results" in response.object;
    enforce(results !is null && (*results).type == JSONType.object,
        "SPARQL response has no results object");
    auto bindings = "bindings" in (*results).object;
    enforce(bindings !is null && (*bindings).type == JSONType.array,
        "SPARQL response has no bindings array");
}

///
unittest
{
    // A successful empty SPARQL response is valid; a service error is not.
    import std.exception : assertThrown;
    validateBatchResponse(parseJSON(`{"results":{"bindings":[]}}`));
    assertThrown!Exception(validateBatchResponse(parseJSON(`{"error":"unavailable"}`)));
}


/**
 * Combine exact SPARQL query text and its validated response for storage.
 *
 * Params:
 *   query = Nonempty, exact SPARQL text used to obtain the response.
 *   response = Parsed complete SPARQL JSON with results.bindings.
 * Returns: Version 1 JSON envelope containing query and response.
 * Throws: $(D Exception) for an empty query or malformed response shape.
 * Notes: The query is preserved verbatim; it is not canonicalized.
 * See_Also: decodeBatchEnvelope, saveCachedBatch
 */
JSONValue makeBatchEnvelope(string query, JSONValue response)
{
    enforce(query.length != 0, "Missing batch SPARQL query");
    validateBatchResponse(response);
    JSONValue envelope = JSONValue.emptyObject;
    envelope["schemaVersion"] = 1;
    envelope["query"] = query;
    envelope["response"] = response;
    return envelope;
}

///
unittest
{
    // Store the exact SPARQL text beside the successful response.
    auto result = parseJSON(`{"results":{"bindings":[]}}`);
    auto saved = makeBatchEnvelope("SELECT * WHERE {}", result);
    assert(saved["schemaVersion"].integer == 1);
    assert(saved["query"].str == "SELECT * WHERE {}");
}


/**
 * Read a saved batch response only when its query text matches exactly.
 *
 * Params:
 *   envelope = Parsed checkpoint envelope using schemaVersion 1.
 *   query = Exact SPARQL text expected by the caller.
 *   response = Output receiving the validated response on $(D true).
 * Returns: $(D true) and sets $(D response) when the query matches; $(D false)
 *          if the checkpoint stores different query text.
 * Throws: $(D Exception) for malformed checkpoint fields, unsupported schema
 *         or invalid stored response when the query matches.
 * Notes: On $(D false), do not rely on the previous content of $(D response).
 *        Semantically equivalent but differently formatted queries differ.
 * See_Also: makeBatchEnvelope, loadCachedBatch
 */
bool decodeBatchEnvelope(JSONValue envelope, string query, out JSONValue response)
{
    enforce(envelope.type == JSONType.object, "Invalid checkpoint object");
    auto schema = "schemaVersion" in envelope.object;
    enforce(schema !is null && (*schema).type == JSONType.integer &&
        (*schema).integer == 1, "Unsupported checkpoint schema");
    auto savedQuery = "query" in envelope.object;
    enforce(savedQuery !is null && (*savedQuery).type == JSONType.string,
        "Checkpoint has no SPARQL query");
    if ((*savedQuery).str != query)
        return false;
    auto savedResponse = "response" in envelope.object;
    enforce(savedResponse !is null, "Checkpoint has no response");
    response = *savedResponse;
    validateBatchResponse(response);
    return true;
}

///
unittest
{
    // Even insignificant query-text differences cause a cache miss.
    auto saved = makeBatchEnvelope("SELECT * WHERE {}",
        parseJSON(`{"results":{"bindings":[]}}`));
    JSONValue response;
    assert(decodeBatchEnvelope(saved, "SELECT * WHERE {}", response));
    assert(response["results"]["bindings"].array.length == 0);
    assert(!decodeBatchEnvelope(saved, "SELECT  * WHERE {}", response));
}


/**
 * Retrieve a locally saved SPARQL batch if the exact query matches.
 *
 * Params:
 *   filePath = Path to the checkpoint JSON file.
 *   query = Exact SPARQL text expected by the caller.
 *   response = Output receiving the validated response on a hit.
 * Returns: $(D false) for a missing file or different stored query;
 *          $(D true) for a validated matching response.
 * Throws: File-reading, JSON decoding and checkpoint validation errors.
 * Notes: This is a single-writer checkpoint, not a concurrent cache or a
 *        crash-durable database. On $(D false), do not use $(D response).
 * See_Also: saveCachedBatch, decodeBatchEnvelope
 */
bool loadCachedBatch(string filePath, string query, out JSONValue response)
{
    if (!exists(filePath))
        return false;
    return decodeBatchEnvelope(parseJSON(readText(filePath)), query, response);
}

/**
 * Save a validated SPARQL batch response to a local checkpoint file.
 *
 * Params:
 *   filePath = Destination path; a sibling $(D .tmp) path is used first.
 *   query = Exact nonempty SPARQL query string used as the cache key.
 *   response = Parsed successful SPARQL result JSON.
 * Throws: Validation, serialization, file-write or rename errors.
 * Notes: Designed for a single writer. Simultaneous writers, power-loss
 *        durability, and recovery of a stale $(D .tmp) file are not guaranteed.
 *        The cache key is exact query text, not SPARQL equivalence.
 * See_Also: loadCachedBatch, makeBatchEnvelope
 */
void saveCachedBatch(string filePath, string query, JSONValue response)
{
    auto serialized = makeBatchEnvelope(query, response).toPrettyString();
    auto temporary = filePath ~ ".tmp";
    write(temporary, serialized);
    rename(temporary, filePath);
}

///
unittest
{
    // Validate and round-trip a complete response without file I/O or network.
    auto data = parseJSON(`{"results":{"bindings":[]}}`);
    validateBatchResponse(data);
    auto envelope = makeBatchEnvelope("SELECT * WHERE {}", data);
    JSONValue restored;
    assert(decodeBatchEnvelope(envelope, "SELECT * WHERE {}", restored));
    assert(restored["results"]["bindings"].array.length == 0);
    assert(!decodeBatchEnvelope(envelope, "SELECT ?x WHERE {}", restored));
}

unittest
{
    import std.exception : assertThrown;
    auto raw = parseJSON(`{"head":{"vars":["lemma"]},
        "results":{"bindings":[]}}`);
    auto checkpoint = makeBatchEnvelope("SELECT * WHERE {}", raw);
    auto decoded = parseJSON(checkpoint.toPrettyString());
    JSONValue recovered;
    assert(decodeBatchEnvelope(decoded, "SELECT * WHERE {}", recovered));
    assert(recovered["results"]["bindings"].array.length == 0);
    assert(!decodeBatchEnvelope(decoded, "SELECT ?s WHERE {}", recovered));
    assertThrown!Exception(validateBatchResponse(
        parseJSON(`{"error":"service unavailable"}`)));
    assertThrown!Exception(decodeBatchEnvelope(
        parseJSON(`{"schemaVersion":1,"query":"x","response":{}}`),
        "x", recovered));
}
