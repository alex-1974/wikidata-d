/**
 * R1.9: A typed, language-neutral expression layer over attested evidence.
 *
 * Strong-Kleene ALL/ANY combines the status of individual Wikidata evidence
 * checks. It does not certify a natural-language grammatical construction.
 * There is intentionally no logical NOT: in an open-world dataset, an absent
 * statement cannot be negated into a confirmed grammar fact.
 */
module wikidata.grammar_expression;

import std.exception : enforce;
import std.json : JSONType, JSONValue, parseJSON;
import wikidata.grammar_evidence :
    EvidenceIndex, EvidenceStatus, GrammarConstraint, GrammarConstraintKind,
    ConstraintEvaluation, evaluateConstraint, parseGrammarConstraint, statusName;

/// Operator vocabulary for an intermediate representation, not a parser DSL.
enum GrammarExpressionKind : ubyte
{
    predicate,
    allOf,
    anyOf
}

/** Immutable-by-convention parsed expression tree, bounded at parse time. */
struct GrammarExpression
{
    GrammarExpressionKind kind;
    string predicateId; // only for predicate
    GrammarExpression[] children; // only for allOf / anyOf
}

/** One original evidence check, with its own proof and scope. */
struct ExpressionLeaf
{
    string predicateId;
    ConstraintEvaluation evidence;
}

/** Combined evidence status, NOT a claim that a sentence is grammatical. */
struct ExpressionEvaluation
{
    string id;
    string caseId;
    EvidenceStatus status;
    ExpressionLeaf[] leaves;
}

private string requiredString(JSONValue obj, string key)
{
    enforce(obj.type == JSONType.object, "Expected expression object");
    auto entries = obj.object;
    auto val = key in entries;
    enforce(val !is null && (*val).type == JSONType.string &&
        (*val).str.length > 0, "Expected non-empty string: " ~ key);
    return (*val).str;
}

private string optionalString(JSONValue obj, string key)
{
    enforce(obj.type == JSONType.object, "Expected expression object");
    auto entries = obj.object;
    auto val = key in entries;
    if (val is null) return "";
    enforce((*val).type == JSONType.string, "Expected string: " ~ key);
    return (*val).str;
}

private JSONValue requiredMember(JSONValue obj, string key)
{
    enforce(obj.type == JSONType.object, "Expected expression object");
    auto entries = obj.object;
    auto val = key in entries;
    enforce(val !is null, "Missing expression member: " ~ key);
    return *val;
}

/**
 * Reject unbounded nesting, empty ALL/ANY, and unknown operations.
 * The limits protect the offline interpreter from hostile configuration files.
 */
private GrammarExpression parseNode(JSONValue input, size_t depth,
    ref size_t nodeCount)
{
    enforce(depth <= 32, "Grammar expression nesting exceeds 32 levels");
    enforce(++nodeCount <= 256, "Grammar expression exceeds 256 nodes");
    auto op = requiredString(input, "op");
    foreach (key, unused; input.object)
    {
        bool allowed = key == "op" ||
            (op == "predicate" ? key == "id" : key == "args");
        enforce(allowed, "Unexpected expression member: " ~ key);
    }
    GrammarExpression tree;
    if (op == "predicate")
    {
        tree.kind = GrammarExpressionKind.predicate;
        tree.predicateId = requiredString(input, "id");
        auto entries = input.object;
        enforce(("args" in entries) is null, "Predicate cannot have args");
    }
    else if (op == "all" || op == "any")
    {
        tree.kind = op == "all" ? GrammarExpressionKind.allOf :
            GrammarExpressionKind.anyOf;
        auto children = requiredMember(input, "args");
        enforce(children.type == JSONType.array &&
            children.array.length > 0, "ALL/ANY requires nonempty args");
        foreach (child; children.array)
            tree.children ~= parseNode(child, depth + 1, nodeCount);
    }
    else
        enforce(false, "Unsupported grammar expression operation: " ~ op);
    return tree;
}

/// Parse a single declarative expression into a typed D tree.
GrammarExpression parseGrammarExpression(JSONValue input)
{
    size_t count;
    return parseNode(input, 0, count);
}

/** Resolve leaves strictly within the rule's specified research case. */
private EvidenceStatus evaluateNode(ref EvidenceIndex index,
    const(GrammarExpression) node, string caseId,
    ref GrammarConstraint[string] predicates, ref ExpressionLeaf[] leaves)
{
    final switch (node.kind)
    {
        case GrammarExpressionKind.predicate:
        {
            auto ptr = node.predicateId in predicates;
            enforce(ptr !is null, "Unknown predicate ID: " ~ node.predicateId);
            enforce((*ptr).caseId == caseId,
                "Cross-case predicate in rule: " ~ node.predicateId);
            auto evaluated = evaluateConstraint(index, *ptr);
            ExpressionLeaf leaf;
            leaf.predicateId = node.predicateId;
            leaf.evidence = evaluated;
            leaves ~= leaf;
            return evaluated.status;
        }
        case GrammarExpressionKind.allOf:
        {
            // Strong Kleene: contradicted dominates unknown; all must support.
            auto result = EvidenceStatus.supported;
            foreach (ref child; node.children)
            {
                auto status = evaluateNode(index, child, caseId,
                    predicates, leaves);
                if (status == EvidenceStatus.contradicted)
                    result = EvidenceStatus.contradicted;
                else if (status == EvidenceStatus.unknown &&
                         result == EvidenceStatus.supported)
                    result = EvidenceStatus.unknown;
            }
            return result;
        }
        case GrammarExpressionKind.anyOf:
        {
            // Strong Kleene: supported dominates unknown; all must contradict
            // for an OR to be contradicted. No closed-world negation occurs.
            auto result = EvidenceStatus.contradicted;
            foreach (ref child; node.children)
            {
                auto status = evaluateNode(index, child, caseId,
                    predicates, leaves);
                if (status == EvidenceStatus.supported)
                    result = EvidenceStatus.supported;
                else if (status == EvidenceStatus.unknown &&
                         result == EvidenceStatus.contradicted)
                    result = EvidenceStatus.unknown;
            }
            return result;
        }
    }
}

/// No cross-case inference, no lexical creation, no implicit grammar validity.
ExpressionEvaluation evaluateExpression(ref EvidenceIndex index,
    string id, string caseId, const(GrammarExpression) expression,
    ref GrammarConstraint[string] predicates)
{
    enforce(index.containsCase(caseId), "Unknown research case: " ~ caseId);
    ExpressionEvaluation result;
    result.id = id;
    result.caseId = caseId;
    result.status = evaluateNode(index, expression, caseId,
        predicates, result.leaves);
    return result;
}

private string leafKindName(GrammarConstraintKind kind)
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

private JSONValue leafJson(ExpressionLeaf leaf)
{
    JSONValue v = JSONValue.emptyObject;
    v["predicateId"] = leaf.predicateId;
    v["kind"] = leafKindName(leaf.evidence.kind);
    v["status"] = statusName(leaf.evidence.status);
    v["scope"] = leaf.evidence.evidenceScope;
    v["proofs"] = JSONValue.emptyArray;
    foreach (proof; leaf.evidence.proofs)
    {
        JSONValue item = JSONValue.emptyObject;
        item["sourceId"] = proof.sourceId;
        item["sourceLevel"] = proof.sourceLevel;
        item["statementId"] = proof.statementId;
        item["property"] = proof.propertyId;
        item["rank"] = proof.rank;
        item["qualifiers"] = proof.qualifiers;
        item["referenceCount"] = cast(long) proof.referenceCount;
        item["sourceDataset"] = proof.sourceDataset;
        v["proofs"].array ~= item;
    }
    v["forwardEdges"] = cast(long) leaf.evidence.forwardEdges;
    v["reverseEdges"] = cast(long) leaf.evidence.reverseEdges;
    v["observedForms"] = cast(long) leaf.evidence.observedForms;
    v["explanation"] = leaf.evidence.explanation;
    return v;
}

private JSONValue resultJson(ExpressionEvaluation result)
{
    JSONValue v = JSONValue.emptyObject;
    v["id"] = result.id;
    v["case"] = result.caseId;
    v["status"] = statusName(result.status);
    v["leafEvidence"] = JSONValue.emptyArray;
    foreach (leaf; result.leaves)
        v["leafEvidence"].array ~= leafJson(leaf);
    v["statementProvenanceIsLeafScoped"] = true;
    v["doesNotCreateLexicalData"] = true;
    v["certifiesGrammaticality"] = false;
    return v;
}

/**
 * Evaluate a versioned expression document using R1.7's frozen predicate
 * definitions and evidence fixture. Expected statuses are executable gates.
 */
JSONValue evaluateExpressionFixture(JSONValue snapshot,
    JSONValue predicateDefinitions, JSONValue specification)
{
    enforce(requiredString(predicateDefinitions, "schemaVersion") ==
        "wikidata-r1.7-predicates-v1", "Unsupported predicate schema");
    enforce(requiredString(specification, "schemaVersion") ==
        "wikidata-r1.9-expressions-v1", "Unsupported expression schema");
    auto declarations = requiredMember(predicateDefinitions, "predicates");
    auto rules = requiredMember(specification, "rules");
    enforce(declarations.type == JSONType.array && rules.type == JSONType.array,
        "Predicates and rules must be arrays");

    GrammarConstraint[string] predicateById;
    foreach (raw; declarations.array)
    {
        auto predicate = parseGrammarConstraint(raw);
        enforce((predicate.id in predicateById) is null,
            "Duplicate predicate ID: " ~ predicate.id);
        predicateById[predicate.id] = predicate;
    }

    auto index = EvidenceIndex(snapshot);
    JSONValue report = JSONValue.emptyObject;
    report["schemaVersion"] = "wikidata-r1.9-expression-evaluation-v1";
    report["results"] = JSONValue.emptyArray;
    bool[string] seenRules;
    foreach (raw; rules.array)
    {
        auto id = requiredString(raw, "id");
        auto caseId = requiredString(raw, "case");
        enforce((id in seenRules) is null, "Duplicate rule ID: " ~ id);
        seenRules[id] = true;
        auto tree = parseGrammarExpression(requiredMember(raw, "expr"));
        auto result = evaluateExpression(index, id, caseId, tree,
            predicateById);
        auto expected = optionalString(raw, "expectedStatus");
        enforce(expected.length == 0 || expected == statusName(result.status),
            "Expression regression mismatch: " ~ id ~ ": expected " ~
            expected ~ ", observed " ~ statusName(result.status));
        report["results"].array ~= resultJson(result);
    }
    return report;
}

unittest
{
    auto snapshot = parseJSON(q{
      {"schemaVersion":"wikidata-r1.7-fixture-v1","cases":{"t":{
        "aggregateFeatures":{},"statements":[
          {"sourceId":"L1-S1","sourceLevel":"sense","property":"P5713",
           "statementId":"L1-S1$a","snaktype":"value","rank":"normal",
           "value":"Q1","qualifiers":{},"referenceCount":0}
        ]}}}
    });
    auto preds = parseJSON(q{
      {"schemaVersion":"wikidata-r1.7-predicates-v1","predicates":[
        {"id":"yes","case":"t","kind":"statement_exists",
         "sourceId":"L1-S1","property":"P5713","value":"Q1"},
        {"id":"maybe","case":"t","kind":"statement_exists",
         "sourceId":"L1-S1","property":"P5713","value":"Q2"},
        {"id":"no","case":"t","kind":"statement_forbidden",
         "sourceId":"L1-S1","property":"P5713","value":"Q1"},
        {"id":"forbidden-absent","case":"t","kind":"statement_forbidden",
         "sourceId":"L1-S1","property":"P5713","value":"Q999"}
      ]}
    });
    auto spec = parseJSON(q{
      {"schemaVersion":"wikidata-r1.9-expressions-v1","rules":[
        {"id":"all-yes","case":"t","expectedStatus":"supported",
         "expr":{"op":"all","args":[{"op":"predicate","id":"yes"},
                                     {"op":"predicate","id":"yes"}]}},
        {"id":"all-unknown","case":"t","expectedStatus":"unknown",
         "expr":{"op":"all","args":[{"op":"predicate","id":"yes"},
                                     {"op":"predicate","id":"maybe"}]}},
        {"id":"all-contradicted","case":"t","expectedStatus":"contradicted",
         "expr":{"op":"all","args":[{"op":"predicate","id":"no"},
                                     {"op":"predicate","id":"maybe"}]}},
        {"id":"any-supported","case":"t","expectedStatus":"supported",
         "expr":{"op":"any","args":[{"op":"predicate","id":"yes"},
                                     {"op":"predicate","id":"maybe"}]}},
        {"id":"any-unknown","case":"t","expectedStatus":"unknown",
         "expr":{"op":"any","args":[{"op":"predicate","id":"no"},
                                     {"op":"predicate","id":"maybe"}]}},
        {"id":"any-contradicted","case":"t","expectedStatus":"contradicted",
         "expr":{"op":"any","args":[{"op":"predicate","id":"no"},
                                     {"op":"predicate","id":"no"}]}},
        {"id":"nested","case":"t","expectedStatus":"supported",
         "expr":{"op":"all","args":[{"op":"predicate","id":"yes"},
            {"op":"any","args":[{"op":"predicate","id":"maybe"},
                                  {"op":"predicate","id":"yes"}]}]}},
        {"id":"not-observed-forbidden-remains-unknown","case":"t",
         "expectedStatus":"unknown",
         "expr":{"op":"predicate","id":"forbidden-absent"}}
      ]}
    });
    auto report = evaluateExpressionFixture(snapshot, preds, spec);
    assert(report["results"].array.length == 8);
    assert(report["results"].array[1]["status"].str == "unknown");
    assert(report["results"].array[2]["status"].str == "contradicted");
    assert(report["results"].array[0]["leafEvidence"].array[0]
        ["proofs"].array[0]["statementId"].str == "L1-S1$a");
}

unittest
{
    import std.exception : assertThrown;
    // Reject operators that could silently turn lack of evidence into proof.
    assertThrown!Exception(parseGrammarExpression(parseJSON(
        q{{"op":"not","args":[{"op":"predicate","id":"x"}]}})));
    assertThrown!Exception(parseGrammarExpression(parseJSON(
        q{{"op":"all","args":[]}})));
    // Unknown/alien case must never be joined to another language's evidence.
    auto snapshot = parseJSON(q{
      {"schemaVersion":"wikidata-r1.7-fixture-v1","cases":{
        "a":{"aggregateFeatures":{},"statements":[]},
        "b":{"aggregateFeatures":{},"statements":[]}}}
    });
    auto predicates = parseJSON(q{
      {"schemaVersion":"wikidata-r1.7-predicates-v1","predicates":[
        {"id":"x","case":"a","kind":"rule_not_available"}]}
    });
    auto spec = parseJSON(q{
      {"schemaVersion":"wikidata-r1.9-expressions-v1","rules":[
        {"id":"bad","case":"b","expr":{"op":"predicate","id":"x"}}]}
    });
    assertThrown!Exception(evaluateExpressionFixture(snapshot,predicates,spec));
}
