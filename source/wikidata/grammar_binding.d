/**
 * R1.10: Typed, case-scoped joins of existing Wikidata evidence witnesses.
 *
 * A supported join certifies the co-occurrence of *attested evidence*, not the
 * grammatical correctness of a phrase. No lexical entry or Form is created.
 * There is no negation-as-failure and no implicit cross-form join.
 */
module wikidata.grammar_binding;

import std.exception : enforce;
import std.json : JSONType, JSONValue, parseJSON;
import std.algorithm.searching : startsWith;
import std.string : indexOf;
import wikidata.grammar_evidence :
    EvidenceIndex, EvidenceProof, EvidenceStatus, GrammarConstraint,
    GrammarConstraintKind, statusName;

/// Identifier sorts, not linguistic features or automatically inferred types.
enum BindingType : ubyte
{
    lexeme, form, sense, feature, language, statement, role
}

BindingType parseBindingType(string label)
{
    switch (label)
    {
        case "lexeme": return BindingType.lexeme;
        case "form": return BindingType.form;
        case "sense": return BindingType.sense;
        case "feature": return BindingType.feature;
        case "language": return BindingType.language;
        case "statement": return BindingType.statement;
        case "role": return BindingType.role;
        default: enforce(false, "Unrecognized binding type: " ~ label);
    }
    assert(0);
}

string bindingTypeName(BindingType kind)
{
    final switch (kind)
    {
        case BindingType.lexeme: return "lexeme";
        case BindingType.form: return "form";
        case BindingType.sense: return "sense";
        case BindingType.feature: return "feature";
        case BindingType.language: return "language";
        case BindingType.statement: return "statement";
        case BindingType.role: return "role";
    }
}

/// One explicitly declared, typed variable name.
struct BindingVariable
{
    string name;
    BindingType kind;
}

/// One typed opaque Wikidata identifier (surface strings are not identifiers).
struct BindingValue
{
    BindingType kind;
    string id;
}

/// The value assigned to one declared variable.
struct EvidenceBinding
{
    string variable;
    BindingValue value;
}

/**
 * One particular evidence witness, scoped to a case, language and construction.
 * `synthetic` witnesses are only admitted when the rule explicitly authorizes
 * the *research-only* mode. Non-synthetic rows must carry original proofs.
 */
struct EvidenceCandidate
{
    string caseId;
    string languageId;
    string constructionId;
    EvidenceBinding[] bindings;
    EvidenceProof[] proofs;
    bool synthetic;
}

/// Alternatives for one necessary evidence atom, NOT a blanket grammar claim.
struct BoundAtom
{
    string id;
    EvidenceCandidate[] candidates;
}

/**
 * Explicit binding contract. Every atom must provide every variable in joinOn.
 * All candidate variables must appear in variables with the same declared type.
 */
struct BoundConstraint
{
    string id;
    string caseId;
    string languageId;
    string constructionId;
    BindingVariable[] variables;
    string[] joinOn;
    BoundAtom[] atoms;
    bool allowSynthetic; // ONLY for isolated fixture experiments
}

/// All distinct attested witness paths are retained; no inferred Forms.
struct BoundEvaluation
{
    string id;
    string caseId;
    EvidenceStatus status;
    EvidenceCandidate[] candidates;
    string explanation;
}

private string requiredString(JSONValue value, string key)
{
    enforce(value.type == JSONType.object, "Expected JSON object");
    auto entries = value.object;
    auto hit = key in entries;
    enforce(hit !is null && (*hit).type == JSONType.string &&
        (*hit).str.length != 0, "Required string: " ~ key);
    return (*hit).str;
}

private JSONValue requiredMember(JSONValue value, string key)
{
    enforce(value.type == JSONType.object, "Expected JSON object");
    auto entries = value.object;
    auto hit = key in entries;
    enforce(hit !is null, "Missing member: " ~ key);
    return *hit;
}

private string optionalString(JSONValue value, string key)
{
    enforce(value.type == JSONType.object, "Expected JSON object");
    auto entries = value.object;
    auto hit = key in entries;
    if (hit is null) return "";
    enforce((*hit).type == JSONType.string, "Invalid string: " ~ key);
    return (*hit).str;
}

private BindingType* declaredType(ref BoundConstraint rule, string name)
{
    foreach (ref variable; rule.variables)
        if (variable.name == name) return &variable.kind;
    return null;
}

private EvidenceBinding* boundValue(ref EvidenceCandidate candidate, string name)
{
    foreach (ref binding; candidate.bindings)
        if (binding.variable == name) return &binding;
    return null;
}

private bool sameValue(BindingValue a, BindingValue b)
{
    return a.kind == b.kind && a.id == b.id;
}

private void validateRule(ref BoundConstraint rule)
{
    enforce(rule.id.length && rule.caseId.length && rule.languageId.length &&
        rule.constructionId.length, "Missing explicit case/language/construction scope");
    enforce(rule.variables.length && rule.joinOn.length && rule.atoms.length,
        "Variables, join variables and atoms must be nonempty");
    enforce(rule.variables.length <= 64 && rule.joinOn.length <= 64 &&
        rule.atoms.length <= 64, "Binding specification exceeds limits");
    bool[string] vars;
    foreach (variable; rule.variables)
    {
        enforce(variable.name.length, "Empty variable name");
        enforce((variable.name in vars) is null,
            "Duplicate variable declaration: " ~ variable.name);
        vars[variable.name] = true;
    }
    bool[string] joins;
    foreach (name; rule.joinOn)
    {
        enforce((name in vars) !is null, "Undeclared join variable: " ~ name);
        enforce((name in joins) is null, "Duplicate join variable: " ~ name);
        joins[name] = true;
    }
    bool[string] atomIds;
    foreach (ref atom; rule.atoms)
    {
        enforce(atom.id.length && (atom.id in atomIds) is null,
            "Empty or repeated atom ID");
        atomIds[atom.id] = true;
        foreach (ref candidate; atom.candidates)
        {
            enforce(candidate.caseId == rule.caseId &&
                candidate.languageId == rule.languageId &&
                candidate.constructionId == rule.constructionId,
                "Candidate crosses research case, language or construction");
            enforce(candidate.synthetic == rule.allowSynthetic,
                "Cannot mix synthetic and attested evidence");
            enforce(candidate.synthetic || candidate.proofs.length > 0,
                "An attested candidate requires original statement proof");
            bool[string] bound;
            foreach (binding; candidate.bindings)
            {
                enforce(binding.variable.length && binding.value.id.length,
                    "Empty binding variable or identifier");
                enforce((binding.variable in bound) is null,
                    "Duplicate candidate variable: " ~ binding.variable);
                bound[binding.variable] = true;
                auto kind = declaredType(rule, binding.variable);
                enforce(kind !is null && *kind == binding.value.kind,
                    "Undeclared or mistyped variable: " ~ binding.variable);
            }
            foreach (name; rule.joinOn)
                enforce((name in bound) !is null,
                    "missing join variable: " ~ name);
        }
    }
}

/**
 * Natural join on explicit *typed* shared variables. Missing join keys are
 * rejected by validation; no unguarded Cartesian product is permitted.
 */
private bool mergeCandidate(ref EvidenceCandidate left,
    ref EvidenceCandidate right, out EvidenceCandidate result)
{
    if (left.caseId != right.caseId || left.languageId != right.languageId ||
        left.constructionId != right.constructionId ||
        left.synthetic != right.synthetic) return false;
    result = left;
    result.bindings = left.bindings.dup;
    result.proofs = left.proofs.dup;
    foreach (binding; right.bindings)
    {
        auto present = boundValue(result, binding.variable);
        if (present !is null)
        {
            if (!sameValue(present.value, binding.value)) return false;
        }
        else result.bindings ~= binding;
    }
    foreach (proof; right.proofs)
    {
        bool found;
        foreach (old; result.proofs)
            if (old.statementId == proof.statementId)
            {
                found = true;
                break;
            }
        if (!found) result.proofs ~= proof;
    }
    return true;
}

private bool sameWitness(ref EvidenceCandidate left, ref EvidenceCandidate right)
{
    if (left.caseId != right.caseId || left.languageId != right.languageId ||
        left.constructionId != right.constructionId ||
        left.bindings.length != right.bindings.length ||
        left.proofs.length != right.proofs.length) return false;
    foreach (binding; left.bindings)
    {
        auto found = boundValue(right, binding.variable);
        if (found is null || !sameValue(found.value, binding.value)) return false;
    }
    foreach (proof; left.proofs)
    {
        bool found;
        foreach (other; right.proofs)
            if (proof.statementId == other.statementId) { found = true; break; }
        if (!found) return false;
    }
    return true;
}

/// Strict open-world evaluation: no matching witnesses means unknown, not false.
BoundEvaluation evaluateBound(BoundConstraint rule)
{
    validateRule(rule);
    enum size_t maxCandidates = 8192;
    BoundEvaluation result;
    result.id = rule.id;
    result.caseId = rule.caseId;
    result.status = EvidenceStatus.unknown;
    auto first = rule.atoms[0];
    result.candidates = first.candidates.dup;
    // Deduplicate every atom, including the first one.
    foreach (size_t i; 0 .. rule.atoms.length)
    {
        EvidenceCandidate[] next;
        auto incoming = rule.atoms[i].candidates;
        if (i == 0)
        {
            foreach (ref witness; result.candidates)
            {
                bool exists;
                foreach (ref previous; next)
                    if (sameWitness(witness, previous)) { exists = true; break; }
                if (!exists)
                {
                    enforce(next.length < maxCandidates, "Too many bound witnesses");
                    next ~= witness;
                }
            }
        }
        else
        {
            foreach (ref left; result.candidates)
                foreach (ref right; incoming)
                {
                    EvidenceCandidate joined;
                    if (!mergeCandidate(left, right, joined)) continue;
                    bool exists;
                    foreach (ref previous; next)
                        if (sameWitness(joined, previous)) { exists = true; break; }
                    if (!exists)
                    {
                        enforce(next.length < maxCandidates, "Too many bound witnesses");
                        next ~= joined;
                    }
                }
        }
        result.candidates = next;
        if (result.candidates.length == 0) break;
    }
    if (result.candidates.length)
        result.status = EvidenceStatus.supported;
    result.explanation = result.candidates.length ?
        "Bound evidence witnesses observed; NOT a grammar production proof." :
        "No consistent witnesses in selected evidence; absence is unknown.";
    return result;
}

/**
 * Safely create one atom from actual R1.8 statement matches (including all
 * original qualifiers). Never accept aggregate observations as per-Form facts.
 * The caller supplies language scope from a separately verified lexeme record.
 */
BoundAtom scanAttestedSource(ref EvidenceIndex index, GrammarConstraint query,
    string atomId, string variable, BindingType sourceType,
    string languageId, string constructionId)
{
    enforce(query.kind == GrammarConstraintKind.statementExists,
        "Only original positive statements can create attested witnesses");
    enforce(sourceType == BindingType.lexeme || sourceType == BindingType.form ||
        sourceType == BindingType.sense, "Source must be Lexeme, Form or Sense");
    enforce(variable.length && atomId.length && languageId.length &&
        constructionId.length, "Missing binding scope");
    BoundAtom atom;
    atom.id = atomId;
    foreach (s; index.matching(query))
    {
        bool validSource;
        if (sourceType == BindingType.lexeme)
            validSource = s.sourceLevel == "lexeme" &&
                s.sourceId.startsWith("L") &&
                s.sourceId.indexOf('-') < 0;
        else if (sourceType == BindingType.form)
            validSource = s.sourceLevel == "form" &&
                s.sourceId.startsWith("L") &&
                s.sourceId.indexOf("-F") > 0;
        else
            validSource = s.sourceLevel == "sense" &&
                s.sourceId.startsWith("L") &&
                s.sourceId.indexOf("-S") > 0;
        enforce(validSource, "Source identifier/type mismatch: " ~ s.sourceId);
        EvidenceCandidate candidate;
        candidate.caseId = query.caseId;
        candidate.languageId = languageId;
        candidate.constructionId = constructionId;
        candidate.bindings ~= EvidenceBinding(variable,
            BindingValue(sourceType, s.sourceId));
        EvidenceProof proof;
        proof.sourceId = s.sourceId;
        proof.sourceLevel = s.sourceLevel;
        proof.statementId = s.statementId;
        proof.propertyId = s.propertyId;
        proof.rank = s.rank;
        proof.qualifiers = s.qualifiers;
        proof.referenceCount = s.referenceCount;
        proof.sourceDataset = s.sourceDataset;
        candidate.proofs ~= proof;
        atom.candidates ~= candidate;
    }
    return atom;
}

/** Versioned research-only synthetic fixtures; not production grammar input. */
JSONValue evaluateSyntheticBindingFixture(JSONValue fixture)
{
    enforce(requiredString(fixture, "schemaVersion") ==
        "wikidata-r1.10-typed-binding-research-v1", "Wrong binding fixture schema");
    auto cases = requiredMember(fixture, "cases");
    enforce(cases.type == JSONType.array, "cases must be an array");
    JSONValue report = JSONValue.emptyObject;
    report["schemaVersion"] = "wikidata-r1.10-binding-evaluation-v1";
    report["syntheticOnly"] = true;
    report["results"] = JSONValue.emptyArray;
    bool[string] seen;
    foreach (raw; cases.array)
    {
        auto id = requiredString(raw, "id");
        enforce((id in seen) is null, "Duplicate test case");
        seen[id] = true;
        BoundConstraint rule;
        rule.id = id;
        rule.caseId = id;
        rule.languageId = "synthetic:language";
        rule.constructionId = "synthetic:construction";
        rule.allowSynthetic = true;
        auto declarations = requiredMember(raw, "variableTypes");
        enforce(declarations.type == JSONType.object, "variableTypes must be object");
        foreach (name, type; declarations.object)
        {
            enforce(type.type == JSONType.string, "Variable type must be string");
            rule.variables ~= BindingVariable(name, parseBindingType(type.str));
        }
        auto joins = requiredMember(raw, "joinOn");
        enforce(joins.type == JSONType.array, "joinOn must be array");
        foreach (name; joins.array)
        {
            enforce(name.type == JSONType.string, "Join variables must be strings");
            rule.joinOn ~= name.str;
        }
        auto atoms = requiredMember(raw, "atoms");
        enforce(atoms.type == JSONType.array, "atoms must be array");
        foreach (entry; atoms.array)
        {
            BoundAtom atom;
            atom.id = requiredString(entry, "id");
            auto rows = requiredMember(entry, "bindings");
            enforce(rows.type == JSONType.array, "bindings must be array");
            foreach (row; rows.array)
            {
                enforce(row.type == JSONType.object, "Binding row must be object");
                EvidenceCandidate candidate;
                candidate.caseId = rule.caseId;
                candidate.languageId = rule.languageId;
                candidate.constructionId = rule.constructionId;
                candidate.synthetic = true;
                foreach (name, token; row.object)
                {
                    enforce(token.type == JSONType.string && token.str.length,
                        "Binding identifier must be string");
                    auto kind = declaredType(rule, name);
                    enforce(kind !is null, "Undeclared binding variable: " ~ name);
                    candidate.bindings ~= EvidenceBinding(name,
                        BindingValue(*kind, token.str));
                }
                atom.candidates ~= candidate;
            }
            rule.atoms ~= atom;
        }
        auto expectedError = optionalString(raw, "expectedError");
        JSONValue row = JSONValue.emptyObject;
        row["id"] = id;
        if (expectedError.length)
        {
            import std.exception : collectException;
            auto error = collectException!Exception(evaluateBound(rule));
            enforce(error !is null && error.msg.indexOf(expectedError) >= 0,
                "Expected binding error not observed: " ~ id);
            row["status"] = "expected-error";
            row["matches"] = 0;
        }
        else
        {
            auto evaluated = evaluateBound(rule);
            enforce(statusName(evaluated.status) ==
                requiredString(raw, "expectedStatus"),
                "Unexpected bound status: " ~ id);
            auto matches = requiredMember(raw, "expectedMatches");
            enforce(matches.type == JSONType.integer && matches.integer >= 0 &&
                cast(size_t) matches.integer == evaluated.candidates.length,
                "Unexpected witness count: " ~ id);
            row["status"] = statusName(evaluated.status);
            row["matches"] = cast(long) evaluated.candidates.length;
            row["witnesses"] = JSONValue.emptyArray;
            foreach (ref witness; evaluated.candidates)
            {
                JSONValue w = JSONValue.emptyObject;
                w["bindings"] = JSONValue.emptyObject;
                foreach (binding; witness.bindings)
                {
                    JSONValue b = JSONValue.emptyObject;
                    b["type"] = bindingTypeName(binding.value.kind);
                    b["id"] = binding.value.id;
                    w["bindings"][binding.variable] = b;
                }
                w["attestedStatementIds"] = JSONValue.emptyArray;
                foreach (proof; witness.proofs)
                    w["attestedStatementIds"].array ~= JSONValue(proof.statementId);
                row["witnesses"].array ~= w;
            }
        }
        report["results"].array ~= row;
    }
    return report;
}

unittest
{
    // Synthetic typed fixtures exercise the join core without lexicon data.
    auto spec = parseJSON(q{
      {"schemaVersion":"wikidata-r1.10-typed-binding-research-v1","cases":[
        {"id":"a","variableTypes":{"form":"form"},"joinOn":["form"],
         "atoms":[{"id":"x","bindings":[{"form":"synthetic:F2"},{"form":"synthetic:F3"}]},
                  {"id":"y","bindings":[{"form":"synthetic:F2"},{"form":"synthetic:F3"}]}],
         "expectedStatus":"supported","expectedMatches":2},
        {"id":"b","variableTypes":{"form":"form"},"joinOn":["form"],
         "atoms":[{"id":"x","bindings":[{"form":"synthetic:F1"}]},
                  {"id":"y","bindings":[{"form":"synthetic:F2"}]}],
         "expectedStatus":"unknown","expectedMatches":0}
      ]}
    });
    auto report = evaluateSyntheticBindingFixture(spec);
    assert(report["results"].array.length == 2);
    assert(report["results"].array[0]["matches"].integer == 2);
    assert(report["results"].array[1]["status"].str == "unknown");
}

unittest
{
    import std.exception : assertThrown;
    BoundConstraint rule;
    rule.id = "b";
    rule.caseId = "test";
    rule.languageId = "Q652";
    rule.constructionId = "c";
    rule.variables ~= BindingVariable("form", BindingType.form);
    rule.joinOn ~= "form";
    BoundAtom a;
    a.id = "x";
    EvidenceCandidate witness;
    witness.caseId = "test";
    witness.languageId = "Q652";
    witness.constructionId = "c";
    witness.synthetic = true;
    witness.bindings ~= EvidenceBinding("form", BindingValue(BindingType.form, "synthetic:F1"));
    a.candidates ~= witness;
    rule.atoms ~= a;
    // Attested mode MUST reject a synthetic witness.
    assertThrown!Exception(evaluateBound(rule));
    rule.allowSynthetic = true;
    assert(evaluateBound(rule).status == EvidenceStatus.supported);
    // No accidental unification across language, even if IDs match.
    rule.atoms[0].candidates[0].languageId = "Q7838";
    assertThrown!Exception(evaluateBound(rule));
    rule.atoms[0].candidates[0].languageId = "Q652";
    rule.atoms[0].candidates[0].bindings[0].value.kind = BindingType.sense;
    assertThrown!Exception(evaluateBound(rule));
}

unittest
{
    // EvidenceIndex adapter must preserve *original* statement IDs/qualifiers.
    auto snapshot = parseJSON(q{
      {"schemaVersion":"wikidata-r1.7-fixture-v1","cases":{"de-test":{
        "aggregateFeatures":{},"statements":[
          {"sourceId":"L1761-S2","sourceLevel":"sense","property":"P9971",
           "statementId":"L1761-S2$original","rank":"normal","snaktype":"value",
           "value":"Q1242505","referenceCount":1,
           "qualifiers":{"P3831":[{"snaktype":"value","value":"Q164573"}],
                         "P5713":[{"snaktype":"value","value":"Q131105"}]}}
        ]}}}
    });
    auto index = EvidenceIndex(snapshot);
    GrammarConstraint query;
    query.id = "subject-nominative";
    query.caseId = "de-test";
    query.kind = GrammarConstraintKind.statementExists;
    query.sourceId = "L1761-S2";
    query.propertyId = "P9971";
    query.value = JSONValue("Q1242505");
    query.requiredQualifiers = parseJSON(q{
      {"P3831":[{"snaktype":"value","value":"Q164573"}],
       "P5713":[{"snaktype":"value","value":"Q131105"}]}
    });
    auto atom = scanAttestedSource(index, query, "role-and-case", "sense",
        BindingType.sense, "Q188", "synthetic:construction");
    assert(atom.candidates.length == 1);
    assert(atom.candidates[0].proofs[0].statementId == "L1761-S2$original");
    BoundConstraint rule;
    rule.id = "role-check";
    rule.caseId = "de-test";
    rule.languageId = "Q188";
    rule.constructionId = "synthetic:construction";
    rule.variables ~= BindingVariable("sense", BindingType.sense);
    rule.joinOn ~= "sense";
    rule.atoms ~= atom;
    assert(evaluateBound(rule).status == EvidenceStatus.supported);
    query.requiredQualifiers = parseJSON(q{
      {"P5713":[{"snaktype":"value","value":"Q999"}]}
    });
    rule.atoms[0] = scanAttestedSource(index, query, "missing", "sense",
        BindingType.sense, "Q188", "synthetic:construction");
    assert(evaluateBound(rule).status == EvidenceStatus.unknown);
}

/**
 * Offline bridge regression: resolve configured predicates against ORIGINAL
 * R1.7 evidence. All language IDs are explicit metadata supplied by the
 * caller; their correctness must be checked against the lexeme inventory.
 */
JSONValue evaluateAttestedBindingFixture(JSONValue snapshot,
    JSONValue definitions, JSONValue checks)
{
    enforce(requiredString(definitions, "schemaVersion") ==
        "wikidata-r1.7-predicates-v1", "Wrong predicate schema");
    enforce(requiredString(checks, "schemaVersion") ==
        "wikidata-r1.10-attested-checks-v1", "Wrong attested check schema");
    auto predicates = requiredMember(definitions, "predicates");
    auto cases = requiredMember(checks, "checks");
    enforce(predicates.type == JSONType.array && cases.type == JSONType.array,
        "Expected predicates/checks arrays");
    import wikidata.grammar_evidence : parseGrammarConstraint;
    GrammarConstraint[string] byId;
    foreach (raw; predicates.array)
    {
        auto constraint = parseGrammarConstraint(raw);
        enforce((constraint.id in byId) is null, "Duplicate predicate ID");
        byId[constraint.id] = constraint;
    }
    auto index = EvidenceIndex(snapshot);
    JSONValue report = JSONValue.emptyObject;
    report["schemaVersion"] = "wikidata-r1.10-attested-evaluation-v1";
    report["syntheticOnly"] = false;
    report["results"] = JSONValue.emptyArray;
    bool[string] seen;
    foreach (raw; cases.array)
    {
        auto id = requiredString(raw, "id");
        enforce((id in seen) is null, "Duplicate attested check ID");
        seen[id] = true;
        BoundConstraint rule;
        rule.id = id;
        rule.caseId = requiredString(raw, "case");
        rule.languageId = requiredString(raw, "languageId");
        rule.constructionId = requiredString(raw, "constructionId");
        auto variable = requiredString(raw, "variable");
        auto kind = parseBindingType(requiredString(raw, "type"));
        rule.variables ~= BindingVariable(variable, kind);
        rule.joinOn ~= variable;
        auto ids = requiredMember(raw, "predicates");
        enforce(ids.type == JSONType.array && ids.array.length > 0,
            "Attested check needs predicates");
        foreach (name; ids.array)
        {
            enforce(name.type == JSONType.string, "Predicate ID must be string");
            auto original = name.str in byId;
            enforce(original !is null, "Unknown reference predicate: " ~ name.str);
            enforce((*original).caseId == rule.caseId,
                "Cross-case attested predicate");
            rule.atoms ~= scanAttestedSource(index, *original, name.str,
                variable, kind, rule.languageId, rule.constructionId);
        }
        auto result = evaluateBound(rule);
        enforce(statusName(result.status) == requiredString(raw, "expectedStatus"),
            "Incorrect attested bound status: " ~ id);
        auto matches = requiredMember(raw, "expectedMatches");
        enforce(matches.type == JSONType.integer && matches.integer >= 0 &&
            cast(size_t) matches.integer == result.candidates.length,
            "Incorrect attested witness count: " ~ id);
        JSONValue item = JSONValue.emptyObject;
        item["id"] = id;
        item["status"] = statusName(result.status);
        item["matches"] = cast(long) result.candidates.length;
        item["witnesses"] = JSONValue.emptyArray;
        foreach (ref candidate; result.candidates)
        {
            JSONValue witness = JSONValue.emptyObject;
            witness["case"] = candidate.caseId;
            witness["languageId"] = candidate.languageId;
            witness["constructionId"] = candidate.constructionId;
            witness["sourceId"] = candidate.bindings[0].value.id;
            witness["sourceKind"] = bindingTypeName(candidate.bindings[0].value.kind);
            witness["statementProofs"] = JSONValue.emptyArray;
            foreach (proof; candidate.proofs)
            {
                JSONValue p = JSONValue.emptyObject;
                p["statementId"] = proof.statementId;
                p["sourceId"] = proof.sourceId;
                p["sourceLevel"] = proof.sourceLevel;
                p["property"] = proof.propertyId;
                p["rank"] = proof.rank;
                p["qualifiers"] = proof.qualifiers;
                p["referenceCount"] = cast(long) proof.referenceCount;
                p["sourceDataset"] = proof.sourceDataset;
                witness["statementProofs"].array ~= p;
            }
            item["witnesses"].array ~= witness;
        }
        report["results"].array ~= item;
    }
    return report;
}
