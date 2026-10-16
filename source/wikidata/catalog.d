/**
 * Independent, language- and level-neutral source vocabulary catalogues.
 * Wikidata lookup results never modify or filter a catalogue.
 */
module wikidata.catalog;

import std.exception : enforce;
import std.file : readText;
import std.json : JSONValue, JSONType, parseJSON;
import wikidata.query : isEntityId;

/**
 * One exact lookup spelling and optional part-of-speech restriction.
 *
 * A catalogue entry may supply several targets while remaining one record.
 * The ID describes the expected Wikidata category, not a verified match.
 * See_Also: CatalogEntry, parseCatalog
 */
struct CatalogLookupTarget
{
    string lemma; /// Exact spelling to search in Wikidata.
    string lexicalCategoryId; /// Optional expected Wikidata POS Q-ID.
}

/**
 * An original source-catalogue entry and its independent lookup targets.
 *
 * Use raw for source metadata and lookupTargets for Lexeme searches.
 * Several targets do not split, delete or replace this entry.
 * See_Also: VocabularyCatalog, CatalogLookupTarget
 */
struct CatalogEntry
{
    string id; /// Stable identifier assigned by the source catalogue.
    string lemma; /// Original source spelling, unchanged by lookup.
    string lexicalCategoryId; /// Optional entry-level Wikidata POS Q-ID.
    string[] lookupLemmas; /// Search spellings retained for existing consumers.
    CatalogLookupTarget[] lookupTargets; /// Searches and optional per-variant POS.
    JSONValue raw; /// Complete original catalogue-entry JSON.
}

/**
 * Complete independent vocabulary catalogue for any language and level.
 *
 * Every source entry remains present regardless of Wikidata coverage.
 * The source metadata and complete original document are preserved.
 * See_Also: parseCatalog, loadCatalog
 */
struct VocabularyCatalog
{
    string id; /// Catalogue identifier from the original document.
    string languageCode; /// Language tag for lemma literals, such as it or sw.
    string languageEntityId; /// Wikidata language item Q-ID.
    string level; /// Source learning level, such as A1 or A2.
    JSONValue source; /// Source metadata exactly as supplied.
    CatalogEntry[] entries; /// All catalogue entries in source order.
    JSONValue raw; /// Full original catalogue JSON.
}

/// Return a mandatory JSON field or reject a missing field.
private JSONValue required(JSONValue obj, string key)
{
    enforce(obj.type == JSONType.object, "Expected JSON object");
    auto value = key in obj.object;
    enforce(value !is null, "Missing field: " ~ key);
    return *value;
}

/// Return a required nonempty string field or reject it.
private string requiredString(JSONValue obj, string key)
{
    auto value = required(obj, key);
    enforce(value.type == JSONType.string && value.str.length > 0,
        "Expected nonempty string field: " ~ key);
    return value.str;
}

/**
 * Parse a full source vocabulary catalogue without consulting Wikidata.
 *
 * All entries remain in source order even if no Lexeme matches them. An
 * entry may have multiple lookup spellings or per-variant lookup targets;
 * neither changes its original lemma or raw source record.
 *
 * Params:
 *   json = Catalogue JSON object using schemaVersion 1.
 * Returns: The complete catalogue with source metadata and original JSON.
 * Throws: $(D Exception) for unsupported schema versions, missing required
 *         fields, duplicate entry IDs, malformed category Q-IDs or invalid
 *         lookup targets. lookupLemmas and lookupTargets cannot coexist.
 * Notes: A valid catalogue does not imply Wikidata coverage. Copying its
 *        structs does not guarantee independent copies of arrays or JSON.
 * See_Also: CatalogEntry, CatalogLookupTarget, loadCatalog
 */
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
        auto targets = "lookupTargets" in record.object;
        enforce(search is null || targets is null,
            "Use lookupLemmas or lookupTargets, not both");
        if (targets !is null)
        {
            enforce((*targets).type == JSONType.array &&
                (*targets).array.length != 0, "Invalid lookupTargets");
            foreach (targetRecord; (*targets).array)
            {
                enforce(targetRecord.type == JSONType.object,
                    "Lookup target must be an object");
                CatalogLookupTarget target;
                target.lemma = requiredString(targetRecord, "lemma");
                auto targetCategory = "lexicalCategoryId" in targetRecord.object;
                if (targetCategory !is null)
                {
                    enforce((*targetCategory).type == JSONType.string,
                        "Invalid lookup target category");
                    target.lexicalCategoryId = (*targetCategory).str;
                    enforce(isEntityId(target.lexicalCategoryId) &&
                        target.lexicalCategoryId[0] == 'Q',
                        "Expected target POS Q-ID");
                }
                entry.lookupTargets ~= target;
                entry.lookupLemmas ~= target.lemma;
            }
        }
        else
        {
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
            foreach (variant; entry.lookupLemmas)
                entry.lookupTargets ~= CatalogLookupTarget(
                    variant, entry.lexicalCategoryId);
        }
        entry.raw = record;
        catalog.entries ~= entry;
    }
    return catalog;
}

///
unittest
{
    // Keep a missing Wikidata match in the independent source catalogue.
    auto document = parseJSON(`{"schemaVersion":1,"id":"example",
      "languageCode":"it","languageEntityId":"Q652","level":"A1",
      "source":{},"entries":[{"id":"1","lemma":"gatto"}]}`);
    auto catalogue = parseCatalog(document);
    assert(catalogue.entries.length == 1);
    assert(catalogue.entries[0].lemma == "gatto");
}


/**
 * Parse the serialized JSON text of a complete vocabulary catalogue.
 *
 * Params:
 *   jsonText = A schemaVersion 1 catalogue JSON document.
 * Returns: All original catalogue entries and source metadata.
 * Throws: $(D Exception) for invalid catalogue fields; malformed JSON text
 *         may also raise a JSON parse exception.
 * See_Also: parseCatalog, loadCatalog
 */
VocabularyCatalog parseCatalog(string jsonText)
{
    return parseCatalog(parseJSON(jsonText));
}

///
unittest
{
    // Each independent source entry stays one record, even with two spellings.
    auto catalogue = parseCatalog(`{"schemaVersion":1,"id":"example",
      "languageCode":"it","languageEntityId":"Q652","level":"A1",
      "source":{},"entries":[{"id":"1","lemma":"amico/a",
      "lookupLemmas":["amico","amica"]}]}`);
    assert(catalogue.entries.length == 1);
    assert(catalogue.entries[0].lookupTargets.length == 2);
}


/**
 * Load a complete independent vocabulary catalogue from a local file.
 *
 * Params:
 *   path = Path to a UTF-8 JSON catalogue document.
 * Returns: The parsed catalogue without filtering missing Wikidata matches.
 * Throws: File read errors, malformed JSON or invalid catalogue data.
 * Notes: Reading this file does not contact Wikidata.
 * See_Also: parseCatalog
 */
VocabularyCatalog loadCatalog(string path)
{
    return parseCatalog(readText(path));
}

///
unittest
{
    // One original entry can produce two lookup targets, without duplication.
    auto catalogue = parseCatalog(`{
      "schemaVersion":1,"id":"example","languageCode":"it",
      "languageEntityId":"Q652","level":"A1","source":{"name":"example"},
      "entries":[{"id":"1","lemma":"amico/a","sourceNote":"original",
        "lookupTargets":[{"lemma":"amico"},{"lemma":"amica"}]}]
    }`);
    assert(catalogue.entries.length == 1);
    assert(catalogue.entries[0].lemma == "amico/a");
    assert(catalogue.entries[0].lookupTargets.length == 2);
    assert(catalogue.entries[0].raw["sourceNote"].str == "original");
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
    assert(c.entries[0].lookupTargets.length == 1);
    assert(c.entries[0].lookupTargets[0].lexicalCategoryId == "Q1084");
    assert(c.entries[2].lookupTargets.length == 2);

    // Original catalogue row stays one row even with multiple POS targets.
    auto multi = parseCatalog(`{
      "schemaVersion":1,"id":"it-A1-perugia-probe","languageCode":"it",
      "languageEntityId":"Q652","level":"A1","source":{},
      "entries":[{"id":"334","lemma":"piacere", "originalPos":"v.int. - s.m.",
        "lookupTargets":[
          {"lemma":"piacere","lexicalCategoryId":"Q24905"},
          {"lemma":"piacere","lexicalCategoryId":"Q1084"}]}]
    }`);
    assert(multi.entries.length == 1);
    assert(multi.entries[0].lookupTargets.length == 2);
    assert(multi.entries[0].raw["originalPos"].str == "v.int. - s.m.");

    import std.exception : assertThrown;
    assertThrown!Exception(parseCatalog(`{"schemaVersion":1,"id":"x"}`));
    assertThrown!Exception(parseCatalog(`{
      "schemaVersion":1,"id":"x","languageCode":"it",
      "languageEntityId":"Q652","level":"A1","source":{},
      "entries":[{"id":"1","lemma":"a"},{"id":"1","lemma":"b"}]
    }`));
    assertThrown!Exception(parseCatalog(`{
      "schemaVersion":1,"id":"x","languageCode":"it",
      "languageEntityId":"Q652","level":"A1","source":{},
      "entries":[{"id":"1","lemma":"a","lookupTargets":[]}]
    }`));
}
