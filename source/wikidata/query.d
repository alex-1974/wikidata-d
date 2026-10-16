/**
 * Small SPARQL query builders for Wikidata lexicographical entities.
 *
 * This module creates text; it does not contact Wikidata.
 */
module wikidata.query;

import std.exception : enforce;
import std.algorithm.searching : canFind;
import std.format : format;

/**
 * Select the execution plan for Lexeme SPARQL queries.
 *
 * The default keeps the existing query representation byte-for-byte.
 * The Blazegraph option is engine-specific and must be selected explicitly.
 * See_Also: buildLexemeQuery
 */
enum QueryOptimization
{
    automatic, /// Original query with automatic optimization.
    blazegraphLemmaFirst /// Explicit lemma-first join order for Blazegraph.
}

///
unittest
{
    assert(QueryOptimization.automatic != QueryOptimization.blazegraphLemmaFirst);
}

/**
 * Convert user-supplied text into a quoted SPARQL string literal.
 *
 * Use this when constructing SPARQL text from a lemma, label or other
 * literal value. The result includes surrounding double quotes and escapes
 * special characters; append a language tag separately if required.
 *
 * Params:
 *   input = Text to include as one SPARQL string literal.
 * Returns: Quoted, escaped literal ready to insert in SPARQL text.
 * See_Also: buildLexemeQuery
 */
string sparqlString(string input)
{
    string output = "\"";
    foreach (char c; input)
    {
        switch (c)
        {
            case '"': output ~= "\\\""; break;
            case '\\': output ~= "\\\\"; break;
            case '\n': output ~= "\\n"; break;
            case '\r': output ~= "\\r"; break;
            case '\t': output ~= "\\t"; break;
            default:
                if (c < 0x20)
                    output ~= format("\\u%04X", cast(uint) c);
                else
                    output ~= c;
                break;
        }
    }
    return output ~ "\"";
}

///
unittest
{
    // The returned text includes quotes and escapes embedded special characters.
    assert(sparqlString("gatto") == "\"gatto\"");
    assert(sparqlString("a\"b") == "\"a\\\"b\"");
}

/**
 * Check whether a string has the syntax of a Wikidata Q-, L- or P-identifier.
 *
 * Use this for input validation before constructing a query. This checks
 * spelling only: it does not look up the entity or establish that it exists.
 * Forms and Senses have separate identifiers and are not accepted here.
 *
 * Params:
 *   id = Candidate Wikidata identifier, such as `Q146`, `L5577` or `P31`.
 * Returns: `true` for a syntactically valid Q/L/P identifier; otherwise `false`.
 * See_Also: buildLexemeQuery
 */
bool isEntityId(string id)
{
    if (id.length < 2 || (id[0] != 'Q' && id[0] != 'L' && id[0] != 'P'))
        return false;
    if (id[1] < '1' || id[1] > '9')
        return false;
    foreach (char c; id[2 .. $])
        if (c < '0' || c > '9')
            return false;
    return true;
}

///
unittest
{
    assert(isEntityId("Q146")); // Item: cat
    assert(isEntityId("L5577")); // Lexeme identifier
    assert(!isEntityId("Q0"));   // Identifier zero is invalid
    assert(!isEntityId("L5577-F1")); // Form identifiers use another syntax
}

/// Check the language-tag syntax accepted by this module's query builder.
private bool validLanguageCode(string code)
{
    if (code.length == 0)
        return false;
    foreach (char c; code)
        if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-'))
            return false;
    return code[0] >= 'a' && code[0] <= 'z' && code[$ - 1] != '-';
}

/**
 * Create a SPARQL query for finding Wikidata Lexemes by exact written lemma.
 *
 * Use this to discover candidate Lexemes for entries in an independent
 * vocabulary catalogue. A match is a candidate, not a verified translation
 * or a guarantee that every Wikidata Lexeme has been found.
 *
 * Supply the language twice: its code for the written lemma and its
 * Wikidata language item. Optionally restrict the lexical category (part of
 * speech); otherwise the query returns candidates of any category.
 * This function only creates query text and never makes an HTTP request.
 *
 * Params:
 *   languageCode = Written lemma language tag, such as `"it"` or `"sw"`.
 *   languageEntity = Wikidata language item Q-ID, e.g. `"Q652"` for Italian.
 *   lemmas = One or more exact, nonempty written forms to look up.
 *   categoryEntity = Optional lexical-category Q-ID; empty means all categories.
 *   optimization = Optional query execution strategy; defaults to automatic.
 *                  The Blazegraph option requires the Blazegraph backend.
 * Returns: SPARQL query text suitable for a Wikidata Query Service client.
 *          Each matching Lexeme may yield multiple Sense rows; a Lexeme
 *          without a Sense can still appear with an unbound Sense variable.
 * Throws: `Exception` if a language tag, Q-ID or lemma is invalid, or if
 *         no lemmas are supplied.
 * Notes: The query does not prove the absence of a Lexeme when a service
 *        returns no results. Consult the client response and its error status.
 * See_Also: sparqlString, isEntityId
 */
string buildLexemeQuery(
    string languageCode,
    string languageEntity,
    const(string)[] lemmas,
    string categoryEntity = "",
    QueryOptimization optimization = QueryOptimization.automatic)
{
    enforce(validLanguageCode(languageCode), "Invalid language code");
    enforce(isEntityId(languageEntity) && languageEntity[0] == 'Q',
        "Expected a language Q-ID");
    enforce(lemmas.length != 0, "At least one lemma required");
    if (categoryEntity.length)
        enforce(isEntityId(categoryEntity) && categoryEntity[0] == 'Q',
            "Expected a lexical category Q-ID");

    string query =
        "PREFIX wd: <http://www.wikidata.org/entity/>\n"
        ~ "PREFIX wdt: <http://www.wikidata.org/prop/direct/>\n"
        ~ "PREFIX wikibase: <http://wikiba.se/ontology#>\n"
        ~ "PREFIX ontolex: <http://www.w3.org/ns/lemon/ontolex#>\n"
        ~ "PREFIX dct: <http://purl.org/dc/terms/>\n"
        ~ "SELECT ?lemma ?lexeme ?category ?sense ?concept WHERE {\n";

    if (optimization == QueryOptimization.blazegraphLemmaFirst)
    {
        query = "PREFIX hint: <http://www.bigdata.com/queryHints#>\n" ~ query;
        query ~= "  hint:Query hint:optimizer \"None\" .\n";
    }
    query ~= "  VALUES ?lemma {\n";

    foreach (lemma; lemmas)
    {
        enforce(lemma.length != 0, "Empty lemma is not allowed");
        query ~= "    " ~ sparqlString(lemma) ~ "@" ~ languageCode ~ "\n";
    }

    query ~= "  }\n";

    if (optimization == QueryOptimization.blazegraphLemmaFirst)
    {
        query ~= "  ?lexeme wikibase:lemma ?lemma .\n"
            ~ "  ?lexeme dct:language wd:" ~ languageEntity ~ " .\n"
            ~ "  ?lexeme wikibase:lexicalCategory ?category .\n"
            ~ "  ?lexeme a ontolex:LexicalEntry .\n";
    }
    else
    {
        query ~= "  ?lexeme a ontolex:LexicalEntry ;\n"
            ~ "    dct:language wd:" ~ languageEntity ~ " ;\n"
            ~ "    wikibase:lemma ?lemma ;\n"
            ~ "    wikibase:lexicalCategory ?category .\n";
    }

    if (categoryEntity.length)
        query ~= "  FILTER(?category = wd:" ~ categoryEntity ~ ")\n";

    query ~= "  OPTIONAL {\n"
        ~ "    ?lexeme ontolex:sense ?sense .\n"
        ~ "    OPTIONAL { ?sense wdt:P5137 ?concept . }\n"
        ~ "  }\n"
        ~ "}\n";

    return query;
}

///
unittest
{
    // Find exact Italian lemmas, without limiting their part of speech.
    auto query = buildLexemeQuery("it", "Q652", ["gatto", "nero"]);
    assert(query.canFind("\"gatto\"@it"));
    assert(query.canFind("\"nero\"@it"));

    // Add a lexical category when the caller needs a specific part of speech.
    auto nouns = buildLexemeQuery("it", "Q652", ["gatto"], "Q1084");
    assert(nouns.canFind("FILTER(?category = wd:Q1084)"));
}

unittest
{
    assert(sparqlString("gatto") == "\"gatto\"");
    assert(sparqlString("a\"b\\c\n") == "\"a\\\"b\\\\c\\n\"");
    assert(sparqlString("città") == "\"città\"");

    assert(isEntityId("L5577"));
    assert(isEntityId("Q146"));
    assert(!isEntityId("Q0"));
    assert(!isEntityId("Q146) . ?x ?y ?z"));

    auto q = buildLexemeQuery("it", "Q652", ["gatto", "nero", "andare"]);
    assert(q.canFind("\"gatto\"@it"));
    assert(q.canFind("\"nero\"@it"));
    assert(q.canFind("\"andare\"@it"));
    assert(q.canFind("ontolex:sense ?sense"));
    assert(q.canFind("wdt:P5137"));
    assert(!q.canFind("FILTER(?category"));

    auto filtered = buildLexemeQuery("it", "Q652", ["nero"], "Q34698");
    assert(filtered.canFind("FILTER(?category = wd:Q34698)"));
}


///
unittest
{
    // Old callers retain their exact original query representation.
    auto baseline = buildLexemeQuery("it", "Q652", ["gatto"]);
    auto explicitDefault = buildLexemeQuery("it", "Q652", ["gatto"], "",
        QueryOptimization.automatic);
    assert(baseline == explicitDefault);
    assert(baseline.canFind("WHERE {\n  VALUES ?lemma {"));
    assert(!baseline.canFind("hint:optimizer"));

    auto optimized = buildLexemeQuery("it", "Q652", ["gatto"], "",
        QueryOptimization.blazegraphLemmaFirst);
    assert(optimized.canFind("PREFIX hint: <http://www.bigdata.com/queryHints#>"));
    assert(optimized.canFind("WHERE {\n  hint:Query hint:optimizer \"None\" .\n  VALUES"));
    assert(optimized.canFind("?lexeme wikibase:lemma ?lemma"));
    assert(optimized.canFind("?lexeme dct:language wd:Q652"));
    assert(optimized.canFind("?lexeme a ontolex:LexicalEntry"));
    assert(optimized.canFind("ontolex:sense ?sense"));
    assert(optimized.canFind("wdt:P5137"));
    auto filtered = buildLexemeQuery("it", "Q652", ["gatto"], "Q1084",
        QueryOptimization.blazegraphLemmaFirst);
    assert(filtered.canFind("FILTER(?category = wd:Q1084)"));
}
