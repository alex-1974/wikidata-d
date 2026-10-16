/**
 * M3: Query Wikidata Sense neighbours through concept, predicate and direct
 * Sense relationships. The data returned by this module is not a vetted
 * translation dictionary: relation type and direction are always retained.
 *
 * No network, GUI, persistence, or catalogue dependencies.
 */
module wikidata.relations;

import std.conv : to;
import std.exception : enforce;
import std.json : JSONType, JSONValue, parseJSON;
import std.algorithm.searching : startsWith;

import wikidata.query : isEntityId, sparqlString;

/**
 * Check whether text has the syntax of a Wikidata Sense identifier.
 *
 * Use this to reject malformed input before composing a Sense-relations
 * query. No request is made and existence is not verified.
 *
 * Params:
 *   id = Candidate identifier, such as $(D "L5577-S1").
 * Returns: $(D true) for an L-number-S-number identifier with positive
 *          decimal numbers and no extra characters; otherwise $(D false).
 * Notes: This function does not accept Form IDs such as $(D "L5577-F1").
 * See_Also: buildSenseRelationsQuery, parseSenseRelations
 */
bool isSenseId(string id)
{
    if (id.length < 4 || id[0] != 'L')
        return false;
    size_t i = 1;
    if (id[i] < '1' || id[i] > '9')
        return false;
    while (i < id.length && id[i] >= '0' && id[i] <= '9')
        ++i;
    if (i + 2 >= id.length || id[i] != '-' || id[i + 1] != 'S')
        return false;
    i += 2;
    if (id[i] < '1' || id[i] > '9')
        return false;
    for (++i; i < id.length; ++i)
        if (id[i] < '0' || id[i] > '9')
            return false;
    return true;
}

///
unittest
{
    // Identifier syntax is not a claim that a Sense exists in Wikidata.
    assert(isSenseId("L5577-S1"));
    assert(!isSenseId("L5577-F1"));
    assert(!isSenseId("L5577-S0"));
}


/**
 * One directed or shared Wikidata relationship involving a source Sense.
 *
 * Use the property ID together with $(D direction) to interpret this edge;
 * it is not automatically an approved translation. The full SPARQL binding
 * remains available through $(D raw) for further inspection.
 *
 * Shared P5137 concept and P9970 predicate relationships carry a Q-item
 * in $(D viaId). Direct P5972, P5973 and P5974 relationships retain the
 * actual stored incoming or outgoing direction instead.
 * Notes: A relation does not assign vocabulary level or catalogue coverage.
 * See_Also: parseSenseRelations, buildSenseRelationsQuery
 */
struct SenseRelation
{
    string sourceSenseId; /// Requested starting Sense ID.
    string targetSenseId; /// Related Sense ID returned by Wikidata.
    string targetLexemeId; /// Lexeme owning the related Sense.
    string targetLemma; /// Written lemma of the target Lexeme.
    string targetLanguageId; /// Wikidata language Q-ID of the target Lexeme.
    string targetCategoryId; /// Wikidata lexical-category Q-ID of the target Lexeme.
    string propertyId; /// Relation property ID, such as P5137 or P5972.
    string direction; /// Relation direction: shared, outgoing or incoming.
    string viaId; /// Shared concept or predicate Q-ID; empty for a direct relation.
    JSONValue raw; /// Original SPARQL binding row, including additional fields.
}

///
unittest
{
    // Property and direction are both needed to interpret this candidate edge.
    SenseRelation edge;
    edge.sourceSenseId = "L5577-S1";
    edge.propertyId = "P5972";
    edge.direction = "outgoing";
    assert(edge.targetSenseId.length == 0 && edge.direction == "outgoing");
}

/**
 * Build a bounded SPARQL query for nearby relationships of one Sense.
 *
 * Use the resulting text with your Wikidata query client, then pass a
 * successful complete JSON response to $(D parseSenseRelations).
 * The query includes shared P5137 concepts, shared P9970 predicates,
 * and direct P5972 translations, P5973 synonyms and P5974 antonyms in
 * both stored edge directions. Such results are relationship candidates,
 * not a verified translation dictionary. No HTTP request occurs here.
 *
 * Params:
 *   sourceSenseId = Starting Wikidata Sense ID (e.g. $(D "L5577-S1")).
 *   targetLanguageId = Optional target language Q-ID; empty includes all.
 *   limit = Maximum result rows from 1 to 1000 (default 100).
 * Returns: SPARQL query text for immediate Sense neighbours.
 * Throws: $(D Exception) for invalid Sense or language IDs, or limits
 *         outside the permitted range.
 * Notes: The limit counts rows, not distinct target Lexemes. A full page
 *        can be truncated; this function has no paging or transitive walk.
 * See_Also: isSenseId, parseSenseRelations, SenseRelation
 */
string buildSenseRelationsQuery(
    string sourceSenseId,
    string targetLanguageId = "",
    size_t limit = 100)
{
    enforce(isSenseId(sourceSenseId), "Expected a Wikidata Sense ID");
    if (targetLanguageId.length)
        enforce(isEntityId(targetLanguageId) && targetLanguageId[0] == 'Q',
            "Expected language Q-ID");
    enforce(limit >= 1 && limit <= 1000, "Query limit must be 1..1000");

    string query =
        "PREFIX wd: <http://www.wikidata.org/entity/>\n"
        ~ "PREFIX wdt: <http://www.wikidata.org/prop/direct/>\n"
        ~ "PREFIX ontolex: <http://www.w3.org/ns/lemon/ontolex#>\n"
        ~ "PREFIX wikibase: <http://wikiba.se/ontology#>\n"
        ~ "PREFIX dct: <http://purl.org/dc/terms/>\n"
        ~ "SELECT DISTINCT ?relation ?direction ?via ?targetSense ?lexeme "
        ~ "?lemma ?language ?category WHERE {\n"
        ~ "  VALUES ?source { wd:" ~ sourceSenseId ~ " }\n";

    bool first = true;
    foreach (propertyId; ["P5137", "P9970"])
    {
        if (!first)
            query ~= "  UNION\n";
        first = false;
        query ~= "  {\n"
            ~ "    ?source wdt:" ~ propertyId ~ " ?via .\n"
            ~ "    ?targetSense wdt:" ~ propertyId ~ " ?via .\n"
            ~ "    BIND(" ~ sparqlString(propertyId) ~ " AS ?relation)\n"
            ~ "    BIND(\"shared\" AS ?direction)\n"
            ~ "  }\n";
    }

    foreach (propertyId; ["P5972", "P5973", "P5974"])
    {
        foreach (direction; ["outgoing", "incoming"])
        {
            query ~= "  UNION\n  {\n";
            if (direction == "outgoing")
                query ~= "    ?source wdt:" ~ propertyId ~ " ?targetSense .\n";
            else
                query ~= "    ?targetSense wdt:" ~ propertyId ~ " ?source .\n";
            query ~= "    BIND(" ~ sparqlString(propertyId) ~ " AS ?relation)\n"
                ~ "    BIND(" ~ sparqlString(direction) ~ " AS ?direction)\n"
                ~ "  }\n";
        }
    }

    query ~= "  FILTER(?targetSense != ?source)\n"
        ~ "  ?lexeme ontolex:sense ?targetSense ;\n"
        ~ "    dct:language ?language ;\n"
        ~ "    wikibase:lemma ?lemma ;\n"
        ~ "    wikibase:lexicalCategory ?category .\n";
    if (targetLanguageId.length)
        query ~= "  FILTER(?language = wd:" ~ targetLanguageId ~ ")\n";
    query ~= "}\nLIMIT " ~ to!string(limit) ~ "\n";
    return query;
}


///
unittest
{
    import std.algorithm.searching : canFind;
    import std.exception : assertThrown;
    // Syntactic checks do not contact Wikidata or establish existence.
    assert(isSenseId("L5577-S1"));
    assert(!isSenseId("L5577-F1"));

    // Ask for immediate relationships of one Sense in one target language.
    auto query = buildSenseRelationsQuery("L5577-S1", "Q188", 25);
    assert(query.canFind("FILTER(?language = wd:Q188)"));
    assert(query.canFind("LIMIT 25"));
    assertThrown!Exception(buildSenseRelationsQuery("L5577-S0"));

    // Parse an offline response; the result remains a candidate, not proof
    // of translation equivalence or a catalogue-level assignment.
    auto sample = parseJSON(`{"results":{"bindings":[{
      "relation":{"value":"P5137"},"direction":{"value":"shared"},
      "via":{"value":"http://www.wikidata.org/entity/Q146"},
      "targetSense":{"value":"http://www.wikidata.org/entity/L100-S2"},
      "lexeme":{"value":"http://www.wikidata.org/entity/L100"},
      "lemma":{"value":"Katze"},
      "language":{"value":"http://www.wikidata.org/entity/Q188"},
      "category":{"value":"http://www.wikidata.org/entity/Q1084"}
    }]}}`);
    auto edges = parseSenseRelations(sample, "L5577-S1");
    assert(edges.length == 1);
    assert(edges[0].propertyId == "P5137");
    assert(edges[0].direction == "shared" && edges[0].viaId == "Q146");
    assert(edges[0].targetSenseId == "L100-S2");
}

/// Read a required or optional string value from one SPARQL binding term.
private string valueAt(JSONValue row, string key, bool optional = false)
{
    enforce(row.type == JSONType.object, "Invalid SPARQL result row");
    auto p = key in row.object;
    if (p is null && optional)
        return "";
    enforce(p !is null && (*p).type == JSONType.object,
        "Missing SPARQL binding: " ~ key);
    auto v = "value" in (*p).object;
    enforce(v !is null && (*v).type == JSONType.string,
        "Invalid SPARQL binding value: " ~ key);
    return (*v).str;
}

/// Extract an identifier from an HTTP(S) Wikidata entity URI.
private string idFromUri(string uri)
{
    enum prefix = "http://www.wikidata.org/entity/";
    enum securePrefix = "https://www.wikidata.org/entity/";
    if (uri.startsWith(prefix))
        return uri[prefix.length .. $];
    if (uri.startsWith(securePrefix))
        return uri[securePrefix.length .. $];
    throw new Exception("Not a Wikidata entity URI: " ~ uri);
}

/**
 * Convert a successful SPARQL JSON response into typed Sense relationships.
 *
 * Use this with the JSON result of $(D buildSenseRelationsQuery). The parser
 * retains each returned relation's property, direction, target identifiers
 * and complete original binding row. It does not verify the meaning of a
 * relation, infer translations or fetch additional data.
 *
 * Params:
 *   result = SPARQL JSON object with $(D results.bindings) rows.
 *   sourceSenseId = Source Sense ID associated with the request.
 * Returns: Relations in the supplied binding order; an empty valid bindings
 *          array produces an empty array of relationships.
 * Throws: $(D Exception) for malformed structure, invalid entity IDs,
 *         direction values or missing shared-relation concept IDs.
 * Notes: Network and endpoint errors must be handled before calling this
 *        parser; they are not equivalent to a successful empty result.
 * See_Also: buildSenseRelationsQuery, SenseRelation, isSenseId
 */
SenseRelation[] parseSenseRelations(JSONValue result, string sourceSenseId)
{
    enforce(isSenseId(sourceSenseId), "Expected a Wikidata Sense ID");
    enforce(result.type == JSONType.object, "SPARQL response must be an object");
    auto results = "results" in result.object;
    enforce(results !is null && (*results).type == JSONType.object,
        "Missing SPARQL results object");
    auto bindings = "bindings" in (*results).object;
    enforce(bindings !is null && (*bindings).type == JSONType.array,
        "Missing SPARQL bindings array");

    SenseRelation[] edges;
    foreach (row; (*bindings).array)
    {
        SenseRelation edge;
        edge.sourceSenseId = sourceSenseId;
        edge.targetSenseId = idFromUri(valueAt(row, "targetSense"));
        edge.targetLexemeId = idFromUri(valueAt(row, "lexeme"));
        edge.targetLemma = valueAt(row, "lemma");
        edge.targetLanguageId = idFromUri(valueAt(row, "language"));
        edge.targetCategoryId = idFromUri(valueAt(row, "category"));
        edge.propertyId = valueAt(row, "relation");
        edge.direction = valueAt(row, "direction");
        auto via = valueAt(row, "via", true);
        edge.viaId = via.length ? idFromUri(via) : "";
        edge.raw = row;

        enforce(isSenseId(edge.targetSenseId), "Invalid target Sense ID");
        enforce(isEntityId(edge.targetLexemeId) && edge.targetLexemeId[0] == 'L',
            "Invalid target Lexeme ID");
        enforce(isEntityId(edge.targetLanguageId) && edge.targetLanguageId[0] == 'Q',
            "Invalid target language ID");
        enforce(isEntityId(edge.targetCategoryId) && edge.targetCategoryId[0] == 'Q',
            "Invalid target category ID");
        enforce(isEntityId(edge.propertyId) && edge.propertyId[0] == 'P',
            "Invalid relation property ID");
        enforce(edge.direction == "shared" || edge.direction == "outgoing"
            || edge.direction == "incoming", "Invalid relation direction");
        if (edge.direction == "shared")
            enforce(edge.viaId.length && isEntityId(edge.viaId)
                && edge.viaId[0] == 'Q', "Shared relation needs a Q-item");
        else
            enforce(edge.viaId.length == 0, "Direct relation must not have via");
        edges ~= edge;
    }
    return edges;
}

///
unittest
{
    // A successful empty response is a valid empty set of relation candidates.
    auto result = parseJSON(`{"results":{"bindings":[]}}`);
    auto edges = parseSenseRelations(result, "L5577-S1");
    assert(edges.length == 0);
}


unittest
{
    import std.algorithm.searching : canFind;
    assert(isSenseId("L5577-S1"));
    assert(isSenseId("L38246-S12"));
    assert(!isSenseId("L5577-F1"));
    assert(!isSenseId("L5577-S0"));
    assert(!isSenseId("L5577-S1) . ?x ?y ?z"));

    auto q = buildSenseRelationsQuery("L5577-S1", "Q188", 25);
    assert(q.canFind("VALUES ?source { wd:L5577-S1 }"));
    assert(q.canFind("?source wdt:P5137 ?via"));
    assert(q.canFind("?targetSense wdt:P9970 ?via"));
    assert(q.canFind("?source wdt:P5972 ?targetSense"));
    assert(q.canFind("?targetSense wdt:P5972 ?source"));
    assert(q.canFind("?targetSense wdt:P5973 ?source"));
    assert(q.canFind("?targetSense wdt:P5974 ?source"));
    assert(q.canFind("FILTER(?language = wd:Q188)"));
    assert(q.canFind("LIMIT 25"));

    import std.exception : assertThrown;
    assertThrown!Exception(buildSenseRelationsQuery("L123-S1)"));
    assertThrown!Exception(buildSenseRelationsQuery("L5577-S1", "Q0"));
    assertThrown!Exception(buildSenseRelationsQuery("L5577-S1", "", 0));
}

unittest
{
    enum sample = `{
      "results": {"bindings": [
        {
          "relation": {"type":"literal","value":"P5137"},
          "direction": {"type":"literal","value":"shared"},
          "via": {"type":"uri","value":"http://www.wikidata.org/entity/Q146"},
          "targetSense": {"type":"uri","value":"http://www.wikidata.org/entity/L100-S2"},
          "lexeme": {"type":"uri","value":"http://www.wikidata.org/entity/L100"},
          "lemma": {"type":"literal","xml:lang":"de","value":"Katze"},
          "language": {"type":"uri","value":"http://www.wikidata.org/entity/Q188"},
          "category": {"type":"uri","value":"http://www.wikidata.org/entity/Q1084"}
        },
        {
          "relation": {"type":"literal","value":"P5972"},
          "direction": {"type":"literal","value":"incoming"},
          "targetSense": {"type":"uri","value":"http://www.wikidata.org/entity/L101-S1"},
          "lexeme": {"type":"uri","value":"http://www.wikidata.org/entity/L101"},
          "lemma": {"type":"literal","value":"cat"},
          "language": {"type":"uri","value":"http://www.wikidata.org/entity/Q1860"},
          "category": {"type":"uri","value":"http://www.wikidata.org/entity/Q1084"}
        }
      ]}
    }`;

    auto edges = parseSenseRelations(parseJSON(sample), "L5577-S1");
    assert(edges.length == 2);
    assert(edges[0].sourceSenseId == "L5577-S1");
    assert(edges[0].targetSenseId == "L100-S2");
    assert(edges[0].targetLexemeId == "L100");
    assert(edges[0].targetLemma == "Katze");
    assert(edges[0].viaId == "Q146");
    assert(edges[0].propertyId == "P5137");
    assert(edges[0].direction == "shared");
    assert(edges[0].raw["lemma"]["xml:lang"].str == "de");
    assert(edges[1].propertyId == "P5972");
    assert(edges[1].direction == "incoming");
    assert(edges[1].viaId.length == 0);
}
