/**
 * Checkpoint successful SPARQL batch responses by exact query text.
 * Failed responses must never be interpreted as missing lexemes.
 */
module wikidata.batch_cache;

import std.exception : enforce;
import std.file : exists, readText, rename, write;
import std.json : JSONValue, JSONType, parseJSON;

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

bool loadCachedBatch(string filePath, string query, out JSONValue response)
{
    if (!exists(filePath))
        return false;
    return decodeBatchEnvelope(parseJSON(readText(filePath)), query, response);
}

void saveCachedBatch(string filePath, string query, JSONValue response)
{
    auto serialized = makeBatchEnvelope(query, response).toPrettyString();
    auto temporary = filePath ~ ".tmp";
    write(temporary, serialized);
    rename(temporary, filePath);
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
