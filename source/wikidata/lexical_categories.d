/**
 * Wikidata P279-based compatibility of lexical categories.
 *
 * Match relations are read from Wikidata, not hard-coded by language.
 * They must never be used to rewrite catalogue source annotations.
 */
module wikidata.lexical_categories;

import std.algorithm.searching : canFind, startsWith;
import std.exception : enforce;
import std.json : JSONValue, JSONType;
import wikidata.query : isEntityId;

struct CategoryCompatibility
{
    private string[][string] ancestorsByCategory;

    void add(string category, string ancestor)
    {
        enforce(isEntityId(category) && category[0] == 'Q',
            "Expected lexical-category Q-ID");
        enforce(isEntityId(ancestor) && ancestor[0] == 'Q',
            "Expected ancestor Q-ID");
        auto current = category in ancestorsByCategory;
        if (current is null || !(*current).canFind(ancestor))
            ancestorsByCategory[category] ~= ancestor;
    }

    /// A category is compatible if it equals or is a Wikidata subclass of expected.
    bool compatible(string category, string expected) const
    {
        if (category == expected)
            return true;
        auto ancestors = category in ancestorsByCategory;
        return ancestors !is null && (*ancestors).canFind(expected);
    }
}

/// Generate a bounded query for the observed POS IDs and catalogue POS IDs.
string buildCategoryCompatibilityQuery(
    const(string)[] observedCategories,
    const(string)[] expectedCategories)
{
    enforce(observedCategories.length > 0 && expectedCategories.length > 0,
        "At least one observed and expected category is required");
    string output =
        "PREFIX wd: <http://www.wikidata.org/entity/>\n"
        ~ "PREFIX wdt: <http://www.wikidata.org/prop/direct/>\n"
        ~ "SELECT DISTINCT ?category ?ancestor WHERE {\n"
        ~ "  VALUES ?category {\n";
    bool[string] seen;
    foreach (id; observedCategories)
    {
        enforce(isEntityId(id) && id[0] == 'Q', "Invalid observed category ID");
        if ((id in seen) is null)
        {
            seen[id] = true;
            output ~= "    wd:" ~ id ~ "\n";
        }
    }
    output ~= "  }\n  VALUES ?ancestor {\n";
    seen = null;
    foreach (id; expectedCategories)
    {
        enforce(isEntityId(id) && id[0] == 'Q', "Invalid expected category ID");
        if ((id in seen) is null)
        {
            seen[id] = true;
            output ~= "    wd:" ~ id ~ "\n";
        }
    }
    output ~= "  }\n  ?category wdt:P279+ ?ancestor .\n}\n";
    return output;
}

private string bindingQId(JSONValue row, string key)
{
    enforce(row.type == JSONType.object, "Invalid SPARQL row");
    auto term = key in row.object;
    enforce(term !is null && (*term).type == JSONType.object,
        "Missing SPARQL binding: " ~ key);
    auto value = "value" in (*term).object;
    enforce(value !is null && (*value).type == JSONType.string,
        "Invalid SPARQL binding: " ~ key);
    enum http = "http://www.wikidata.org/entity/";
    enum https = "https://www.wikidata.org/entity/";
    auto uri = (*value).str;
    string id;
    if (uri.startsWith(http))
        id = uri[http.length .. $];
    else if (uri.startsWith(https))
        id = uri[https.length .. $];
    else
        throw new Exception("Unexpected Wikidata entity URI: " ~ uri);
    enforce(isEntityId(id) && id[0] == 'Q', "Expected Q-ID in category query");
    return id;
}

CategoryCompatibility parseCategoryCompatibility(JSONValue response)
{
    enforce(response.type == JSONType.object, "Invalid category response");
    auto results = "results" in response.object;
    enforce(results !is null && (*results).type == JSONType.object,
        "Missing category-query results");
    auto bindings = "bindings" in (*results).object;
    enforce(bindings !is null && (*bindings).type == JSONType.array,
        "Missing category-query bindings");
    CategoryCompatibility compatibility;
    foreach (row; (*bindings).array)
        compatibility.add(bindingQId(row, "category"),
            bindingQId(row, "ancestor"));
    return compatibility;
}

unittest
{
    import std.json : parseJSON;
    auto q = buildCategoryCompatibilityQuery(
        ["Q468801", "Q2865743", "Q9788", "Q468801"],
        ["Q36224", "Q103184"]);
    assert(q.canFind("wdt:P279+"));
    assert(q.canFind("wd:Q468801"));
    auto relations = parseCategoryCompatibility(parseJSON(`{
      "results":{"bindings":[
        {"category":{"value":"http://www.wikidata.org/entity/Q468801"},
         "ancestor":{"value":"http://www.wikidata.org/entity/Q36224"}},
        {"category":{"value":"http://www.wikidata.org/entity/Q2865743"},
         "ancestor":{"value":"http://www.wikidata.org/entity/Q103184"}}
      ]}}`));
    assert(relations.compatible("Q468801", "Q36224"));
    assert(relations.compatible("Q2865743", "Q103184"));
    assert(relations.compatible("Q9788", "Q9788"));
    assert(!relations.compatible("Q9788", "Q103184"));
    assert(!relations.compatible("Q36224", "Q468801"));
}
