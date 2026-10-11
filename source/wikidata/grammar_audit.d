/**
 * M5.8: Audit Wikidata grammatical feature combinations for matched lexemes.
 *
 * A catalogue is an independent selection; this module does not change
 * catalogue entries, matches, or Wikidata. Only returned Forms are counted.
 * Missing feature statements and missing Forms remain visible, not inferred.
 */
module wikidata.grammar_audit;

import std.algorithm.searching : canFind, startsWith;
import std.algorithm.sorting : sort;
import std.exception : enforce;
import std.json : JSONValue, JSONType, parseJSON;
import wikidata.query : isEntityId;
import wikidata.form_lookup : isFormId;

struct AuditLexeme
{
    string id;
    string lexicalCategoryId;
}

struct AuditForm
{
    string lexemeId;
    string formId;
    string[] featureIds;
}

/**
 * Extract unique lexemes from a completed M5.5 category coverage report.
 * Multiple catalogue entries referencing one lexeme must not inflate counts.
 */
AuditLexeme[] auditLexemes(JSONValue coverage)
{
    enforce(coverage.type == JSONType.object, "Coverage must be an object");
    auto rows = "entries" in coverage.object;
    enforce(rows !is null && (*rows).type == JSONType.array,
        "Coverage report has no entries");
    AuditLexeme[] lexemes;
    foreach (row; (*rows).array)
    {
        enforce(row.type == JSONType.object, "Invalid coverage entry");
        auto candidates = "candidates" in row.object;
        enforce(candidates !is null && (*candidates).type == JSONType.array,
            "Coverage entry has no candidates array");
        foreach (candidate; (*candidates).array)
        {
            enforce(candidate.type == JSONType.object, "Invalid candidate");
            auto id = candidate["lexemeId"].str;
            auto category = candidate["lexicalCategoryId"].str;
            enforce(isEntityId(id) && id[0] == 'L',
                "Invalid candidate Lexeme ID");
            enforce(isEntityId(category) && category[0] == 'Q',
                "Invalid candidate category ID");
            bool seen;
            foreach (lexeme; lexemes)
                if (lexeme.id == id)
                {
                    enforce(lexeme.lexicalCategoryId == category,
                        "Conflicting category for Lexeme " ~ id);
                    seen = true;
                    break;
                }
            if (!seen)
                lexemes ~= AuditLexeme(id, category);
        }
    }
    // Sort for reproducible requests, checkpoint identities, and reports.
    sort!((a, b) => a.id < b.id)(lexemes);
    return lexemes;
}

/// Find ALL returned Forms, including those with no grammatical features.
string buildGrammarAuditQuery(const(AuditLexeme)[] lexemes)
{
    enforce(lexemes.length > 0 && lexemes.length <= 20,
        "Grammar audit batch size must be 1..20");
    string query =
        "PREFIX wd: <http://www.wikidata.org/entity/>\n"
        ~ "PREFIX ontolex: <http://www.w3.org/ns/lemon/ontolex#>\n"
        ~ "PREFIX wikibase: <http://wikiba.se/ontology#>\n"
        ~ "SELECT ?lexeme ?form ?feature WHERE {\n"
        ~ "  VALUES ?lexeme {\n";
    string[] seen;
    foreach (lexeme; lexemes)
    {
        enforce(isEntityId(lexeme.id) && lexeme.id[0] == 'L',
            "Invalid Lexeme ID");
        enforce(!seen.canFind(lexeme.id), "Duplicate Lexeme ID in batch");
        seen ~= lexeme.id;
        query ~= "    wd:" ~ lexeme.id ~ "\n";
    }
    query ~= "  }\n"
        ~ "  ?lexeme ontolex:lexicalForm ?form .\n"
        ~ "  OPTIONAL { ?form wikibase:grammaticalFeature ?feature . }\n"
        ~ "}\n";
    return query;
}

private string bindingId(JSONValue row, string key, bool optional = false)
{
    enforce(row.type == JSONType.object, "Invalid SPARQL binding row");
    auto term = key in row.object;
    if (term is null && optional)
        return "";
    enforce(term !is null && (*term).type == JSONType.object,
        "Missing binding: " ~ key);
    auto value = "value" in (*term).object;
    enforce(value !is null && (*value).type == JSONType.string,
        "Invalid binding: " ~ key);
    auto uri = (*value).str;
    enum http = "http://www.wikidata.org/entity/";
    enum https = "https://www.wikidata.org/entity/";
    if (uri.startsWith(http)) return uri[http.length .. $];
    if (uri.startsWith(https)) return uri[https.length .. $];
    throw new Exception("Unexpected entity URI: " ~ uri);
}

/**
 * Group feature triples by actual Form ID. An OPTIONAL feature may be absent.
 * Zero rows for a lexeme means "no Forms returned by this query", not proof
 * that the entity lacks Forms in the authoritative Wikibase API.
 */
AuditForm[] parseGrammarAuditResponse(JSONValue response,
    const(AuditLexeme)[] requested)
{
    enforce(response.type == JSONType.object, "Invalid response");
    auto results = "results" in response.object;
    enforce(results !is null && (*results).type == JSONType.object,
        "Missing results object");
    auto bindings = "bindings" in (*results).object;
    enforce(bindings !is null && (*bindings).type == JSONType.array,
        "Missing bindings array");
    AuditForm[] forms;
    size_t[string] indexByForm;
    foreach (row; (*bindings).array)
    {
        string lexemeId = bindingId(row, "lexeme");
        string formId = bindingId(row, "form");
        string feature = bindingId(row, "feature", true);
        bool known;
        foreach (lexeme; requested)
            if (lexeme.id == lexemeId) { known = true; break; }
        enforce(known, "Unexpected Lexeme ID: " ~ lexemeId);
        enforce(isFormId(formId) &&
            formId.startsWith(lexemeId ~ "-F"),
            "Form does not belong to queried Lexeme: " ~ formId);
        if (feature.length)
            enforce(isEntityId(feature) && feature[0] == 'Q',
                "Invalid grammatical feature Q-ID");
        size_t index;
        if (auto existing = formId in indexByForm)
        {
            index = *existing;
            enforce(forms[index].lexemeId == lexemeId,
                "Conflicting parent Lexeme for Form");
        }
        else
        {
            index = forms.length;
            forms ~= AuditForm(lexemeId, formId, null);
            indexByForm[formId] = index;
        }
        if (feature.length && !forms[index].featureIds.canFind(feature))
            forms[index].featureIds ~= feature;
    }
    foreach (ref form; forms)
        sort(form.featureIds);
    sort!((a, b) => a.formId < b.formId)(forms);
    return forms;
}

private struct FeaturePattern
{
    string[] featureIds;
    size_t formCount;
    string[] lexemeIds;
    string[] sampleFormIds;
}

private struct CategoryProfile
{
    string id;
    string[] lexemeIds;
    string[] lexemeIdsWithForms;
    size_t formsWithoutFeatures;
    size_t formCount;
    FeaturePattern[] patterns;
}

private JSONValue stringArrayJson(const(string)[] values)
{
    JSONValue output = JSONValue.emptyArray;
    foreach (value; values)
        output.array ~= JSONValue(value);
    return output;
}

private bool equalFeatures(const(string)[] a, const(string)[] b)
{
    if (a.length != b.length) return false;
    foreach (i, value; a)
        if (value != b[i]) return false;
    return true;
}

/**
 * Create a fully offline and reproducible audit over unique lexemes.
 * It retains individual Form IDs for later (versioned) grammar contracts.
 */
JSONValue buildGrammarAuditReport(JSONValue coverage,
    const(AuditLexeme)[] lexemes, const(AuditForm)[] forms)
{
    enforce(coverage.type == JSONType.object, "Invalid coverage report");
    CategoryProfile[] categories;
    foreach (lexeme; lexemes)
    {
        size_t categoryIndex = categories.length;
        foreach (i, category; categories)
            if (category.id == lexeme.lexicalCategoryId)
            {
                categoryIndex = i;
                break;
            }
        if (categoryIndex == categories.length)
        {
            CategoryProfile category;
            category.id = lexeme.lexicalCategoryId;
            categories ~= category;
        }
        enforce(!categories[categoryIndex].lexemeIds.canFind(lexeme.id),
            "Duplicate input Lexeme");
        categories[categoryIndex].lexemeIds ~= lexeme.id;
    }

    JSONValue formRows = JSONValue.emptyArray;
    bool[string] seenForms;
    size_t[string] categoryByLexeme;
    foreach (i, category; categories)
        foreach (lexemeId; category.lexemeIds)
            categoryByLexeme[lexemeId] = i;
    size_t noFeatureCount;
    foreach (form; forms)
    {
        enforce(isFormId(form.formId) &&
            form.formId.startsWith(form.lexemeId ~ "-F"),
            "Invalid Form parent relationship");
        enforce((form.formId in seenForms) is null,
            "Duplicate Form ID: " ~ form.formId);
        seenForms[form.formId] = true;
        auto ci = form.lexemeId in categoryByLexeme;
        enforce(ci !is null,
            "Form for unknown Lexeme: " ~ form.lexemeId);
        auto category = &categories[*ci];
        ++category.formCount;
        if (!category.lexemeIdsWithForms.canFind(form.lexemeId))
            category.lexemeIdsWithForms ~= form.lexemeId;
        string[] normalized;
        foreach (feature; form.featureIds)
        {
            enforce(isEntityId(feature) && feature[0] == 'Q',
                "Invalid feature Q-ID");
            if (!normalized.canFind(feature)) normalized ~= feature;
        }
        sort(normalized);
        if (normalized.length == 0)
        {
            ++category.formsWithoutFeatures;
            ++noFeatureCount;
        }
        size_t pi = category.patterns.length;
        foreach (i, pattern; category.patterns)
            if (equalFeatures(pattern.featureIds, normalized))
            {
                pi = i;
                break;
            }
        if (pi == category.patterns.length)
        {
            FeaturePattern pattern;
            pattern.featureIds = normalized;
            category.patterns ~= pattern;
        }
        ++category.patterns[pi].formCount;
        if (!category.patterns[pi].lexemeIds.canFind(form.lexemeId))
            category.patterns[pi].lexemeIds ~= form.lexemeId;
        if (category.patterns[pi].sampleFormIds.length < 3)
            category.patterns[pi].sampleFormIds ~= form.formId;

        JSONValue row = JSONValue.emptyObject;
        row["lexemeId"] = form.lexemeId;
        row["formId"] = form.formId;
        row["lexicalCategoryId"] = category.id;
        row["grammaticalFeatureIds"] = stringArrayJson(normalized);
        formRows.array ~= row;
    }

    JSONValue categoryRows = JSONValue.emptyArray;
    foreach (category; categories)
    {
        JSONValue item = JSONValue.emptyObject;
        item["lexicalCategoryId"] = category.id;
        item["lexemes"] = cast(long) category.lexemeIds.length;
        item["lexemesWithReturnedForms"] =
            cast(long) category.lexemeIdsWithForms.length;
        item["formsReturned"] = cast(long) category.formCount;
        item["formsWithoutFeatures"] =
            cast(long) category.formsWithoutFeatures;
        JSONValue patterns = JSONValue.emptyArray;
        foreach (pattern; category.patterns)
        {
            JSONValue p = JSONValue.emptyObject;
            p["featureIds"] = stringArrayJson(pattern.featureIds);
            p["formCount"] = cast(long) pattern.formCount;
            p["lexemeCount"] = cast(long) pattern.lexemeIds.length;
            p["sampleFormIds"] = stringArrayJson(pattern.sampleFormIds);
            patterns.array ~= p;
        }
        item["patterns"] = patterns;
        categoryRows.array ~= item;
    }

    size_t lexemesWithForms;
    foreach (category; categories)
        lexemesWithForms += category.lexemeIdsWithForms.length;

    JSONValue summary = JSONValue.emptyObject;
    summary["catalogEntries"] = coverage["summary"]["catalogEntries"].integer;
    summary["uniqueLexemes"] = cast(long) lexemes.length;
    summary["lexemesWithReturnedForms"] = cast(long) lexemesWithForms;
    summary["lexemesWithoutReturnedForms"] =
        cast(long) (lexemes.length - lexemesWithForms);
    summary["formsReturned"] = cast(long) forms.length;
    summary["formsWithoutFeatures"] = cast(long) noFeatureCount;
    summary["lexicalCategories"] = cast(long) categories.length;
    size_t patternCount;
    foreach (category; categories) patternCount += category.patterns.length;
    summary["categoryFeaturePatterns"] = cast(long) patternCount;

    JSONValue report = JSONValue.emptyObject;
    report["schemaVersion"] = 1;
    report["catalogId"] = coverage["catalogId"].str;
    report["languageCode"] = coverage["languageCode"].str;
    report["level"] = coverage["level"].str;
    report["sourceReport"] = "M5.5-category-coverage";
    report["summary"] = summary;
    report["lexicalCategories"] = categoryRows;
    report["forms"] = formRows;
    return report;
}

unittest
{
    import std.exception : assertThrown;
    enum sample = `{"catalogId":"demo","languageCode":"it","level":"A1",
      "summary":{"catalogEntries":4},"entries":[
        {"catalogEntryId":"1","candidates":[
          {"lexemeId":"L1","lexicalCategoryId":"Q1084"}]},
        {"catalogEntryId":"2","candidates":[
          {"lexemeId":"L1","lexicalCategoryId":"Q1084"}]},
        {"catalogEntryId":"3","candidates":[
          {"lexemeId":"L2","lexicalCategoryId":"Q24905"}]},
        {"catalogEntryId":"4","candidates":[]}
      ]}`;
    auto coverage = parseJSON(sample);
    auto lexemes = auditLexemes(coverage);
    assert(lexemes.length == 2);
    assert(lexemes[0].id == "L1");
    assert(buildGrammarAuditQuery(lexemes).canFind("ontolex:lexicalForm"));
    assert(buildGrammarAuditQuery(lexemes).canFind("OPTIONAL"));
    assertThrown!Exception(buildGrammarAuditQuery([]));

    auto response = parseJSON(`{"results":{"bindings":[
      {"lexeme":{"value":"http://www.wikidata.org/entity/L1"},
       "form":{"value":"http://www.wikidata.org/entity/L1-F2"},
       "feature":{"value":"http://www.wikidata.org/entity/Q146786"}},
      {"lexeme":{"value":"http://www.wikidata.org/entity/L1"},
       "form":{"value":"http://www.wikidata.org/entity/L1-F1"},
       "feature":{"value":"http://www.wikidata.org/entity/Q499327"}},
      {"lexeme":{"value":"http://www.wikidata.org/entity/L1"},
       "form":{"value":"http://www.wikidata.org/entity/L1-F1"},
       "feature":{"value":"http://www.wikidata.org/entity/Q110786"}},
      {"lexeme":{"value":"http://www.wikidata.org/entity/L1"},
       "form":{"value":"http://www.wikidata.org/entity/L1-F1"},
       "feature":{"value":"http://www.wikidata.org/entity/Q110786"}},
      {"lexeme":{"value":"http://www.wikidata.org/entity/L2"},
       "form":{"value":"http://www.wikidata.org/entity/L2-F1"}}
    ]}}`);
    auto forms = parseGrammarAuditResponse(response, lexemes);
    assert(forms.length == 3);
    assert(forms[0].formId == "L1-F1");
    assert(forms[0].featureIds == ["Q110786", "Q499327"]);
    assert(forms[2].featureIds.length == 0);
    auto report = buildGrammarAuditReport(coverage, lexemes, forms);
    assert(report["summary"]["catalogEntries"].integer == 4);
    assert(report["summary"]["uniqueLexemes"].integer == 2);
    assert(report["summary"]["formsReturned"].integer == 3);
    assert(report["summary"]["formsWithoutFeatures"].integer == 1);
    assert(report["lexicalCategories"].array.length == 2);
    assert(report["lexicalCategories"].array[0]["patterns"].array.length == 2);
    assert(report["forms"].array.length == 3);
    auto emptyAudit = buildGrammarAuditReport(coverage, lexemes, null);
    assert(emptyAudit["summary"]["lexemesWithoutReturnedForms"].integer == 2);
    assert(emptyAudit["summary"]["formsReturned"].integer == 0);
    assertThrown!Exception(parseGrammarAuditResponse(
        parseJSON(`{"results":{"bindings":[
          {"lexeme":{"value":"http://www.wikidata.org/entity/L999"},
           "form":{"value":"http://www.wikidata.org/entity/L999-F1"}}
        ]}}`), lexemes));
    assertThrown!Exception(buildGrammarAuditReport(coverage,
        lexemes, [AuditForm("L999", "L999-F1", null)]));
}
