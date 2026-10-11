/**
 * Independent, language- and level-neutral source vocabulary catalogues.
 * Wikidata lookup results never modify or filter a catalogue.
 */
module wikidata.catalog;

import std.exception : enforce;
import std.file : readText;
import std.json : JSONValue, JSONType, parseJSON;
import wikidata.query : isEntityId;

struct CatalogEntry
{
    string id;                  /// Stable ID from this catalogue.
    string lemma;               /// Original source spelling.
    string lexicalCategoryId;   /// Optional Wikidata POS Q-ID.
    string[] lookupLemmas;      /// Explicit search forms; source lemma retained.
    JSONValue raw;              /// All original source fields.
}

struct VocabularyCatalog
{
    string id;
    string languageCode;        /// For lemma literals (it, de, sw, etc.).
    string languageEntityId;    /// Wikidata language Q-ID.
    string level;               /// A1, A2, ...
    JSONValue source;           /// Origin/rights/version info, as supplied.
    CatalogEntry[] entries;
    JSONValue raw;              /// Full original document.
}

private JSONValue required(JSONValue obj, string key)
{
    enforce(obj.type == JSONType.object, "Expected JSON object");
    auto value = key in obj.object;
    enforce(value !is null, "Missing field: " ~ key);
    return *value;
}

private string requiredString(JSONValue obj, string key)
{
    auto value = required(obj, key);
    enforce(value.type == JSONType.string && value.str.length > 0,
        "Expected nonempty string field: " ~ key);
    return value.str;
}

/// Parse a whole source catalogue, retaining unknown fields and absent matches.
VocabularyCatalog parseCatalog(JSONValue json)
{
    auto schemaVersionValue = required(json, "schemaVersion");
    enforce(schemaVersionValue.type == JSONType.integer && schemaVersionValue.integer == 1,
        "Unsupported catalogue schemaVersion");

    VocabularyCatalog catalog;
    catalog.id = requiredString(json, "id");
    catalog.languageCode = requiredString(json, "languageCode");
    catalog.languageEntityId = requiredString(json, "languageEntityId");
    catalog.level = requiredString(json, "level");
    enforce(isEntityId(catalog.languageEntityId) &&
        catalog.languageEntityId[0] == 'Q', "Expected language Q-ID");
    catalog.source = required(json, "source");
    enforce(catalog.source.type == JSONType.object, "source must be an object");
    catalog.raw = json;

    auto records = required(json, "entries");
    enforce(records.type == JSONType.array, "entries must be an array");
    bool[string] seenIds;
    foreach (record; records.array)
    {
        CatalogEntry entry;
        entry.id = requiredString(record, "id");
        enforce((entry.id in seenIds) is null,
            "Duplicate entry ID: " ~ entry.id);
        seenIds[entry.id] = true;
        entry.lemma = requiredString(record, "lemma");
        auto category = "lexicalCategoryId" in record.object;
        if (category !is null)
        {
            enforce((*category).type == JSONType.string,
                "Invalid lexicalCategoryId");
            entry.lexicalCategoryId = (*category).str;
            enforce(isEntityId(entry.lexicalCategoryId) &&
                entry.lexicalCategoryId[0] == 'Q', "Expected POS Q-ID");
        }
        auto search = "lookupLemmas" in record.object;
        if (search is null)
            entry.lookupLemmas = [entry.lemma];
        else
        {
            enforce((*search).type == JSONType.array &&
                (*search).array.length != 0, "Invalid lookupLemmas");
            foreach (variant; (*search).array)
            {
                enforce(variant.type == JSONType.string &&
                    variant.str.length != 0, "Invalid lookup lemma");
                entry.lookupLemmas ~= variant.str;
            }
        }
        entry.raw = record;
        catalog.entries ~= entry;
    }
    return catalog;
}

VocabularyCatalog parseCatalog(string jsonText)
{
    return parseCatalog(parseJSON(jsonText));
}

VocabularyCatalog loadCatalog(string path)
{
    return parseCatalog(readText(path));
}

unittest
{
    enum input = `{
      "schemaVersion":1,"id":"it-A1-demo","languageCode":"it",
      "languageEntityId":"Q652","level":"A1",
      "source":{"name":"Test fixture","version":"1"},
      "entries":[
        {"id":"01","lemma":"gatto","lexicalCategoryId":"Q1084","position":1},
        {"id":"02","lemma":"nero","lexicalCategoryId":"Q34698"},
        {"id":"03","lemma":"amico/a","lexicalCategoryId":"Q1084",
         "lookupLemmas":["amico","amica"]}
      ], "unrecognizedFutureField":{"keep":true}
    }`;
    auto c = parseCatalog(input);
    assert(c.entries.length == 3);
    assert(c.entries[1].lexicalCategoryId == "Q34698");
    assert(c.entries[2].lemma == "amico/a");
    assert(c.entries[2].lookupLemmas.length == 2);
    assert(c.entries[0].raw["position"].integer == 1);
    assert(c.raw["unrecognizedFutureField"]["keep"].boolean);

    import std.exception : assertThrown;
    assertThrown!Exception(parseCatalog(`{"schemaVersion":1,"id":"x"}`));
    assertThrown!Exception(parseCatalog(`{
      "schemaVersion":1,"id":"x","languageCode":"it",
      "languageEntityId":"Q652","level":"A1","source":{},
      "entries":[{"id":"1","lemma":"a"},{"id":"1","lemma":"b"}]
    }`));
}
