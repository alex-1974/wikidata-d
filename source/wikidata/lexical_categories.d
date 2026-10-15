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

/**
 * Look up whether one lexical category is identical to, or a known subtype of,
 * another lexical category.
 *
 * Add only category-to-ancestor relationships from evidence you trust, such
 * as the result of $(D parseCategoryCompatibility). A missing relationship
 * returns $(D false); it does not prove that Wikidata contains no relation.
 *
 * This object does not alter catalogues or infer grammatical forms.
 * See_Also: buildCategoryCompatibilityQuery, parseCategoryCompatibility
 */
struct CategoryCompatibility
{
    private string[][string] ancestorsByCategory;

    /**
     * Record one observed category-to-ancestor relation for later lookup.
     *
     * Params:
     *   category = Lexical category Q-ID to classify.
     *   ancestor = Parent/ancestor category Q-ID returned by a trusted source.
     * Throws: $(D Exception) for invalid Q-ID syntax.
     * Notes: Recording a relation does not contact Wikidata and does not
     *        verify whether the relationship is actually true.
     */
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

    /**
     * Decide whether a candidate category is acceptable for an expected one.
     *
     * Params:
     *   category = Candidate lexical-category Q-ID.
     *   expected = Required lexical-category Q-ID.
     * Returns: $(D true) for identical IDs or a previously added ancestor
     *          relation; otherwise $(D false).
     * Notes: Does not query Wikidata, calculate unrecorded relations or
     *        validate the input IDs. Unknown evidence is not a positive match.
     * See_Also: add
     */
    bool compatible(string category, string expected) const
    {
        if (category == expected)
            return true;
        auto ancestors = category in ancestorsByCategory;
        return ancestors !is null && (*ancestors).canFind(expected);
    }
}

///
unittest
{
    CategoryCompatibility categories;
    categories.add("Q468801", "Q36224"); // Relation observed in query results.
    assert(categories.compatible("Q468801", "Q36224"));
    assert(categories.compatible("Q468801", "Q468801")); // Same category.
    assert(!categories.compatible("Q36224", "Q468801")); // Not reversible.
}

/**
 * Build a SPARQL query to find subclass relationships between categories.
 *
 * Use this to compare lexical categories returned for Lexemes with category
 * restrictions from an independent vocabulary catalogue. Execute the query
 * with your own Wikidata client and pass its JSON response to
 * $(D parseCategoryCompatibility). No HTTP request happens here.
 *
 * Params:
 *   observedCategories = Nonempty list of candidate lexical-category Q-IDs.
 *   expectedCategories = Nonempty list of catalogue lexical-category Q-IDs.
 * Returns: SPARQL text restricting both lists and selecting matching
 *          $(D ?category)/$(D ?ancestor) pairs reachable via P279+.
 * Throws: $(D Exception) if either list is empty or an ID is not a Q-ID.
 * Notes: Missing query rows must not be interpreted as proof that no
 *        relationship exists outside the queried data.
 * See_Also: parseCategoryCompatibility
 */
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

/// Read and validate a Wikidata Q-ID from one SPARQL binding term.
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

/**
 * Read category compatibility evidence from a SPARQL JSON result.
 *
 * The response should come from $(D buildCategoryCompatibilityQuery),
 * preserving each returned category-to-ancestor relation. An empty valid
 * bindings array produces an empty compatibility lookup.
 *
 * Params:
 *   response = Parsed SPARQL JSON object with results.bindings rows.
 * Returns: A lookup whose $(D compatible) method accepts recorded ancestors.
 * Throws: $(D Exception) for missing, malformed, or invalid Q-ID bindings.
 * Notes: This parser validates shape and identifiers, not factual truth.
 * See_Also: CategoryCompatibility, buildCategoryCompatibilityQuery
 */
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

///
unittest
{
    // Prepare a bounded category query for an observed part of speech.
    auto text = buildCategoryCompatibilityQuery(["Q468801"], ["Q36224"]);
    assert(text.canFind("wdt:P279+"));

    // Parse one sample server response without making a network request.
    import std.json : parseJSON;
    auto evidence = parseCategoryCompatibility(parseJSON(`{"results":{"bindings":[
      {"category":{"value":"http://www.wikidata.org/entity/Q468801"},
       "ancestor":{"value":"http://www.wikidata.org/entity/Q36224"}}
    ]}}`));
    assert(evidence.compatible("Q468801", "Q36224"));
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
