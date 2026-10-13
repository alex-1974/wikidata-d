/**
 * R1.12-C1: evidence-only verification of an explicitly P5548-referenced
 * object Form of a P5238 lexical component, across separately verified
 * ORIGINAL owner and target Lexeme snapshots.
 *
 * No allomorph selection, Turkish morphology, construction operation,
 * form synthesis, general form-sense association or Wikidata backfill.
 */
module wikidata.grammar_component_form_evidence;

import std.algorithm.searching : startsWith;
import std.json : JSONType, JSONValue;

import wikidata.grammar_statement_witness : ComponentWitness,
    SourceSnapshotRef, OriginalStatementProof;
import wikidata.grammar_evidence_composition : OriginalLexemeReceipt,
    OriginalFormMembership, CompositionStatus, composeComponents,
    receiptFormMembership;

enum ComponentObjectFormStatus : ubyte
{
    sourceNotVerified,
    noObjectFormQualifier,
    targetNotFetched,
    invalidOrAmbiguousQualifier,
    targetIdentityMismatch,
    formNotPresentInTargetSnapshot,
    verifiedTargetFormMembership
}

/** A pair of independent source revisions, NOT an atomic Wikidata snapshot.
 *  Original statement holds all qualifiers and references verbatim.
 */
struct ComponentObjectFormEvidence
{
    ComponentObjectFormStatus status;
    SourceSnapshotRef ownerSnapshot;
    SourceSnapshotRef targetSnapshot;
    OriginalStatementProof originalComponentStatement;
    string componentLexemeId;
    string formId;
    string ordinalLiteral;
    string originalTargetFormPath;
    @property bool permitsFormSelection() const { return false; }
    @property bool permitsGrammarProduction() const { return false; }
    @property bool permitsGeneralFormSenseAssociation() const { return false; }
}

private JSONValue* member(ref JSONValue obj, string name)
{
    if (obj.type != JSONType.object) return null;
    return name in obj.object;
}

private string literal(ref JSONValue obj, string name)
{
    auto v = member(obj, name);
    return v !is null && (*v).type == JSONType.string ? (*v).str : "";
}

private bool isOwnedFormId(string formId, string lexemeId)
{
    string prefix = lexemeId ~ "-F";
    if (!formId.startsWith(prefix) || formId.length <= prefix.length ||
        formId[prefix.length] == '0') return false;
    foreach (digit; formId[prefix.length .. $])
        if (digit < '0' || digit > '9') return false;
    return true;
}

/** Parse only ONE explicit original P5548 snak. An absent field differs from
 *  an empty/ill-typed field. Do not silently take the first of several snaks.
 */
private ComponentObjectFormStatus readExplicitObjectForm(
    ref JSONValue statement, string componentLexemeId, out string formId)
{
    formId = "";
    auto qualifiers = member(statement, "qualifiers");
    if (qualifiers is null) return ComponentObjectFormStatus.noObjectFormQualifier;
    if ((*qualifiers).type != JSONType.object)
        return ComponentObjectFormStatus.invalidOrAmbiguousQualifier;
    auto snaks = member(*qualifiers, "P5548");
    if (snaks is null) return ComponentObjectFormStatus.noObjectFormQualifier;
    if ((*snaks).type != JSONType.array || (*snaks).array.length != 1)
        return ComponentObjectFormStatus.invalidOrAmbiguousQualifier;
    auto one = (*snaks).array[0];
    if (one.type != JSONType.object ||
        literal(one, "property") != "P5548" ||
        literal(one, "snaktype") != "value" ||
        literal(one, "datatype") != "wikibase-form")
        return ComponentObjectFormStatus.invalidOrAmbiguousQualifier;
    auto datavalue = member(one, "datavalue");
    if (datavalue is null || literal(*datavalue, "type") != "wikibase-entityid")
        return ComponentObjectFormStatus.invalidOrAmbiguousQualifier;
    auto value = member(*datavalue, "value");
    if (value is null || literal(*value, "entity-type") != "form")
        return ComponentObjectFormStatus.invalidOrAmbiguousQualifier;
    formId = literal(*value, "id");
    if (!isOwnedFormId(formId, componentLexemeId))
    {
        formId = "";
        return ComponentObjectFormStatus.invalidOrAmbiguousQualifier;
    }
    return ComponentObjectFormStatus.verifiedTargetFormMembership;
}

private ComponentObjectFormEvidence attestImpl(OriginalLexemeReceipt owner,
    ComponentWitness component, bool targetSupplied, OriginalLexemeReceipt target)
{
    ComponentObjectFormEvidence result;
    result.status = ComponentObjectFormStatus.sourceNotVerified;

    // composeComponents verifies the concrete, unmodified component witness
    // against the ORIGINAL statement re-extracted from this owner receipt.
    auto ownerProof = composeComponents(owner, component, component);
    if (ownerProof.status != CompositionStatus.sameOriginalStatement ||
        ownerProof.sources.length != 2 ||
        ownerProof.sources[0].sourceUrl != component.snapshot.sourceUrl ||
        ownerProof.originalStatements.length != 2)
        return result;

    result.ownerSnapshot = ownerProof.sources[0];
    result.originalComponentStatement = ownerProof.originalStatements[0];
    result.componentLexemeId = component.componentLexemeId;
    result.ordinalLiteral = component.ordinal;

    // A well-typed original P5238 Lexeme-object value is the only legal
    // context for the P5548 object-Form qualifier. D3-C preserves the raw
    // mainsnak but its component witness intentionally does not type-check
    // every future Wikibase datatype. C1 therefore enforces it here.
    auto originalStatement = result.originalComponentStatement.originalStatement;
    auto mainSnak = member(originalStatement, "mainsnak");
    if (result.originalComponentStatement.propertyId != "P5238" ||
        mainSnak is null || literal(*mainSnak, "property") != "P5238" ||
        literal(*mainSnak, "datatype") != "wikibase-lexeme" ||
        literal(*mainSnak, "snaktype") != "value")
        return result;
    auto mainValue = member(*mainSnak, "datavalue");
    if (mainValue is null ||
        literal(*mainValue, "type") != "wikibase-entityid")
        return result;
    auto mainEntity = member(*mainValue, "value");
    if (mainEntity is null ||
        literal(*mainEntity, "entity-type") != "lexeme" ||
        literal(*mainEntity, "id") != component.componentLexemeId)
        return result;

    // A single well-typed P5548 is obligatory for a positive claim.
    string id;
    auto parsed = readExplicitObjectForm(
        result.originalComponentStatement.originalStatement,
        component.componentLexemeId, id);
    result.status = parsed;
    if (parsed != ComponentObjectFormStatus.verifiedTargetFormMembership)
        return result;
    result.formId = id;

    if (!targetSupplied)
    {
        result.status = ComponentObjectFormStatus.targetNotFetched;
        return result;
    }
    if (!target.valid)
    {
        result.status = ComponentObjectFormStatus.sourceNotVerified;
        return result;
    }
    // A mismatched but individually verified target is NOT a missing Form.
    if (target.lexemeId != component.componentLexemeId ||
        target.lexemeId == owner.lexemeId)
    {
        result.status = ComponentObjectFormStatus.targetIdentityMismatch;
        return result;
    }
    OriginalFormMembership memberForm = receiptFormMembership(target, id);
    result.targetSnapshot = memberForm.targetSnapshot;
    if (!memberForm.present)
    {
        result.status = ComponentObjectFormStatus.formNotPresentInTargetSnapshot;
        return result;
    }
    result.originalTargetFormPath = memberForm.originalEvidencePath;
    result.status = ComponentObjectFormStatus.verifiedTargetFormMembership;
    return result;
}

/** When the target has NOT been fetched or is not supplied. */
ComponentObjectFormEvidence attestComponentObjectForm(
    OriginalLexemeReceipt owner, ComponentWitness component)
{
    OriginalLexemeReceipt absent;
    return attestImpl(owner, component, false, absent);
}

/** When an independently byte-checked target receipt IS supplied.
 *  Invalid target receipts fail closed rather than looking like not-fetched.
 */
ComponentObjectFormEvidence attestComponentObjectForm(
    OriginalLexemeReceipt owner, ComponentWitness component,
    OriginalLexemeReceipt target)
{
    return attestImpl(owner, component, true, target);
}
