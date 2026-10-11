/**
 * Small SPARQL query builders for Wikidata lexicographical entities.
 *
 * This module creates text; it does not contact Wikidata.
 */
module wikidata.query;

import std.exception : enforce;
import std.algorithm.searching : canFind;
import std.format : format;

/// Escape a UTF-8 string for a double-quoted SPARQL string literal.
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

/// Validate a Wikidata Q/L/P entity identifier before placing it in SPARQL.
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
 * Build a lexeme discovery query.
 *
 * Params:
 *   languageCode = Lexeme representation language (e.g. "it", "de", "sw").
 *   languageEntity = Wikidata item identifying that language (e.g. "Q652").
 *   lemmas = Exact written lemmas. All candidate lexical categories are returned.
 *   categoryEntity = Optional lexical category Q-ID; empty means no POS filter.
 *
 * Returns: SPARQL text. A result row is returned for each available sense;
 *          lexemes without senses are returned with unbound ?sense.
 */
string buildLexemeQuery(
    string languageCode,
    string languageEntity,
    const(string)[] lemmas,
    string categoryEntity = "")
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
        ~ "SELECT ?lemma ?lexeme ?category ?sense ?concept WHERE {\n"
        ~ "  VALUES ?lemma {\n";

    foreach (lemma; lemmas)
    {
        enforce(lemma.length != 0, "Empty lemma is not allowed");
        query ~= "    " ~ sparqlString(lemma) ~ "@" ~ languageCode ~ "\n";
    }

    query ~= "  }\n"
        ~ "  ?lexeme a ontolex:LexicalEntry ;\n"
        ~ "    dct:language wd:" ~ languageEntity ~ " ;\n"
        ~ "    wikibase:lemma ?lemma ;\n"
        ~ "    wikibase:lexicalCategory ?category .\n";

    if (categoryEntity.length)
        query ~= "  FILTER(?category = wd:" ~ categoryEntity ~ ")\n";

    query ~= "  OPTIONAL {\n"
        ~ "    ?lexeme ontolex:sense ?sense .\n"
        ~ "    OPTIONAL { ?sense wdt:P5137 ?concept . }\n"
        ~ "  }\n"
        ~ "}\n";

    return query;
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

