/**
 * M5.10: Retrieve original, language-tagged Wikidata Form representations.
 *
 * The M5.8 grammatical feature audit is read-only input.  This module never
 * synthesizes a spelling or discards alternate writing systems. Differences
 * between the audit snapshot and a later SPARQL response remain visible.
 */
module wikidata.form_representations;

import std.algorithm.searching : canFind, startsWith;
import std.algorithm.sorting : sort;
import std.exception : enforce;
import std.json : JSONType, JSONValue, parseJSON;
import wikidata.grammar_audit : AuditLexeme;
import wikidata.form_lookup : isFormId;
import wikidata.query : isEntityId;

struct WrittenRepresentation
{
    string text;
    string languageCode; // Literal xml:lang, or empty if absent.
}

struct WrittenForm
{
    string lexemeId;
    string formId;
    WrittenRepresentation[] representations;
}

/// Read Forms by their parent Lexeme, retaining Forms with no representation.
string buildRepresentationQuery(const(AuditLexeme)[] lexemes)
{
    enforce(lexemes.length >= 1 && lexemes.length <= 20,
        "Representation query batch size must be 1..20");
    string query =
        "PREFIX wd: <http://www.wikidata.org/entity/>\n"
        ~ "PREFIX ontolex: <http://www.w3.org/ns/lemon/ontolex#>\n"
        ~ "SELECT ?lexeme ?form ?representation WHERE {\n"
        ~ "  VALUES ?lexeme {\n";
    string[] seen;
    foreach (lexeme; lexemes)
    {
        enforce(isEntityId(lexeme.id) && lexeme.id[0] == 'L',
            "Invalid Lexeme ID in representation batch");
        enforce(!seen.canFind(lexeme.id), "Duplicate Lexeme ID");
        seen ~= lexeme.id;
        query ~= "    wd:" ~ lexeme.id ~ "\n";
    }
    query ~= "  }\n"
        ~ "  ?lexeme ontolex:lexicalForm ?form .\n"
        ~ "  OPTIONAL { ?form ontolex:representation ?representation . }\n"
        ~ "}\n";
    return query;
}

private string entityBindingId(JSONValue row, string key)
{
    enforce(row.type == JSONType.object, "Invalid binding row");
    auto term = key in row.object;
    enforce(term !is null && (*term).type == JSONType.object,
        "Missing binding " ~ key);
    auto val = "value" in (*term).object;
    enforce(val !is null && (*val).type == JSONType.string,
        "Invalid binding " ~ key);
    auto uri = (*val).str;
    enum http = "http://www.wikidata.org/entity/";
    enum https = "https://www.wikidata.org/entity/";
    string id;
    if (uri.startsWith(http)) id = uri[http.length .. $];
    else if (uri.startsWith(https)) id = uri[https.length .. $];
    else enforce(false, "Unexpected Wikidata entity URI: " ~ uri);
    return id;
}

/// Parse rows, validating ownership and preserving all distinct written forms.
WrittenForm[] parseRepresentationResponse(JSONValue response,
    const(AuditLexeme)[] requested)
{
    enforce(response.type == JSONType.object, "Invalid SPARQL response");
    auto results = "results" in response.object;
    enforce(results !is null && (*results).type == JSONType.object,
        "Missing SPARQL results");
    auto bindings = "bindings" in (*results).object;
    enforce(bindings !is null && (*bindings).type == JSONType.array,
        "Missing SPARQL bindings");

    bool[string] allowed;
    foreach (lexeme; requested) allowed[lexeme.id] = true;
    size_t[string] byForm;
    WrittenForm[] forms;
    foreach (row; (*bindings).array)
    {
        auto lexemeId = entityBindingId(row, "lexeme");
        auto formId = entityBindingId(row, "form");
        enforce((lexemeId in allowed) !is null,
            "Unexpected Lexeme ID: " ~ lexemeId);
        enforce(isFormId(formId) && formId.startsWith(lexemeId ~ "-F"),
            "Invalid Form parent: " ~ formId);

        size_t index;
        if (auto previous = formId in byForm)
        {
            index = *previous;
            enforce(forms[index].lexemeId == lexemeId,
                "Conflicting parent for Form " ~ formId);
        }
        else
        {
            index = forms.length;
            forms ~= WrittenForm(lexemeId, formId, null);
            byForm[formId] = index;
        }

        auto literal = "representation" in row.object;
        if (literal is null) continue;
        enforce((*literal).type == JSONType.object,
            "Invalid representation binding");
        auto value = "value" in (*literal).object;
        enforce(value !is null && (*value).type == JSONType.string,
            "Missing representation string");
        auto tag = "xml:lang" in (*literal).object;
        string language;
        if (tag !is null)
        {
            enforce((*tag).type == JSONType.string,
                "Invalid language tag");
            language = (*tag).str;
        }
        WrittenRepresentation rep = WrittenRepresentation((*value).str,
            language);
        bool duplicate;
        foreach (r; forms[index].representations)
            if (r.text == rep.text && r.languageCode == rep.languageCode)
                duplicate = true;
        if (!duplicate) forms[index].representations ~= rep;
    }
    foreach (ref form; forms)
        sort!((a, b) => a.languageCode == b.languageCode ?
            a.text < b.text : a.languageCode < b.languageCode)(
                form.representations);
    sort!((a, b) => a.formId < b.formId)(forms);
    return forms;
}

/// Join a later representation lookup to the original M5.8 Form set by ID.
JSONValue buildRepresentationReport(JSONValue audit,
    const(WrittenForm)[] discovered)
{
    enforce(audit.type == JSONType.object, "Invalid M5.8 report");
    auto source = "forms" in audit.object;
    enforce(source !is null && (*source).type == JSONType.array,
        "M5.8 report has no Forms array");
    auto summary = "summary" in audit.object;
    enforce(summary !is null && (*summary).type == JSONType.object,
        "M5.8 report has no summary");
    enforce((*source).array.length ==
        cast(size_t) audit["summary"]["formsReturned"].integer,
        "M5.8 Form count inconsistent");

    size_t[string] byId;
    foreach (i, form; discovered)
    {
        enforce(isFormId(form.formId), "Invalid discovered Form ID");
        enforce((form.formId in byId) is null,
            "Duplicate discovered Form ID");
        byId[form.formId] = i;
    }
    bool[string] sourceIds;
    JSONValue rows = JSONValue.emptyArray;
    JSONValue missing = JSONValue.emptyArray;
    size_t withRepresentation;
    size_t multipleRepresentations;
    size_t missingLanguageTags;
    foreach (form; (*source).array)
    {
        auto formId = form["formId"].str;
        auto lexemeId = form["lexemeId"].str;
        enforce(isFormId(formId) &&
            formId.startsWith(lexemeId ~ "-F"),
            "Invalid M5.8 Form ID");
        enforce((formId in sourceIds) is null,
            "Duplicate M5.8 Form ID");
        sourceIds[formId] = true;
        JSONValue row = JSONValue.emptyObject;
        row["formId"] = formId;
        row["lexemeId"] = lexemeId;
        row["lexicalCategoryId"] = form["lexicalCategoryId"].str;
        row["grammaticalFeatureIds"] = form["grammaticalFeatureIds"];
        JSONValue representations = JSONValue.emptyArray;
        if (auto found = formId in byId)
        {
            enforce(discovered[*found].lexemeId == lexemeId,
                "Parent Lexeme changed for Form " ~ formId);
            foreach (rep; discovered[*found].representations)
            {
                JSONValue r = JSONValue.emptyObject;
                r["text"] = rep.text;
                r["languageCode"] = rep.languageCode;
                representations.array ~= r;
                if (!rep.languageCode.length) ++missingLanguageTags;
            }
        }
        else
            missing.array ~= JSONValue(formId);
        if (representations.array.length > 0) ++withRepresentation;
        if (representations.array.length > 1) ++multipleRepresentations;
        row["representations"] = representations;
        row["presentInLatestQuery"] = (formId in byId) !is null;
        rows.array ~= row;
    }

    JSONValue newForms = JSONValue.emptyArray;
    foreach (form; discovered)
        if ((form.formId in sourceIds) is null)
        {
            JSONValue item = JSONValue.emptyObject;
            item["formId"] = form.formId;
            item["lexemeId"] = form.lexemeId;
            newForms.array ~= item;
        }
    JSONValue stats = JSONValue.emptyObject;
    stats["catalogEntries"] = audit["summary"]["catalogEntries"];
    stats["uniqueLexemes"] = audit["summary"]["uniqueLexemes"];
    stats["auditForms"] = cast(long) (*source).array.length;
    stats["formsWithRepresentation"] = cast(long) withRepresentation;
    stats["formsWithoutRepresentation"] =
        cast(long) ((*source).array.length - withRepresentation);
    stats["formsWithMultipleRepresentations"] =
        cast(long) multipleRepresentations;
    stats["representationsWithoutLanguageTag"] =
        cast(long) missingLanguageTags;
    stats["missingFromLatestQuery"] = cast(long) missing.array.length;
    stats["newSinceAudit"] = cast(long) newForms.array.length;
    JSONValue report = JSONValue.emptyObject;
    report["schemaVersion"] = 1;
    report["catalogId"] = audit["catalogId"];
    report["languageCode"] = audit["languageCode"];
    report["level"] = audit["level"];
    report["sourceReport"] = "M5.8-grammar-audit";
    report["snapshotConsistency"] = "mixed-time";
    report["summary"] = stats;
    report["forms"] = rows;
    report["missingFormIds"] = missing;
    report["newFormsNotInAudit"] = newForms;
    return report;
}

unittest
{
    import std.exception : assertThrown;
    auto lexemes = [AuditLexeme("L1", "Q24905")];
    auto q = buildRepresentationQuery(lexemes);
    assert(q.canFind("ontolex:representation"));
    assertThrown!Exception(buildRepresentationQuery([]));
    auto response = parseJSON(`{"results":{"bindings":[
       {"lexeme":{"value":"http://www.wikidata.org/entity/L1"},
        "form":{"value":"http://www.wikidata.org/entity/L1-F1"},
        "representation":{"value":"vado","xml:lang":"it"}},
       {"lexeme":{"value":"http://www.wikidata.org/entity/L1"},
        "form":{"value":"http://www.wikidata.org/entity/L1-F1"},
        "representation":{"value":"vado","xml:lang":"it"}},
       {"lexeme":{"value":"http://www.wikidata.org/entity/L1"},
        "form":{"value":"http://www.wikidata.org/entity/L1-F1"},
        "representation":{"value":"𐌀","xml:lang":"it-x-test"}},
       {"lexeme":{"value":"http://www.wikidata.org/entity/L1"},
        "form":{"value":"http://www.wikidata.org/entity/L1-F2"}},
       {"lexeme":{"value":"http://www.wikidata.org/entity/L1"},
        "form":{"value":"http://www.wikidata.org/entity/L1-F4"},
        "representation":{"value":"new","xml:lang":"it"}}
    ]}}`);
    auto found = parseRepresentationResponse(response, lexemes);
    assert(found.length == 3);
    assert(found[0].representations.length == 2);
    assert(found[1].representations.length == 0);
    auto audit = parseJSON(`{"catalogId":"a1","languageCode":"it",
        "level":"A1","summary":{"catalogEntries":1,
        "uniqueLexemes":1,"formsReturned":3},"forms":[
       {"lexemeId":"L1","formId":"L1-F1",
        "lexicalCategoryId":"Q24905",
        "grammaticalFeatureIds":["Q110786"]},
       {"lexemeId":"L1","formId":"L1-F2",
        "lexicalCategoryId":"Q24905",
        "grammaticalFeatureIds":[]},
       {"lexemeId":"L1","formId":"L1-F3",
        "lexicalCategoryId":"Q24905",
        "grammaticalFeatureIds":[]}
    ]}`);
    auto report = buildRepresentationReport(audit, found);
    assert(report["summary"]["auditForms"].integer == 3);
    assert(report["summary"]["formsWithRepresentation"].integer == 1);
    assert(report["summary"]["missingFromLatestQuery"].integer == 1);
    assert(report["summary"]["newSinceAudit"].integer == 1);
    assert(report["summary"]["formsWithMultipleRepresentations"].integer == 1);
    assert(report["forms"].array[0]["representations"].array.length == 2);
    assert(report["forms"].array[1]["presentInLatestQuery"].type ==
        JSONType.true_);
    assert(report["forms"].array[2]["presentInLatestQuery"].type ==
        JSONType.false_);
    assertThrown!Exception(parseRepresentationResponse(
        parseJSON(`{"results":{"bindings":[
           {"lexeme":{"value":"http://www.wikidata.org/entity/L2"},
            "form":{"value":"http://www.wikidata.org/entity/L2-F1"}}
        ]}}`), lexemes));
}
