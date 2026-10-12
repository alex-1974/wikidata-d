/**
 * R1.8: Offline, language-neutral Wikidata evidence and constraint evaluation.
 *
 * An attested statement is evidence that Wikidata recorded an assertion, NOT
 * proof that a full natural-language grammar rule is valid. No word forms are
 * generated, merged, or silently inferred. The input is the versioned R1.7
 * research snapshot; its original statement IDs and qualifiers are retained.
 */
module wikidata.grammar_evidence;

import std.exception : enforce;
import std.json : JSONType, JSONValue, parseJSON;

/// Result of evaluating a condition in an open-world data set.
enum EvidenceStatus : ubyte
{
    supported,
    contradicted,
    unknown
}

/// Small, language-independent vocabulary of R1.7 evidence predicates.
enum GrammarConstraintKind : ubyte
{
    statementExists,
    statementForbidden,
    formOrder,
    aggregateFeatureObserved,
    perFormFromAggregate,
    ruleNotAvailable
}

/** One original Wikidata statement, with its source scope and qualifiers. */
struct EvidenceStatement
{
    string caseId;
    string sourceId;
    string sourceLevel;
    string statementId;
    string propertyId;
    string rank;
    string snaktype;
    JSONValue value;
    JSONValue qualifiers;
    size_t referenceCount;
    string sourceDataset;
    JSONValue originalStatement;
    JSONValue sourceRecord;
}

/** A typed check; all Q/L/P identifiers here are original IDs. */
struct GrammarConstraint
{
    string id;
    string caseId;
    GrammarConstraintKind kind;
    string sourceId;
    string propertyId;
    JSONValue value;
    JSONValue requiredQualifiers;
    string rank; // empty = no rank restriction
    string beforeFormId;
    string afterFormId;
    string featureQId;
}

/// Provenance of one attested statement, not an invented reciprocal edge.
struct EvidenceProof
{
    string sourceId;
    string sourceLevel;
    string statementId;
    string propertyId;
    string rank;
    JSONValue qualifiers;
    size_t referenceCount;
    string sourceDataset;
}

/** Evaluation describes evidence availability, not grammar rule validity. */
struct ConstraintEvaluation
{
    string id;
    string caseId;
    GrammarConstraintKind kind;
    EvidenceStatus status;
    string evidenceScope;
    EvidenceProof[] proofs;
    string explanation;
    size_t forwardEdges;
    size_t reverseEdges;
    size_t observedForms;
}

private string requiredString(JSONValue obj, string key)
{
    enforce(obj.type == JSONType.object, "Expected JSON object");
    auto entries = obj.object;
    auto ptr = key in entries;
    enforce(ptr !is null && (*ptr).type == JSONType.string &&
        (*ptr).str.length > 0, "Required string: " ~ key);
    return (*ptr).str;
}

private string optionalString(JSONValue obj, string key)
{
    enforce(obj.type == JSONType.object, "Expected JSON object");
    auto entries = obj.object;
    auto ptr = key in entries;
    if (ptr is null) return "";
    enforce((*ptr).type == JSONType.string, "Invalid string: " ~ key);
    return (*ptr).str;
}

private JSONValue optionalObject(JSONValue obj, string key)
{
    auto entries = obj.object;
    auto ptr = key in entries;
    if (ptr is null) return JSONValue.emptyObject;
    enforce((*ptr).type == JSONType.object, "Invalid object: " ~ key);
    return *ptr;
}

private size_t optionalCount(JSONValue obj, string key)
{
    auto entries = obj.object;
    auto ptr = key in entries;
    if (ptr is null) return 0;
    enforce((*ptr).type == JSONType.integer && (*ptr).integer >= 0,
        "Invalid nonnegative count: " ~ key);
    return cast(size_t) (*ptr).integer;
}

private bool jsonEqual(JSONValue a, JSONValue b)
{
    if (a.type != b.type) return false;
    if (a.type == JSONType.object)
    {
        auto left = a.object;
        auto right = b.object;
        if (left.length != right.length) return false;
        foreach (key, value; left)
        {
            auto other = key in right;
            if (other is null || !jsonEqual(value, *other)) return false;
        }
        return true;
    }
    if (a.type == JSONType.array)
    {
        auto left = a.array;
        auto right = b.array;
        if (left.length != right.length) return false;
        foreach (i, value; left)
            if (!jsonEqual(value, right[i])) return false;
        return true;
    }
    if (a.type == JSONType.string) return a.str == b.str;
    return a.toString() == b.toString();
}

/** Every required qualifier snak must occur on the SAME original statement. */
private bool qualifiersMatch(JSONValue present, JSONValue required)
{
    enforce(present.type == JSONType.object && required.type == JSONType.object,
        "Qualifiers must be JSON objects");
    auto have = present.object;
    foreach (propertyId, expectedList; required.object)
    {
        auto actual = propertyId in have;
        if (actual is null || (*actual).type != JSONType.array ||
            expectedList.type != JSONType.array) return false;
        foreach (expected; expectedList.array)
        {
            bool matched;
            foreach (candidate; (*actual).array)
                if (jsonEqual(candidate, expected)) { matched = true; break; }
            if (!matched) return false;
        }
    }
    return true;
}

private GrammarConstraintKind parseKind(string name)
{
    switch (name)
    {
        case "statement_exists": return GrammarConstraintKind.statementExists;
        case "statement_forbidden": return GrammarConstraintKind.statementForbidden;
        case "form_order": return GrammarConstraintKind.formOrder;
        case "aggregate_feature_observed": return GrammarConstraintKind.aggregateFeatureObserved;
        case "per_form_from_aggregate": return GrammarConstraintKind.perFormFromAggregate;
        case "rule_not_available": return GrammarConstraintKind.ruleNotAvailable;
        default: enforce(false, "Unknown constraint kind: " ~ name);
    }
    assert(0);
}

private string kindName(GrammarConstraintKind kind)
{
    final switch (kind)
    {
        case GrammarConstraintKind.statementExists: return "statement_exists";
        case GrammarConstraintKind.statementForbidden: return "statement_forbidden";
        case GrammarConstraintKind.formOrder: return "form_order";
        case GrammarConstraintKind.aggregateFeatureObserved: return "aggregate_feature_observed";
        case GrammarConstraintKind.perFormFromAggregate: return "per_form_from_aggregate";
        case GrammarConstraintKind.ruleNotAvailable: return "rule_not_available";
    }
}

string statusName(EvidenceStatus status)
{
    final switch (status)
    {
        case EvidenceStatus.supported: return "supported";
        case EvidenceStatus.contradicted: return "contradicted";
        case EvidenceStatus.unknown: return "unknown";
    }
}

/// Validate and parse a predicate from the frozen R1.7 predicate schema.
GrammarConstraint parseGrammarConstraint(JSONValue data)
{
    GrammarConstraint p;
    p.id = requiredString(data, "id");
    p.caseId = requiredString(data, "case");
    p.kind = parseKind(requiredString(data, "kind"));
    p.requiredQualifiers = optionalObject(data, "qualifiers");
    p.rank = optionalString(data, "rank");
    if (p.kind == GrammarConstraintKind.statementExists ||
        p.kind == GrammarConstraintKind.statementForbidden)
    {
        p.sourceId = requiredString(data, "sourceId");
        p.propertyId = requiredString(data, "property");
        auto entries = data.object;
        auto value = "value" in entries;
        enforce(value !is null, "Missing statement value");
        p.value = *value;
    }
    else if (p.kind == GrammarConstraintKind.formOrder)
    {
        p.beforeFormId = requiredString(data, "beforeFormId");
        p.afterFormId = requiredString(data, "afterFormId");
    }
    else if (p.kind == GrammarConstraintKind.aggregateFeatureObserved ||
             p.kind == GrammarConstraintKind.perFormFromAggregate)
    {
        p.featureQId = requiredString(data, "featureQId");
    }
    return p;
}

private EvidenceStatement parseStatement(string caseId, JSONValue rec)
{
    EvidenceStatement s;
    s.caseId = caseId;
    s.sourceId = requiredString(rec, "sourceId");
    s.sourceLevel = optionalString(rec, "sourceLevel");
    s.statementId = requiredString(rec, "statementId");
    s.propertyId = requiredString(rec, "property");
    s.rank = requiredString(rec, "rank");
    s.snaktype = requiredString(rec, "snaktype");
    auto entries = rec.object;
    auto val = "value" in entries;
    enforce(val !is null, "Missing statement value");
    s.value = *val;
    s.qualifiers = optionalObject(rec, "qualifiers");
    s.referenceCount = optionalCount(rec, "referenceCount");
    s.sourceDataset = optionalString(rec, "sourceDataset");
    auto raw = "originalStatement" in entries;
    s.originalStatement = raw is null ? JSONValue.emptyObject : *raw;
    s.sourceRecord = rec;
    return s;
}

/**
 * Case-local index for original statements and aggregate counts.
 * A statement's original scope is never broadened to other Forms or Senses.
 */
struct EvidenceIndex
{
    private EvidenceStatement[][string] bySourceProperty;
    private size_t[string][string] aggregateByCase;
    private bool[string] cases;

    this(JSONValue snapshot)
    {
        enforce(requiredString(snapshot, "schemaVersion") ==
            "wikidata-r1.7-fixture-v1", "Unsupported evidence fixture");
        auto allCases = snapshot["cases"];
        enforce(allCases.type == JSONType.object, "Fixture cases must be an object");
        EvidenceStatement[string] seen;
        foreach (caseId, data; allCases.object)
        {
            cases[caseId] = true;
            auto features = data["aggregateFeatures"];
            enforce(features.type == JSONType.object,
                "Case aggregateFeatures must be an object");
            foreach (qid, count; features.object)
            {
                enforce(count.type == JSONType.integer && count.integer >= 0,
                    "Invalid aggregate feature count");
                aggregateByCase[caseId][qid] = cast(size_t) count.integer;
            }
            auto rawStatements = data["statements"];
            enforce(rawStatements.type == JSONType.array,
                "Case statements must be an array");
            foreach (raw; rawStatements.array)
            {
                auto s = parseStatement(caseId, raw);
                if (auto other = s.statementId in seen)
                    enforce(jsonEqual(other.sourceRecord, s.sourceRecord),
                        "Conflicting original statement ID: " ~ s.statementId);
                else
                    seen[s.statementId] = s;
                bySourceProperty[indexKey(caseId, s.sourceId, s.propertyId)] ~= s;
            }
        }
    }

    private static string indexKey(string c, string source, string propertyId)
    {
        // Identifiers are Wikidata IDs and configured case names; the
        // delimiter cannot occur in any of them.
        return c ~ "\x1f" ~ source ~ "\x1f" ~ propertyId;
    }

    bool containsCase(string caseId)
    {
        return (caseId in cases) !is null;
    }

    /// Matching cannot join qualifier snaks from different statements.
    EvidenceStatement[] matching(GrammarConstraint p)
    {
        enforce(containsCase(p.caseId), "Unrecognized case: " ~ p.caseId);
        EvidenceStatement[] found;
        auto entries = indexKey(p.caseId, p.sourceId, p.propertyId) in
            bySourceProperty;
        if (entries is null) return found;
        foreach (s; *entries)
        {
            if (p.rank.length > 0 && p.rank != s.rank) continue;
            if (s.snaktype != "value" || !jsonEqual(s.value, p.value)) continue;
            if (!qualifiersMatch(s.qualifiers, p.requiredQualifiers)) continue;
            found ~= s;
        }
        return found;
    }

    size_t aggregateCount(string caseId, string qid)
    {
        enforce(containsCase(caseId), "Unrecognized case: " ~ caseId);
        auto counts = caseId in aggregateByCase;
        if (counts is null) return 0;
        auto count = qid in *counts;
        return count is null ? 0 : *count;
    }
}

/**
 * Read the original directed Wikidata edges without adding inverse claims.
 * `P11952` A -> B and `P11953` B -> A independently attest A before B.
 */
struct FormRelationIndex
{
    private EvidenceIndex* evidence;

    this(ref EvidenceIndex index)
    {
        evidence = &index;
    }

    ConstraintEvaluation check(string caseId, string before, string after)
    {
        GrammarConstraint forward;
        forward.caseId = caseId;
        forward.kind = GrammarConstraintKind.statementExists;
        forward.sourceId = before;
        forward.propertyId = "P11952";
        forward.value = JSONValue(after);
        forward.requiredQualifiers = JSONValue.emptyObject;
        auto first = evidence.matching(forward);
        GrammarConstraint backward = forward;
        backward.sourceId = after;
        backward.propertyId = "P11953";
        backward.value = JSONValue(before);
        auto second = evidence.matching(backward);
        ConstraintEvaluation outcome;
        outcome.kind = GrammarConstraintKind.formOrder;
        outcome.caseId = caseId;
        outcome.evidenceScope = "form_pair";
        outcome.forwardEdges = first.length;
        outcome.reverseEdges = second.length;
        foreach (s; first) outcome.proofs ~= asProof(s);
        foreach (s; second) outcome.proofs ~= asProof(s);
        outcome.status = outcome.proofs.length > 0 ? EvidenceStatus.supported :
            EvidenceStatus.unknown;
        outcome.explanation = "Original P11952/P11953 order evidence only; " ~
            "no missing reciprocal claim or lexical Form is generated.";
        return outcome;
    }
}

private EvidenceProof asProof(EvidenceStatement s)
{
    EvidenceProof p;
    p.sourceId = s.sourceId;
    p.sourceLevel = s.sourceLevel;
    p.statementId = s.statementId;
    p.propertyId = s.propertyId;
    p.rank = s.rank;
    p.qualifiers = s.qualifiers;
    p.referenceCount = s.referenceCount;
    p.sourceDataset = s.sourceDataset;
    return p;
}

/// Evaluate evidence existence or explicit prohibitions, never morphology.
ConstraintEvaluation evaluateConstraint(ref EvidenceIndex index,
    GrammarConstraint p)
{
    enforce(index.containsCase(p.caseId), "Unrecognized case: " ~ p.caseId);
    ConstraintEvaluation result;
    result.id = p.id;
    result.caseId = p.caseId;
    result.kind = p.kind;
    result.status = EvidenceStatus.unknown;
    final switch (p.kind)
    {
        case GrammarConstraintKind.statementExists:
        case GrammarConstraintKind.statementForbidden:
        {
            result.evidenceScope = p.sourceId;
            foreach (s; index.matching(p)) result.proofs ~= asProof(s);
            if (result.proofs.length)
                result.status = p.kind == GrammarConstraintKind.statementExists ?
                    EvidenceStatus.supported : EvidenceStatus.contradicted;
            result.explanation = result.proofs.length ?
                "Original statement found, including required qualifiers on the same claim." :
                "Not observed in selected snapshot; absence is not falsity.";
            break;
        }
        case GrammarConstraintKind.formOrder:
        {
            auto relations = FormRelationIndex(index);
            result = relations.check(p.caseId, p.beforeFormId, p.afterFormId);
            result.id = p.id;
            break;
        }
        case GrammarConstraintKind.aggregateFeatureObserved:
        {
            result.evidenceScope = "case_aggregate";
            result.observedForms = index.aggregateCount(p.caseId, p.featureQId);
            if (result.observedForms > 0) result.status = EvidenceStatus.supported;
            result.explanation = "Aggregate feature count only; not evidence of an individual Form.";
            break;
        }
        case GrammarConstraintKind.perFormFromAggregate:
        {
            result.evidenceScope = "form";
            result.explanation = "An aggregate cannot certify a particular Form-ID.";
            break;
        }
        case GrammarConstraintKind.ruleNotAvailable:
        {
            result.evidenceScope = "construction";
            result.explanation = "No grammar production rule established by this evidence.";
            break;
        }
    }
    return result;
}

private JSONValue asJson(EvidenceProof p)
{
    JSONValue row = JSONValue.emptyObject;
    row["sourceId"] = p.sourceId;
    row["sourceLevel"] = p.sourceLevel;
    row["statementId"] = p.statementId;
    row["property"] = p.propertyId;
    row["rank"] = p.rank;
    row["qualifiers"] = p.qualifiers;
    row["referenceCount"] = cast(long) p.referenceCount;
    row["sourceDataset"] = p.sourceDataset;
    return row;
}

private JSONValue asJson(ConstraintEvaluation v)
{
    JSONValue row = JSONValue.emptyObject;
    row["id"] = v.id;
    row["case"] = v.caseId;
    row["kind"] = kindName(v.kind);
    row["status"] = statusName(v.status);
    row["scope"] = v.evidenceScope;
    row["proof"] = JSONValue.emptyArray;
    foreach (p; v.proofs) row["proof"].array ~= asJson(p);
    row["explanation"] = v.explanation;
    row["doesNotCreateLexicalData"] = true;
    if (v.kind == GrammarConstraintKind.formOrder)
    {
        JSONValue detail = JSONValue.emptyObject;
        detail["P11952"] = cast(long) v.forwardEdges;
        detail["P11953"] = cast(long) v.reverseEdges;
        row["directionsAttested"] = detail;
    }
    if (v.kind == GrammarConstraintKind.aggregateFeatureObserved)
        row["observedForms"] = cast(long) v.observedForms;
    return row;
}

/**
 * Run the original 15-predicate R1.7 fixture (or compatible research fixture).
 * An expectedStatus mismatch throws: this is an executable regression gate.
 */
JSONValue evaluateEvidenceFixture(JSONValue snapshot, JSONValue request)
{
    enforce(requiredString(request, "schemaVersion") ==
        "wikidata-r1.7-predicates-v1", "Unsupported predicate schema");
    auto predicates = request["predicates"];
    enforce(predicates.type == JSONType.array, "Expected predicates array");
    auto index = EvidenceIndex(snapshot);
    JSONValue report = JSONValue.emptyObject;
    report["schemaVersion"] = "wikidata-r1.8-evidence-core-v1";
    report["results"] = JSONValue.emptyArray;
    foreach (raw; predicates.array)
    {
        auto p = parseGrammarConstraint(raw);
        auto ev = evaluateConstraint(index, p);
        auto expected = optionalString(raw, "expectedStatus");
        enforce(expected.length == 0 || expected == statusName(ev.status),
            "Regression mismatch: " ~ p.id ~ ": expected " ~ expected ~
            ", got " ~ statusName(ev.status));
        report["results"].array ~= asJson(ev);
    }
    return report;
}

unittest
{
    // Entirely synthetic data. The full 15 original Wikidata regressions are
    // tested by examples/catalog_grammar_evidence.d against the R1.7 archive.
    auto snapshot = parseJSON(q{
      {"schemaVersion":"wikidata-r1.7-fixture-v1","cases":{"test":{
        "aggregateFeatures":{"Q10":2},"statements":[
          {"sourceId":"L1-S1","sourceLevel":"sense","property":"P9971",
           "statementId":"L1-S1$one","snaktype":"value","rank":"normal",
           "value":"Q1","referenceCount":0,"qualifiers":{
             "P3831":[{"snaktype":"value","value":"Q2"}],
             "P5713":[{"snaktype":"value","value":"Q3"}]}},
          {"sourceId":"L2-F2","sourceLevel":"form","property":"P11952",
           "statementId":"L2-F2$edge","snaktype":"value","rank":"normal",
           "value":"L3-F4","referenceCount":0,"qualifiers":{}}
        ]}}}
    });
    auto index = EvidenceIndex(snapshot);
    auto direct = parseGrammarConstraint(parseJSON(q{
      {"id":"q","case":"test","kind":"statement_exists",
       "sourceId":"L1-S1","property":"P9971","value":"Q1",
       "qualifiers":{"P3831":[{"snaktype":"value","value":"Q2"}],
                     "P5713":[{"snaktype":"value","value":"Q3"}]}}
    }));
    auto yes = evaluateConstraint(index, direct);
    assert(yes.status == EvidenceStatus.supported && yes.proofs.length == 1);
    assert(yes.proofs[0].statementId == "L1-S1$one");
    direct.requiredQualifiers = parseJSON(q{
      {"P5713":[{"snaktype":"value","value":"Q999"}]}
    });
    assert(evaluateConstraint(index, direct).status == EvidenceStatus.unknown);
    direct.requiredQualifiers = JSONValue.emptyObject;
    direct.kind = GrammarConstraintKind.statementForbidden;
    assert(evaluateConstraint(index, direct).status == EvidenceStatus.contradicted);
    GrammarConstraint ordering;
    ordering.caseId = "test";
    ordering.kind = GrammarConstraintKind.formOrder;
    ordering.beforeFormId = "L2-F2";
    ordering.afterFormId = "L3-F4";
    auto forward = evaluateConstraint(index, ordering);
    assert(forward.status == EvidenceStatus.supported &&
        forward.forwardEdges == 1 && forward.reverseEdges == 0);
    ordering.beforeFormId = "L3-F4";
    ordering.afterFormId = "L2-F2";
    assert(evaluateConstraint(index, ordering).status == EvidenceStatus.unknown);
    GrammarConstraint agg;
    agg.caseId = "test";
    agg.kind = GrammarConstraintKind.aggregateFeatureObserved;
    agg.featureQId = "Q10";
    assert(evaluateConstraint(index, agg).observedForms == 2);
    agg.kind = GrammarConstraintKind.perFormFromAggregate;
    assert(evaluateConstraint(index, agg).status == EvidenceStatus.unknown);
}
