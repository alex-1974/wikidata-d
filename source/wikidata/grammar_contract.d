/**
 * M5.11: Evaluate versioned, declarative grammar contracts over the original
 * M5.10 Wikidata Forms. This module never inflects, alters Wikidata features,
 * or promotes an underannotated Form to a confirmed conjugation.
 *
 * Hierarchical implications are explicitly curated in the contract, with
 * evidence and approval status. Automatic graph traversal is out of scope.
 */
module wikidata.grammar_contract;

import std.algorithm.searching : canFind;
import std.exception : enforce;
import std.json : JSONType, JSONValue, parseJSON;
import wikidata.query : isEntityId;

private struct ContractRule
{
    string id;
    string sourceFeatureId;
    string[] impliedFeatureIds;
    string status; // approved | review
    string evidence;
}

private struct ContractSlot
{
    string id;
    string[] required;
    string[] anchors;
}

private struct ContractDefinition
{
    string id;
    string languageCode;
    string lexicalCategoryId;
    ContractRule[] rules;
    ContractSlot[] slots;
    string[] incompatibleFeatureIds;
}

private string mandatoryString(JSONValue object, string key)
{
    enforce(object.type == JSONType.object, "Expected JSON object");
    auto value = key in object.object;
    enforce(value !is null && (*value).type == JSONType.string &&
        (*value).str.length > 0, "Missing/invalid string: " ~ key);
    return (*value).str;
}

private JSONValue mandatoryArray(JSONValue object, string key)
{
    enforce(object.type == JSONType.object, "Expected JSON object");
    auto value = key in object.object;
    enforce(value !is null && (*value).type == JSONType.array,
        "Missing/invalid array: " ~ key);
    return *value;
}

private void addUnique(ref string[] list, string id)
{
    if (!list.canFind(id)) list ~= id;
}

private string[] featureIds(JSONValue value, string context, bool nonEmpty)
{
    enforce(value.type == JSONType.array, context ~ " must be an array");
    string[] ids;
    foreach (item; value.array)
    {
        enforce(item.type == JSONType.string && isEntityId(item.str) &&
            item.str[0] == 'Q', "Invalid Q-ID in " ~ context);
        enforce(!ids.canFind(item.str), "Duplicate Q-ID in " ~ context);
        ids ~= item.str;
    }
    enforce(!nonEmpty || ids.length > 0, context ~ " must not be empty");
    return ids;
}

private bool containsAll(const(string)[] available, const(string)[] required)
{
    foreach (id; required)
        if (!available.canFind(id)) return false;
    return true;
}

private JSONValue stringsJson(const(string)[] values)
{
    JSONValue result = JSONValue.emptyArray;
    foreach (value; values) result.array ~= JSONValue(value);
    return result;
}

private ContractDefinition readContract(JSONValue input)
{
    enforce(input.type == JSONType.object, "Contract must be an object");
    enforce(input["schemaVersion"].type == JSONType.integer &&
        input["schemaVersion"].integer == 1,
        "Unsupported grammar-contract schemaVersion");

    ContractDefinition contract;
    contract.id = mandatoryString(input, "id");
    contract.languageCode = mandatoryString(input, "languageCode");
    contract.lexicalCategoryId = mandatoryString(input, "lexicalCategoryId");
    enforce(isEntityId(contract.lexicalCategoryId) &&
        contract.lexicalCategoryId[0] == 'Q', "Invalid lexicalCategoryId");

    // Curated, contract-specific negative evidence. It is NOT a general
    // Wikidata ontology inference: excluded features must be maintained by
    // the contract author and can be absent from underannotated Forms.
    auto incompatible = "incompatibleFeatureIds" in input.object;
    if (incompatible !is null)
        contract.incompatibleFeatureIds = featureIds(*incompatible,
            "incompatibleFeatureIds", false);

    auto rules = mandatoryArray(input, "implications");
    foreach (raw; rules.array)
    {
        ContractRule rule;
        rule.id = mandatoryString(raw, "id");
        rule.sourceFeatureId = mandatoryString(raw, "sourceFeatureId");
        enforce(isEntityId(rule.sourceFeatureId) &&
            rule.sourceFeatureId[0] == 'Q', "Invalid sourceFeatureId");
        rule.impliedFeatureIds = featureIds(
            mandatoryArray(raw, "impliedFeatureIds"),
            "impliedFeatureIds", true);
        rule.status = mandatoryString(raw, "status");
        enforce(rule.status == "approved" || rule.status == "review",
            "Invalid implication status");
        rule.evidence = mandatoryString(raw, "evidence");
        foreach (existing; contract.rules)
            enforce(existing.id != rule.id, "Duplicate implication ID");
        contract.rules ~= rule;
    }

    auto slots = mandatoryArray(input, "slots");
    enforce(slots.array.length > 0, "Contract needs at least one slot");
    foreach (raw; slots.array)
    {
        ContractSlot slot;
        slot.id = mandatoryString(raw, "id");
        slot.required = featureIds(mandatoryArray(raw,
            "requiredFeatureIds"), "requiredFeatureIds", true);
        slot.anchors = featureIds(mandatoryArray(raw,
            "anchorFeatureIds"), "anchorFeatureIds", true);
        foreach (id; contract.incompatibleFeatureIds)
            enforce(!slot.required.canFind(id),
                "An incompatible feature cannot also be required");
        enforce(containsAll(slot.required, slot.anchors),
            "Every anchor must be a required feature");
        enforce(slot.anchors.length < slot.required.length,
            "Anchors must be less specific than the full requirement");
        foreach (existing; contract.slots)
            enforce(existing.id != slot.id, "Duplicate grammar slot ID");
        contract.slots ~= slot;
    }
    return contract;
}

/**
 * Add the immediate implications of features explicitly present on a Form.
 * This is deliberately a one-step expansion, not a silent P279* traversal.
 */
private string[] expand(const(string)[] originals,
    const(ContractRule)[] rules, bool includeReview,
    out string[] appliedRuleIds)
{
    string[] available;
    foreach (feature; originals) addUnique(available, feature);
    foreach (rule; rules)
    {
        if (!includeReview && rule.status != "approved") continue;
        if (!originals.canFind(rule.sourceFeatureId)) continue;
        bool contributes;
        foreach (feature; rule.impliedFeatureIds)
        {
            if (!available.canFind(feature))
            {
                addUnique(available, feature);
                contributes = true;
            }
        }
        if (contributes) appliedRuleIds ~= rule.id;
    }
    return available;
}

private JSONValue makeCandidate(JSONValue form, string method,
    const(string)[] appliedRuleIds, const(string)[] missing)
{
    JSONValue output = JSONValue.emptyObject;
    output["formId"] = form["formId"].str;
    output["lexemeId"] = form["lexemeId"].str;
    output["method"] = method;
    output["originalFeatureIds"] = form["grammaticalFeatureIds"];
    output["appliedRuleIds"] = stringsJson(appliedRuleIds);
    output["missingRequiredFeatureIds"] = stringsJson(missing);
    output["representations"] = form["representations"];
    return output;
}

/**
 * Resolve one Lexeme against all slots in a declarative contract, preserving
 * every matching Form and its original data. No network request is performed.
 *
 * A 'review' result is NOT confirmed. An 'incomplete' candidate (e.g. stiamo)
 * is diagnostic only and does not count as a conjugation answer.
 */
JSONValue evaluateGrammarContract(JSONValue contractInput,
    JSONValue representationsReport, string lexemeId)
{
    auto contract = readContract(contractInput);
    enforce(representationsReport.type == JSONType.object,
        "Representation report must be an object");
    enforce(mandatoryString(representationsReport, "languageCode") ==
        contract.languageCode, "Contract/report language mismatch");
    auto summary = representationsReport["summary"];
    enforce(summary["missingFromLatestQuery"].integer == 0 &&
        summary["newSinceAudit"].integer == 0,
        "Representation snapshot differs from grammar audit");
    auto forms = mandatoryArray(representationsReport, "forms");
    enforce(forms.array.length ==
        cast(size_t) summary["auditForms"].integer,
        "Report Form count mismatch");
    enforce(isEntityId(lexemeId) && lexemeId[0] == 'L',
        "Invalid target Lexeme ID");

    JSONValue[] eligible;
    bool[string] seenForms;
    foreach (row; forms.array)
    {
        if (mandatoryString(row, "lexemeId") != lexemeId) continue;
        enforce(mandatoryString(row, "lexicalCategoryId") ==
            contract.lexicalCategoryId, "Lexeme category differs from contract");
        auto id = mandatoryString(row, "formId");
        enforce((id in seenForms) is null, "Duplicate Form in report");
        seenForms[id] = true;
        // A Form without a representation in the requested language cannot
        // supply an answer, even if its grammatical features match.
        bool hasRequestedLanguage;
        foreach (rep; mandatoryArray(row, "representations").array)
        {
            enforce(rep.type == JSONType.object,
                "Invalid representation object");
            auto lang = "languageCode" in rep.object;
            enforce(lang !is null && (*lang).type == JSONType.string,
                "Invalid representation languageCode");
            if ((*lang).str == contract.languageCode)
                hasRequestedLanguage = true;
        }
        if (hasRequestedLanguage) eligible ~= row;
    }

    JSONValue results = JSONValue.emptyArray;
    size_t confirmed, review, missing;
    foreach (slot; contract.slots)
    {
        JSONValue matches = JSONValue.emptyArray;
        JSONValue nearMisses = JSONValue.emptyArray;
        JSONValue excludedCandidates = JSONValue.emptyArray;
        size_t bestRank;
        foreach (row; eligible)
        {
            auto originals = featureIds(row["grammaticalFeatureIds"],
                "grammaticalFeatureIds", false);
            // Person + number alone are far too broad for near-misses:
            // an imperfect, preterite or subjunctive first-person plural
            // is not evidence of a present-indicative first-person plural.
            // Reject Forms carrying explicit evidence incompatible with
            // the contract, even if their spelling equals a valid answer.
            string[] incompatibleIds;
            foreach (id; contract.incompatibleFeatureIds)
                if (originals.canFind(id)) incompatibleIds ~= id;
            if (incompatibleIds.length)
            {
                if (containsAll(originals, slot.anchors))
                {
                    auto rejected = makeCandidate(row, "incompatible",
                        [], []);
                    rejected["incompatibleFeatureIds"] =
                        stringsJson(incompatibleIds);
                    excludedCandidates.array ~= rejected;
                }
                continue;
            }
            string[] approvedRules;
            string[] allRules;
            auto approved = expand(originals, contract.rules, false,
                approvedRules);
            auto proposed = expand(originals, contract.rules, true,
                allRules);
            string method;
            size_t rank;
            string[] applied;
            if (containsAll(originals, slot.required))
            {
                method = "exact";
                rank = 3;
            }
            else if (containsAll(approved, slot.required))
            {
                method = "inherited";
                applied = approvedRules;
                rank = 2;
            }
            else if (containsAll(proposed, slot.required))
            {
                method = "review";
                applied = allRules;
                rank = 1;
            }
            if (rank)
            {
                matches.array ~= makeCandidate(row, method, applied, []);
                if (rank > bestRank) bestRank = rank;
            }
            else if (containsAll(originals, slot.anchors))
            {
                // Incomplete metadata: retain the candidate for human
                // inspection, but NEVER promote it to a confirmed answer.
                string[] missingFeatures;
                foreach (required; slot.required)
                    if (!approved.canFind(required))
                        missingFeatures ~= required;
                nearMisses.array ~= makeCandidate(row, "incomplete",
                    approvedRules, missingFeatures);
            }
        }
        JSONValue result = JSONValue.emptyObject;
        result["slotId"] = slot.id;
        result["requiredFeatureIds"] = stringsJson(slot.required);
        result["matches"] = matches;
        // Diagnostic only: never part of matches or coverage counts.
        result["excludedCandidates"] = excludedCandidates;
        // Show near-misses only if no confirmed match exists for the slot.
        result["incompleteCandidates"] = bestRank >= 2 ?
            JSONValue.emptyArray : nearMisses;
        string status = bestRank == 3 ? "exact" :
            bestRank == 2 ? "inherited" :
            bestRank == 1 ? "review" : "missing";
        result["status"] = status;
        if (bestRank >= 2) ++confirmed;
        else if (bestRank == 1) ++review;
        else ++missing;
        results.array ~= result;
    }
    JSONValue stats = JSONValue.emptyObject;
    stats["slots"] = cast(long) contract.slots.length;
    stats["confirmedSlots"] = cast(long) confirmed;
    stats["reviewSlots"] = cast(long) review;
    stats["missingSlots"] = cast(long) missing;
    JSONValue output = JSONValue.emptyObject;
    output["schemaVersion"] = 1;
    output["contractId"] = contract.id;
    output["lexemeId"] = lexemeId;
    output["languageCode"] = contract.languageCode;
    output["summary"] = stats;
    output["slots"] = results;
    return output;
}

unittest
{
    import std.exception : assertThrown;
    auto contract = parseJSON(`{
      "schemaVersion":1,"id":"it.present","languageCode":"it",
      "lexicalCategoryId":"Q24905",
      "incompatibleFeatureIds":["Q12547192","Q3502553","Q22716","Q1475560"],
      "implications":[{
        "id":"present-indicative-p279","sourceFeatureId":"Q56682909",
        "impliedFeatureIds":["Q682111","Q192613"],
        "status":"approved","evidence":"reviewed P279 relation"}],
      "slots":[{"id":"1pl",
        "requiredFeatureIds":["Q682111","Q192613","Q21714344","Q146786"],
        "anchorFeatureIds":["Q21714344","Q146786"]}]
    }`);
    auto report = parseJSON(`{
      "languageCode":"it",
      "summary":{"auditForms":6,"missingFromLatestQuery":0,"newSinceAudit":0},
      "forms":[
        {"lexemeId":"L21251","formId":"L21251-F9",
         "lexicalCategoryId":"Q24905",
         "grammaticalFeatureIds":["Q146786","Q21714344"],
         "representations":[{"text":"stiamo","languageCode":"it"}]},
        {"lexemeId":"L21251","formId":"L21251-F16",
         "lexicalCategoryId":"Q24905",
         "grammaticalFeatureIds":["Q146786","Q21714344","Q12547192"],
         "representations":[{"text":"stavamo","languageCode":"it"}]},
        {"lexemeId":"L21251","formId":"L21251-F40",
         "lexicalCategoryId":"Q24905",
         "grammaticalFeatureIds":["Q146786","Q21714344","Q3502553"],
         "representations":[{"text":"stiamo","languageCode":"it"}]},
        {"lexemeId":"L21251","formId":"L21251-F51",
         "lexicalCategoryId":"Q24905",
         "grammaticalFeatureIds":["Q146786","Q21714344","Q22716"],
         "representations":[{"text":"stiamo","languageCode":"it"}]},
        {"lexemeId":"L21251","formId":"L21251-F28",
         "lexicalCategoryId":"Q24905",
         "grammaticalFeatureIds":["Q146786","Q21714344","Q682111","Q1475560"],
         "representations":[{"text":"staremo","languageCode":"it"}]},
        {"lexemeId":"L38246","formId":"L38246-F6",
         "lexicalCategoryId":"Q24905",
         "grammaticalFeatureIds":["Q146786","Q21714344","Q56682909"],
         "representations":[{"text":"andiamo","languageCode":"it"}]}
      ]
    }`);
    auto missing = evaluateGrammarContract(contract, report, "L21251");
    assert(missing["summary"]["confirmedSlots"].integer == 0);
    assert(missing["slots"].array[0]["status"].str == "missing");
    auto near = missing["slots"].array[0]["incompleteCandidates"].array;
    assert(near.length == 1);
    assert(near[0]["formId"].str == "L21251-F9");
    assert(near[0]["missingRequiredFeatureIds"].array.length == 2);
    // Identical spelling is not enough to classify a subjunctive or
    // imperative Form as a present-indicative candidate.
    auto excluded = missing["slots"].array[0]["excludedCandidates"].array;
    assert(excluded.length == 4);
    // Q1475560 (simple future) must not be suggested as present.
    bool futureRejected;
    foreach (row; excluded)
        if (row["formId"].str == "L21251-F28")
        {
            futureRejected = true;
            assert(row["incompatibleFeatureIds"].array[0].str == "Q1475560");
        }
    assert(futureRejected);
    foreach (row; excluded)
        assert(row["method"].str == "incompatible");
    auto found = evaluateGrammarContract(contract, report, "L38246");
    assert(found["summary"]["confirmedSlots"].integer == 1);
    assert(found["slots"].array[0]["status"].str == "inherited");
    assert(found["slots"].array[0]["matches"].array[0]["formId"].str ==
        "L38246-F6");

    auto reviewContract = parseJSON(contract.toString());
    reviewContract["implications"].array[0]["status"] = "review";
    auto onlyReview = evaluateGrammarContract(reviewContract, report, "L38246");
    assert(onlyReview["summary"]["confirmedSlots"].integer == 0);
    assert(onlyReview["summary"]["reviewSlots"].integer == 1);
    assert(onlyReview["slots"].array[0]["status"].str == "review");

    auto unsafeContract = parseJSON(contract.toString());
    JSONValue wrongAnchors = JSONValue.emptyArray;
    wrongAnchors.array ~= JSONValue("Q110786");
    unsafeContract["slots"].array[0]["anchorFeatureIds"] = wrongAnchors;
    assertThrown!Exception(readContract(unsafeContract));
}
