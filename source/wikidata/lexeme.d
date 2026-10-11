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

/// A statement and its complete original Wikibase JSON, including qualifiers,
/// references, snak type, value, and rank.
struct WikidataStatement
{
    string propertyId;
    string targetId; // Present only when the main value contains an entity ID.
    JSONValue raw;
}

/// One Wikidata Form; representations remain available in the raw JSON.
struct WikidataForm
{
    string id;
    string[] grammaticalFeatures;
    WikidataStatement[] statements;
    JSONValue raw;
}

/// One Wikidata Sense; multilingual glosses remain available in the raw JSON.
struct WikidataSense
{
    string id;
    WikidataStatement[] statements;
    JSONValue raw;
}

/// An individual Wikidata Lexeme, not a collapsed spelling or translation.
struct WikidataLexeme
{
    string id;
    string languageId;
    string lexicalCategoryId;
    WikidataForm[] forms;
    WikidataSense[] senses;
    WikidataStatement[] statements;
    JSONValue raw;
}

private void requireObject(JSONValue value, string description)
{
    enforce(value.type == JSONType.object, description ~ " must be a JSON object");
}

private string requireString(JSONValue value, string key)
{
    requireObject(value, "Entity");
    auto field = key in value.object;
    enforce(field !is null && (*field).type == JSONType.string,
        "Missing or invalid string field: " ~ key);
    return (*field).str;
}

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

/// Extract all statements without limiting the set of recognized properties.
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
 * Decode a full Lexeme entity returned by Wikidata's wbgetentities API.
 *
 * Parameters: entity = the individual JSON entity, not the enclosing
 *                        {"entities": {"L123": ...}} API response.
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

/// Handy overload when working with a serialized standalone entity.
WikidataLexeme parseLexeme(string jsonText)
{
    return parseLexeme(parseJSON(jsonText));
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
