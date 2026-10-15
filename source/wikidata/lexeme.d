/**
 * Typed, lossless view of a Wikibase Lexeme entity.
 *
 * The raw JSON for each lexeme, form, sense, and statement is retained so
 * additions to Wikidata's property inventory do not require schema changes.
 * No network or GUI dependencies.
 */
module wikidata.lexeme;

import std.exception : enforce;
import std.json : JSONType, JSONValue, parseJSON;

/**
 * A Wikibase statement with its original JSON retained.
 *
 * Use $(D propertyId) to identify the property, $(D targetId) when its main
 * value is an entity ID, and $(D raw) for qualifiers, references, rank and
 * value details. An empty target ID does not mean that no value exists.
 * Notes: Copying this struct does not promise a deep copy of JSON values.
 * See_Also: readStatements
 */
struct WikidataStatement
{
    string propertyId; /// Statement property identifier (for example, P5137).
    string targetId;   /// Main-value entity ID, or empty for other value kinds.
    JSONValue raw;     /// Complete original statement JSON.
}

/**
 * A Form belonging to one Wikidata Lexeme.
 *
 * Identifiers and grammatical feature IDs are available directly. Written
 * representations and other original fields remain in $(D raw).
 * Notes: This is not a Sense or a translation.
 * See_Also: WikidataLexeme, parseLexeme
 */
struct WikidataForm
{
    string id;
    string[] grammaticalFeatures; /// Wikidata grammatical-feature entity IDs.
    WikidataStatement[] statements; /// Statements attached to this Form.
    JSONValue raw; /// Complete original Form JSON including representations.
}

/**
 * A Sense belonging to one Lexeme, not an inflected Form.
 *
 * Consult $(D raw) for original multilingual glosses and properties not
 * projected into the typed fields. The parser does not verify translations.
 * See_Also: WikidataLexeme, parseLexeme
 */
struct WikidataSense
{
    string id;
    WikidataStatement[] statements;
    JSONValue raw;
}

/**
 * A single Wikidata Lexeme with its Forms, Senses and original data.
 *
 * Use this to inspect the distinct Lexeme, Form and Sense identifiers while
 * retaining the source JSON in $(D raw). No catalogue entry is changed.
 * Notes: JSON and array members do not gain deep-copy isolation on struct copy.
 * See_Also: parseLexeme, WikidataForm, WikidataSense
 */
struct WikidataLexeme
{
    string id; /// Original Wikidata Lexeme ID.
    string languageId; /// Language item ID returned by Wikidata.
    string lexicalCategoryId; /// Lexical-category item ID returned by Wikidata.
    WikidataForm[] forms; /// Separate Forms belonging to this Lexeme.
    WikidataSense[] senses; /// Separate Senses belonging to this Lexeme.
    WikidataStatement[] statements; /// Lexeme-level statements.
    JSONValue raw; /// Complete original Lexeme JSON, including unknown fields.
}

/// Require a JSON object and report a descriptive validation error.
private void requireObject(JSONValue value, string description)
{
    enforce(value.type == JSONType.object, description ~ " must be a JSON object");
}

/// Read a required string field from a JSON object.
private string requireString(JSONValue value, string key)
{
    requireObject(value, "Entity");
    auto field = key in value.object;
    enforce(field !is null && (*field).type == JSONType.string,
        "Missing or invalid string field: " ~ key);
    return (*field).str;
}

/// Return an optional JSON array, rejecting malformed present values.
private JSONValue[] optionalArray(JSONValue value, string key)
{
    requireObject(value, "Entity");
    auto field = key in value.object;
    if (field is null)
        return null;
    enforce((*field).type == JSONType.array,
        "Invalid array field: " ~ key);
    return (*field).array;
}

/// Read the entity ID in a statement main value, when present.
private string statementTarget(JSONValue statement)
{
    auto mainsnak = "mainsnak" in statement.object;
    if (mainsnak is null || (*mainsnak).type != JSONType.object)
        return "";
    auto dataValue = "datavalue" in (*mainsnak).object;
    if (dataValue is null || (*dataValue).type != JSONType.object)
        return "";
    auto value = "value" in (*dataValue).object;
    if (value is null || (*value).type != JSONType.object)
        return "";
    auto id = "id" in (*value).object;
    if (id is null || (*id).type != JSONType.string)
        return "";
    return (*id).str;
}

/**
 * Read every statement from an entity's claims object.
 *
 * Use this to inspect all properties without restricting the property set.
 * The original statement JSON is retained, including unknown details.
 *
 * Params:
 *   entity = A Lexeme, Form, Sense or other JSON object containing claims.
 * Returns: Statements found in claims, or an empty array if claims is absent.
 * Throws: $(D Exception) if the entity, claims or statement-group structure
 *         is malformed.
 * Notes: Only entity-valued main values expose a nonempty targetId.
 * See_Also: WikidataStatement, parseLexeme
 */
WikidataStatement[] readStatements(JSONValue entity)
{
    requireObject(entity, "Entity");
    WikidataStatement[] result;
    auto claims = "claims" in entity.object;
    if (claims is null)
        return result;

    enforce((*claims).type == JSONType.object, "Claims must be an object");
    foreach (string propertyId, JSONValue values; (*claims).object)
    {
        enforce(values.type == JSONType.array,
            "Statement group must be an array: " ~ propertyId);
        foreach (statement; values.array)
        {
            requireObject(statement, "Statement");
            result ~= WikidataStatement(
                propertyId, statementTarget(statement), statement);
        }
    }
    return result;
}

/**
 * Parse one Wikidata Lexeme entity into typed fields and preserved source JSON.
 *
 * Pass the individual Lexeme object returned by wbgetentities, not the
 * enclosing $(D entities) response. This operation is local and makes no
 * network request. Forms and Senses remain separate and retain original IDs.
 *
 * Params:
 *   entity = Parsed JSON object for one Lexeme.
 * Returns: A WikidataLexeme with typed IDs, Forms, Senses and statements.
 * Throws: $(D Exception) when the Lexeme is missing or required fields and
 *         nested structures have invalid shapes.
 * Notes: Unknown fields remain in raw; this parser does not infer missing
 *        Forms, Senses, translations or grammatical facts. A struct copy is
 *        not a deep-copy guarantee for arrays or JSON values.
 * See_Also: WikidataLexeme, readStatements, parseLexeme
 */
WikidataLexeme parseLexeme(JSONValue entity)
{
    requireObject(entity, "Lexeme");
    enforce(("missing" in entity.object) is null, "Lexeme does not exist");

    WikidataLexeme result;
    result.id = requireString(entity, "id");
    enforce(result.id.length > 1 && result.id[0] == 'L',
        "Expected a Lexeme entity ID");
    result.languageId = requireString(entity, "language");
    result.lexicalCategoryId = requireString(entity, "lexicalCategory");
    result.statements = readStatements(entity);
    result.raw = entity;

    foreach (form; optionalArray(entity, "forms"))
    {
        requireObject(form, "Form");
        WikidataForm item;
        item.id = requireString(form, "id");
        foreach (feature; optionalArray(form, "grammaticalFeatures"))
        {
            enforce(feature.type == JSONType.string,
                "Grammatical feature must be an entity ID string");
            item.grammaticalFeatures ~= feature.str;
        }
        item.statements = readStatements(form);
        item.raw = form;
        result.forms ~= item;
    }

    foreach (sense; optionalArray(entity, "senses"))
    {
        requireObject(sense, "Sense");
        WikidataSense item;
        item.id = requireString(sense, "id");
        item.statements = readStatements(sense);
        item.raw = sense;
        result.senses ~= item;
    }

    return result;
}

/**
 * Parse the JSON text of one standalone Wikidata Lexeme entity.
 *
 * Params:
 *   jsonText = Serialized Lexeme object, not a complete API envelope.
 * Returns: A typed Lexeme with original JSON preserved.
 * Throws: $(D Exception) for invalid Lexeme data; JSON parsing may throw
 *         on malformed JSON text.
 * Notes: This operation does not fetch a Lexeme from Wikidata.
 * See_Also: parseLexeme
 */
WikidataLexeme parseLexeme(string jsonText)
{
    return parseLexeme(parseJSON(jsonText));
}

///
unittest
{
    // A compact offline Lexeme with a Form and an independently identified Sense.
    auto lexeme = parseLexeme(`{
      "id":"L42", "language":"Q652", "lexicalCategory":"Q1084",
      "forms":[{"id":"L42-F1","grammaticalFeatures":[],"representations":{}}],
      "senses":[{"id":"L42-S1","glosses":{}}], "futureField":17
    }`);
    assert(lexeme.id == "L42");
    assert(lexeme.forms[0].id == "L42-F1");
    assert(lexeme.senses[0].id == "L42-S1");
    assert(lexeme.raw["futureField"].integer == 17); // Unknown source fields survive.

    // Missing claims are an ordinary empty result, not an invented statement.
    assert(readStatements(parseJSON(`{"id":"L42"}`)).length == 0);
}

unittest
{
    // Synthetic fixture (not a snapshot of a live Wikidata revision).
    enum fixture = `{
      "id":"L5577", "type":"lexeme", "language":"Q652",
      "lexicalCategory":"Q1084",
      "lemmas":{"it":{"language":"it","value":"gatto"}},
      "claims":{"P5185":[{"mainsnak":{"datavalue":{"value":{"id":"Q499327"}}}}]},
      "forms":[{
        "id":"L5577-F1",
        "representations":{"it":{"language":"it","value":"gatto"}},
        "grammaticalFeatures":["Q110786"],
        "claims":{"P898":[{"mainsnak":{"datavalue":{"value":"/ˈɡat.to/"}}}]}
      }],
      "senses":[
        {"id":"L5577-S1","glosses":{"de":{"language":"de","value":"Katze"}},
         "claims":{"P5137":[{"mainsnak":{"datavalue":{"value":{"id":"Q146"}}},
            "qualifiers":{"P1":[]},"references":[],"rank":"preferred"}],
                   "P5972":[{"mainsnak":{"datavalue":{"value":{"id":"L511-S1"}}}}]}},
        {"id":"L5577-S2","glosses":{},
         "claims":{"P5137":[{"mainsnak":{"datavalue":{"value":{"id":"Q2961480"}}}}]}}
      ],
      "unexpectedFutureField":{"preserve":true}
    }`;

    auto lexeme = parseLexeme(fixture);
    assert(lexeme.id == "L5577");
    assert(lexeme.languageId == "Q652");
    assert(lexeme.lexicalCategoryId == "Q1084");
    assert(lexeme.forms.length == 1);
    assert(lexeme.forms[0].id == "L5577-F1");
    assert(lexeme.forms[0].grammaticalFeatures[0] == "Q110786");
    assert(lexeme.forms[0].raw["representations"]["it"]["value"].str == "gatto");
    assert(lexeme.forms[0].statements.length == 1);
    assert(lexeme.forms[0].statements[0].propertyId == "P898");
    assert(lexeme.forms[0].statements[0].targetId.length == 0); // IPA is text
    assert(lexeme.senses.length == 2);
    assert(lexeme.senses[0].statements.length == 2);
    assert(lexeme.senses[0].raw["glosses"]["de"]["value"].str == "Katze");
    assert(lexeme.senses[0].raw["claims"]["P5137"][0]["rank"].str == "preferred");
    assert(lexeme.raw["unexpectedFutureField"]["preserve"].boolean);

    bool foundConcept = false;
    bool foundTranslation = false;
    foreach (statement; lexeme.senses[0].statements)
    {
        if (statement.propertyId == "P5137" && statement.targetId == "Q146")
            foundConcept = true;
        if (statement.propertyId == "P5972" && statement.targetId == "L511-S1")
            foundTranslation = true;
    }
    assert(foundConcept && foundTranslation);
    assert(lexeme.statements.length == 1);
}

unittest
{
    enum fixture = `{
        "id":"L38246", "language":"Q652", "lexicalCategory":"Q24905",
        "forms":[],
        "senses":[{"id":"L38246-S1","claims":{
            "P9970":[{"mainsnak":{"datavalue":{"value":{"id":"Q19279529"}}}}],
            "P5972":[{"mainsnak":{"datavalue":{"value":{"id":"L3006-S1"}}}}]
        }}]
    }`;
    auto verb = parseLexeme(fixture);
    assert(verb.forms.length == 0);
    assert(verb.senses.length == 1);
    assert(verb.senses[0].statements.length == 2);

    auto invalid = parseJSON(`{"id":"L9","missing":""}`);
    import std.exception : assertThrown;
    assertThrown!Exception(parseLexeme(invalid));
}
