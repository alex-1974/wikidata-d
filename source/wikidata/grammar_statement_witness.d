/**
 * R1.11-D3-C research: statement-scoped, evidence-only lexical witnesses.
 *
 * Reads the original Lexeme JSON, not an R1.11-D3-A summary index.
 * No inferred Form/Sense join, grammar operator, synthetic Form, or Q meaning.
 * The input snapshot digest is a CALLER-VERIFIED reference, not cryptographic
 * authentication performed by this module.
 */
module wikidata.grammar_statement_witness;

import std.algorithm.searching : startsWith;
import std.json : JSONType, JSONValue;
import wikidata.lexeme : WikidataLexeme, parseLexeme;

enum StatementWitnessKind : ubyte
{
    partial,
    ambiguous,
    usageExamplePair,
    lexemeComponent,
    semanticArgument,
    unresolved
}

struct SourceSnapshotRef
{
    string lexemeId;
    ulong revision;
    string rawResponseSha256;
    string sourceUrl;
}

/// The unmodified statement contains qualifiers, references and all future fields.
struct OriginalStatementProof
{
    string ownerId; // Lexeme or Sense, never implicitly converted to another scope.
    string statementId; // Preserve original GUID case.
    string propertyId;
    string rank;
    string snakType;
    size_t referenceCount;
    JSONValue originalStatement;
}

/// One observation is emitted for EACH relevant original statement, even if
/// unresolved. An observation is not automatically a positive witness.
struct StatementObservation
{
    OriginalStatementProof source;
    StatementWitnessKind kind;
    string reason;
}

struct UsageExampleWitness
{
    SourceSnapshotRef snapshot;
    OriginalStatementProof source;
    string formId;
    string senseId;
    string text;
    string languageTag;
    @property bool permitsFormSelection() const { return false; }
    @property bool permitsGeneralFormSenseAssociation() const { return false; }
    @property bool permitsGrammarProduction() const { return false; }
}

struct ComponentWitness
{
    SourceSnapshotRef snapshot;
    OriginalStatementProof source;
    string componentLexemeId;
    string ordinal; // Only if a SINGLE literal P1545 occurs on this statement.
    // P5548 is kept only in source.originalStatement until the *target* Lexeme
    // and its exact Form have been independently verified.
    bool hasUnverifiedObjectFormQualifier;
    @property bool permitsFormSelection() const { return false; }
    @property bool permitsGrammarProduction() const { return false; }
}

struct SemanticArgumentWitness
{
    SourceSnapshotRef snapshot;
    OriginalStatementProof source;
    string senseId;
    string argumentQId; // Original P9971 value; Q meaning is not resolved.
    string roleQId; // SINGLE original P3831 role or empty.
    @property bool permitsGrammarProduction() const { return false; }
    @property bool permitsFormSelection() const { return false; }
}

struct StatementWitnessBatch
{
    bool validInput;
    SourceSnapshotRef snapshot;
    StatementObservation[] observations;
    UsageExampleWitness[] usageExamples;
    ComponentWitness[] components;
    SemanticArgumentWitness[] semanticArguments;
    string error;
    @property bool permitsFormSelection() const { return false; }
    @property bool permitsGrammarProduction() const { return false; }
    @property bool permitsGeneralFormSenseAssociation() const { return false; }
}

private JSONValue* member(ref JSONValue obj, string key)
{
    if (obj.type != JSONType.object) return null;
    return key in obj.object;
}

private string str(ref JSONValue obj, string key)
{
    auto v = member(obj, key);
    return v !is null && (*v).type == JSONType.string ? (*v).str : "";
}

private bool isId(string value, char prefix)
{
    if (value.length < 2 || value[0] != prefix || value[1] == '0')
        return false;
    foreach (c; value[1 .. $])
        if (c < '0' || c > '9') return false;
    return true;
}

private bool isOwnedSubId(string value, string lexemeId, char sub)
{
    string prefix = lexemeId ~ "-" ~ sub;
    if (!value.startsWith(prefix) || value.length <= prefix.length ||
        value[prefix.length] == '0') return false;
    foreach (c; value[prefix.length .. $])
        if (c < '0' || c > '9') return false;
    return true;
}

private bool isDigest(string value)
{
    if (value.length != 64) return false;
    foreach (c; value)
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')))
            return false;
    return true;
}

private bool hasMemberId(const(string)[] ids, string id)
{
    foreach (test; ids) if (test == id) return true;
    return false;
}

private bool uniqueIds(ref JSONValue original, string listKey,
    string lexemeId, char suffix, out string[] ids)
{
    auto records = member(original, listKey);
    if (records is null) return true; // Lexeme may omit empty arrays.
    if ((*records).type != JSONType.array) return false;
    foreach (row; (*records).array)
    {
        if (row.type != JSONType.object) return false;
        string id = str(row, "id");
        if (!isOwnedSubId(id, lexemeId, suffix) || hasMemberId(ids, id))
            return false;
        ids ~= id;
    }
    return true;
}

private bool isOriginalStatement(ref JSONValue statement,
    string owner, string propertyId)
{
    string sid = str(statement, "id");
    auto snak = member(statement, "mainsnak");
    return sid.startsWith(owner ~ "$") && sid.length > owner.length + 1 &&
        snak !is null && (*snak).type == JSONType.object &&
        str(*snak, "property") == propertyId;
}

private bool isPositive(ref JSONValue statement)
{
    string rank = str(statement, "rank");
    auto mainSnak = member(statement, "mainsnak");
    return (rank == "normal" || rank == "preferred") &&
        mainSnak !is null && str(*mainSnak, "snaktype") == "value";
}

/// Require an explicitly present Wikibase entity-id payload; plain strings,
/// somevalue, novalue, and monolingual text are NOT entity IDs.
private string entityValue(ref JSONValue snak)
{
    if (str(snak, "snaktype") != "value") return "";
    auto dv = member(snak, "datavalue");
    if (dv is null) return "";
    auto val = member(*dv, "value");
    if (val is null) return "";
    return str(*val, "id");
}

private string monolingualValue(ref JSONValue snak, out string language)
{
    language = "";
    if (str(snak, "snaktype") != "value") return "";
    auto dv = member(snak, "datavalue");
    if (dv is null) return "";
    auto val = member(*dv, "value");
    if (val is null) return "";
    language = str(*val, "language");
    return str(*val, "text");
}

private string literalValue(ref JSONValue snak)
{
    if (str(snak, "snaktype") != "value") return "";
    auto dv = member(snak, "datavalue");
    if (dv is null) return "";
    auto val = member(*dv, "value");
    return val !is null && (*val).type == JSONType.string ? (*val).str : "";
}

private JSONValue[] qualifierSnaks(ref JSONValue statement, string propertyId)
{
    auto qualifiers = member(statement, "qualifiers");
    if (qualifiers is null) return null;
    auto row = member(*qualifiers, propertyId);
    if (row is null || (*row).type != JSONType.array) return null;
    return (*row).array;
}

private OriginalStatementProof proof(ref JSONValue statement,
    string owner, string propertyId)
{
    OriginalStatementProof result;
    result.ownerId = owner;
    result.statementId = str(statement, "id");
    result.propertyId = propertyId;
    result.rank = str(statement, "rank");
    auto snak = member(statement, "mainsnak");
    if (snak !is null) result.snakType = str(*snak, "snaktype");
    auto references = member(statement, "references");
    if (references !is null && (*references).type == JSONType.array)
        result.referenceCount = (*references).array.length;
    result.originalStatement = statement;
    return result;
}

/** Bounded scope parser. Input JSON is the authoritative statement source.
 *  The caller must verify source bytes and hash BEFORE using this API.
 *  `sourceUrl` and SHA syntax alone are NOT source authentication.
 */
StatementWitnessBatch extractOriginalStatementWitnesses(
    WikidataLexeme supplied, SourceSnapshotRef snapshot)
{
    StatementWitnessBatch result;
    result.snapshot = snapshot;
    if (supplied.raw.type != JSONType.object ||
        !isId(snapshot.lexemeId, 'L') ||
        !isDigest(snapshot.rawResponseSha256) ||
        snapshot.revision == 0 || snapshot.sourceUrl.length == 0)
    {
        result.error = "Invalid input snapshot metadata";
        return result;
    }
    // Parsed fields are derived, and therefore never trusted over original JSON.
    WikidataLexeme original;
    try { original = parseLexeme(supplied.raw); }
    catch (Exception)
    {
        result.error = "Malformed original Lexeme JSON";
        return result;
    }
    if (supplied.id != original.id ||
        supplied.languageId != original.languageId ||
        supplied.lexicalCategoryId != original.lexicalCategoryId ||
        snapshot.lexemeId != original.id ||
        !isId(original.languageId, 'Q') ||
        !isId(original.lexicalCategoryId, 'Q'))
    {
        result.error = "Lexeme identity mismatch";
        return result;
    }
    auto revision = member(original.raw, "lastrevid");
    if (revision is null || (*revision).type != JSONType.integer ||
        (*revision).integer <= 0 ||
        cast(ulong)(*revision).integer != snapshot.revision)
    {
        result.error = "Snapshot revision not present or mismatched";
        return result;
    }
    string[] forms, senses;
    if (!uniqueIds(original.raw, "forms", original.id, 'F', forms) ||
        !uniqueIds(original.raw, "senses", original.id, 'S', senses) ||
        supplied.forms.length != forms.length ||
        supplied.senses.length != senses.length)
    {
        result.error = "Invalid original Form/Sense identities";
        return result;
    }
    foreach (i, f; original.forms)
        if (supplied.forms[i].id != f.id ||
            supplied.forms[i].grammaticalFeatures != f.grammaticalFeatures)
        {
            result.error = "Changed derived Form";
            return result;
        }
    foreach (i, s; original.senses)
        if (supplied.senses[i].id != s.id)
        {
            result.error = "Changed derived Sense";
            return result;
        }

    // Fail closed on duplicate statement IDs even if different owners.
    string[] allStatements;
    auto collect = (JSONValue holder, string ownerId) {
        auto groups = member(holder, "claims");
        if (groups is null) return true;
        if ((*groups).type != JSONType.object) return false;
        foreach (propertyId, sequence; (*groups).object)
        {
            if (sequence.type != JSONType.array) return false;
            foreach (statement; sequence.array)
            {
                if (!isOriginalStatement(statement, ownerId, propertyId))
                    return false;
                string sid = str(statement, "id");
                if (hasMemberId(allStatements, sid)) return false;
                allStatements ~= sid;
            }
        }
        return true;
    };
    if (!collect(original.raw, original.id))
    {
        result.error = "Malformed or duplicate Lexeme statement";
        return result;
    }
    auto senseRows = member(original.raw, "senses");
    if (senseRows !is null)
        foreach (senseRow; (*senseRows).array)
            if (!collect(senseRow, str(senseRow, "id")))
            {
                result.error = "Malformed or duplicate Sense statement";
                return result;
            }
    result.validInput = true;

    auto evaluate = (JSONValue holder, string ownerId) {
        auto groups = member(holder, "claims");
        if (groups is null) return;
        foreach (propertyId, sequence; (*groups).object)
        {
            if (propertyId != "P5831" && propertyId != "P5238" &&
                propertyId != "P9971") continue;
            foreach (statement; sequence.array)
            {
                auto p = proof(statement, ownerId, propertyId);
                StatementObservation observation;
                observation.source = p;
                observation.kind = StatementWitnessKind.unresolved;
                if (!isPositive(statement))
                {
                    observation.reason = "Deprecated or non-value statement";
                    result.observations ~= observation;
                    continue;
                }
                auto mainSnak = member(statement, "mainsnak");
                if (propertyId == "P5831")
                {
                    auto ff = qualifierSnaks(statement, "P5830");
                    auto ss = qualifierSnaks(statement, "P6072");
                    string lang;
                    string value = monolingualValue(*mainSnak, lang);
                    if (ff.length != 1 || ss.length != 1)
                    {
                        observation.kind = ff.length > 1 || ss.length > 1 ?
                            StatementWitnessKind.ambiguous : StatementWitnessKind.partial;
                        observation.reason = "Missing or multiple same-statement qualifiers";
                    }
                    else
                    {
                        string form = entityValue(ff[0]);
                        string sense = entityValue(ss[0]);
                        if (value.length && lang.length &&
                            hasMemberId(forms, form) && hasMemberId(senses, sense) &&
                            (ownerId == original.id || ownerId == sense))
                        {
                            UsageExampleWitness w;
                            w.snapshot = snapshot;
                            w.source = p;
                            w.formId = form;
                            w.senseId = sense;
                            w.text = value;
                            w.languageTag = lang;
                            result.usageExamples ~= w;
                            observation.kind = StatementWitnessKind.usageExamplePair;
                        }
                        else observation.reason = "Unverifiable exact original Form/Sense/text";
                    }
                }
                else if (propertyId == "P5238")
                {
                    string target = entityValue(*mainSnak);
                    if (ownerId == original.id && isId(target, 'L'))
                    {
                        auto ordinal = qualifierSnaks(statement, "P1545");
                        auto objectForm = qualifierSnaks(statement, "P5548");
                        if (ordinal.length > 1)
                        {
                            observation.kind = StatementWitnessKind.ambiguous;
                            observation.reason = "Multiple ordinal qualifiers";
                        }
                        else
                        {
                            ComponentWitness w;
                            w.snapshot = snapshot;
                            w.source = p;
                            w.componentLexemeId = target;
                            w.hasUnverifiedObjectFormQualifier = objectForm.length != 0;
                            if (ordinal.length == 1)
                            {
                                w.ordinal = literalValue(ordinal[0]);
                                if (w.ordinal.length == 0)
                                {
                                    observation.reason = "Invalid ordinal qualifier";
                                    result.observations ~= observation;
                                    continue;
                                }
                            }
                            result.components ~= w;
                            observation.kind = StatementWitnessKind.lexemeComponent;
                        }
                    }
                    else observation.reason = "Invalid component Lexeme target or scope";
                }
                else if (propertyId == "P9971")
                {
                    string argument = entityValue(*mainSnak);
                    auto roles = qualifierSnaks(statement, "P3831");
                    if (roles.length > 1)
                    {
                        observation.kind = StatementWitnessKind.ambiguous;
                        observation.reason = "Multiple role qualifiers";
                    }
                    else if (isOwnedSubId(ownerId, original.id, 'S') &&
                        hasMemberId(senses, ownerId) && isId(argument, 'Q'))
                    {
                        string role;
                        if (roles.length == 1) role = entityValue(roles[0]);
                        if (roles.length == 0 || isId(role, 'Q'))
                        {
                            SemanticArgumentWitness w;
                            w.snapshot = snapshot;
                            w.source = p;
                            w.senseId = ownerId;
                            w.argumentQId = argument;
                            w.roleQId = role;
                            result.semanticArguments ~= w;
                            observation.kind = StatementWitnessKind.semanticArgument;
                        }
                        else observation.reason = "Invalid role qualifier";
                    }
                    else observation.reason = "Argument scope or Q-ID invalid";
                }
                result.observations ~= observation;
            }
        }
    };
    evaluate(original.raw, original.id);
    if (senseRows !is null)
        foreach (senseRow; (*senseRows).array)
            evaluate(senseRow, str(senseRow, "id"));
    return result;
}

private enum testSha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
private SourceSnapshotRef testSnapshot(string id = "L7")
{
    return SourceSnapshotRef(id, 42, testSha,
        "https://www.wikidata.org/wiki/Special:EntityData/" ~ id ~ ".json");
}

unittest
{
    import std.json : parseJSON;
    // Original-shaped synthetic data, NOT a live Wikidata revision.
    auto lexical = parseLexeme(q{
      {"id":"L7","language":"Q1860","lexicalCategory":"Q1084",
       "lastrevid":42,
       "forms":[{"id":"L7-F4","grammaticalFeatures":[]},
                {"id":"L7-F5","grammaticalFeatures":[]}],
       "senses":[{"id":"L7-S1"},{"id":"L7-S2"}],
       "claims":{"P5831":[
         {"id":"L7$alpha","rank":"normal","mainsnak":{
           "property":"P5831","snaktype":"value","datavalue":{
             "value":{"text":"the cat sat","language":"en"}}},
          "qualifiers":{
            "P5830":[{"snaktype":"value","datavalue":{"value":{"id":"L7-F4"}}}],
            "P6072":[{"snaktype":"value","datavalue":{"value":{"id":"L7-S1"}}}]},
          "references":[{"hash":"original-reference-retained","snaks":{}}],
          "futureField":{"keep":true}},
         {"id":"L7$only-sense","rank":"normal","mainsnak":{
            "property":"P5831","snaktype":"value","datavalue":{
              "value":{"text":"cat","language":"en"}}},
           "qualifiers":{"P6072":[{"snaktype":"value",
                "datavalue":{"value":{"id":"L7-S2"}}}]}},
         {"id":"L7$only-form","rank":"normal","mainsnak":{
            "property":"P5831","snaktype":"value","datavalue":{
              "value":{"text":"cats","language":"en"}}},
           "qualifiers":{"P5830":[{"snaktype":"value",
                "datavalue":{"value":{"id":"L7-F5"}}}]}}
       ]}}
    });
    auto result = extractOriginalStatementWitnesses(lexical, testSnapshot());
    assert(result.validInput);
    assert(result.observations.length == 3);
    assert(result.usageExamples.length == 1);
    assert(result.usageExamples[0].formId == "L7-F4");
    assert(result.usageExamples[0].senseId == "L7-S1");
    assert(result.usageExamples[0].source.statementId == "L7$alpha");
    assert(result.usageExamples[0].source.referenceCount == 1);
    assert(result.usageExamples[0].source.originalStatement["futureField"]["keep"].boolean);
    assert(result.observations[1].kind == StatementWitnessKind.partial);
    assert(result.observations[2].kind == StatementWitnessKind.partial);
    assert(!result.permitsFormSelection && !result.permitsGrammarProduction);
    assert(!result.usageExamples[0].permitsGeneralFormSenseAssociation);

    // Source metadata must agree with the original entity revision.
    auto wrongRev = testSnapshot();
    wrongRev.revision = 43;
    assert(!extractOriginalStatementWitnesses(lexical, wrongRev).validInput);
    wrongRev = testSnapshot();
    wrongRev.rawResponseSha256 = "claim-not-a-verified-digest";
    assert(!extractOriginalStatementWitnesses(lexical, wrongRev).validInput);

    // A caller cannot forge derived Form identity while retaining original JSON.
    auto edited = lexical;
    edited.forms = lexical.forms.dup;
    edited.forms[0].id = "L7-F999";
    assert(!extractOriginalStatementWitnesses(edited, testSnapshot()).validInput);
}

unittest
{
    import std.json : parseJSON;
    auto lexical = parseLexeme(q{
      {"id":"L252527","language":"Q652","lexicalCategory":"Q1084",
       "lastrevid":42,"forms":[],"senses":[],
       "claims":{"P5238":[
        {"id":"L252527$component-a","rank":"normal","mainsnak":{
          "property":"P5238","snaktype":"value","datavalue":{"value":{"id":"L40399"}}}},
        {"id":"L252527$component-b","rank":"normal","mainsnak":{
          "property":"P5238","snaktype":"value","datavalue":{"value":{"id":"L7119"}}}},
        {"id":"L252527$component-c","rank":"normal","mainsnak":{
          "property":"P5238","snaktype":"value","datavalue":{"value":{"id":"L77"}}},
          "qualifiers":{
            "P1545":[{"snaktype":"value","datavalue":{"value":"2"}}],
            "P5548":[{"snaktype":"value","datavalue":{"value":{"id":"L77-F3"}}}]}}
       ]}}
    });
    auto result = extractOriginalStatementWitnesses(lexical, testSnapshot("L252527"));
    assert(result.validInput && result.components.length == 3);
    assert(result.components[0].componentLexemeId == "L40399");
    assert(result.components[0].ordinal.length == 0);
    assert(!result.components[0].hasUnverifiedObjectFormQualifier);
    assert(result.components[2].componentLexemeId == "L77");
    assert(result.components[2].ordinal == "2");
    assert(result.components[2].hasUnverifiedObjectFormQualifier);
    assert(result.components[2].source.originalStatement["qualifiers"]["P5548"].array.length == 1);
    assert(!result.components[2].permitsFormSelection);
}

unittest
{
    import std.json : parseJSON;
    auto lexeme = parseLexeme(q{
      {"id":"L1340","language":"Q1860","lexicalCategory":"Q24905",
       "lastrevid":42,"forms":[{"id":"L1340-F1"}],
       "claims":{"P5831":[
         {"id":"L1340$partial","rank":"normal","mainsnak":{
          "property":"P5831","snaktype":"value","datavalue":{
            "value":{"text":"used","language":"en"}}},
          "qualifiers":{"P5830":[{"snaktype":"value",
            "datavalue":{"value":{"id":"L1340-F1"}}}]}},
         {"id":"L1340$deprecated","rank":"deprecated","mainsnak":{
          "property":"P5831","snaktype":"value","datavalue":{
            "value":{"text":"old","language":"en"}}},
          "qualifiers":{"P5830":[{"snaktype":"value",
            "datavalue":{"value":{"id":"L1340-F1"}}}],
           "P6072":[{"snaktype":"value",
            "datavalue":{"value":{"id":"L1340-S1"}}}]}},
         {"id":"L1340$multi","rank":"normal","mainsnak":{
          "property":"P5831","snaktype":"value","datavalue":{
            "value":{"text":"two meanings","language":"en"}}},
          "qualifiers":{"P5830":[{"snaktype":"value",
            "datavalue":{"value":{"id":"L1340-F1"}}}],
           "P6072":[{"snaktype":"value","datavalue":{"value":{"id":"L1340-S1"}}},
                     {"snaktype":"value","datavalue":{"value":{"id":"L1340-S2"}}}]}}
       ]},
       "senses":[{"id":"L1340-S1","claims":{
        "P5831":[{"id":"L1340-S1$partial-sense","rank":"normal",
          "mainsnak":{"property":"P5831","snaktype":"value",
            "datavalue":{"value":{"text":"example","language":"en"}}},
          "qualifiers":{"P6072":[{"snaktype":"value",
            "datavalue":{"value":{"id":"L1340-S1"}}}]}}],
        "P9971":[{"id":"L1340-S1$ARG-CaSe","rank":"normal","mainsnak":{
          "property":"P9971","snaktype":"value","datavalue":{"value":{"id":"Q20984678"}}},
          "qualifiers":{"P3831":[{"snaktype":"value",
            "datavalue":{"value":{"id":"Q164573"}}}]},"references":[]}
        ]}},{"id":"L1340-S2"}]}
    });
    auto result = extractOriginalStatementWitnesses(lexeme, testSnapshot("L1340"));
    assert(result.validInput);
    assert(result.usageExamples.length == 0); // NO JOIN across statements.
    assert(result.semanticArguments.length == 1);
    assert(result.semanticArguments[0].senseId == "L1340-S1");
    assert(result.semanticArguments[0].argumentQId == "Q20984678");
    assert(result.semanticArguments[0].roleQId == "Q164573");
    assert(result.semanticArguments[0].source.statementId == "L1340-S1$ARG-CaSe");
    assert(result.semanticArguments[0].source.referenceCount == 0);
    size_t ambiguous;
    foreach (observation; result.observations)
        if (observation.kind == StatementWitnessKind.ambiguous) ++ambiguous;
    assert(ambiguous == 1);
}

unittest
{
    import std.json : parseJSON;
    auto badOwner = parseLexeme(q{
      {"id":"L9","language":"Q1860","lexicalCategory":"Q1084",
       "lastrevid":42,"forms":[],"senses":[],
       "claims":{"P5238":[{"id":"L10$foreign","rank":"normal",
         "mainsnak":{"property":"P5238","snaktype":"value",
           "datavalue":{"value":{"id":"L11"}}}}]}}
    });
    auto rejected = extractOriginalStatementWitnesses(badOwner, testSnapshot("L9"));
    assert(!rejected.validInput);
    auto missing = parseLexeme(q{
      {"id":"L9","language":"Q1860","lexicalCategory":"Q1084",
       "lastrevid":42,"forms":[],"senses":[],
       "claims":{"P5238":[{"id":"L9$none","rank":"normal",
         "mainsnak":{"property":"P5238","snaktype":"novalue"}}]}}
    });
    auto noVal = extractOriginalStatementWitnesses(missing, testSnapshot("L9"));
    assert(noVal.validInput && noVal.components.length == 0);
    assert(noVal.observations.length == 1);
    assert(noVal.observations[0].kind == StatementWitnessKind.unresolved);
}
