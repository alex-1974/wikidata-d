/**
 * R1.12-C2: Statement-scoped P5831 usage evidence from ORIGINAL Lexeme bytes.
 * Lexeme/Form/Sense ownership and literal P5830/P6072 qualifiers are separate.
 * No implied Form-Sense join, generated Form, grammar production or selection.
 */
module wikidata.grammar_scoped_usage;

import std.algorithm.searching : startsWith;
import std.json : JSONType, JSONValue;
import wikidata.grammar_statement_witness : SourceSnapshotRef, OriginalStatementProof;
import wikidata.grammar_evidence_composition : OriginalLexemeReceipt,
    OriginalScopedUsageSource, receiptScopedUsageSources,
    receiptFormMembership, receiptContainsSenseId, receiptSourceSnapshot;

enum ScopedUsageOwner : ubyte { lexeme, form, sense }
enum ScopedUsageStatus : ubyte
{
    lexemeExampleOnly,
    formOwnedExample,
    senseOwnedExample,
    explicitFormQualifierOnly,
    explicitSenseQualifierOnly,
    explicitSameStatementPair,
    /// Well-typed original Form/Sense reference absent from this exact revision.
    unresolvedReferencedEntity,
    invalidOrAmbiguous,
    deprecatedOrNonValue
}

struct ScopedUsageExample
{
    SourceSnapshotRef snapshot;
    OriginalStatementProof source;
    ScopedUsageOwner ownerKind;
    ScopedUsageStatus status;
    /// From owner ID only; NEVER fabricated as a P5830/P6072 qualifier.
    string ownerFormId;
    string ownerSenseId;
    /// Present only if one well-typed ORIGINAL qualifier explicitly says so.
    string explicitFormId;
    string explicitSenseId;
    string text;
    string languageTag;
    @property bool permitsFormSelection() const { return false; }
    @property bool permitsGrammarProduction() const { return false; }
    @property bool permitsGeneralFormSenseAssociation() const { return false; }
}

struct ScopedUsageBatch
{
    bool validInput;
    SourceSnapshotRef snapshot;
    ScopedUsageExample[] examples;
    string error;
    @property bool permitsFormSelection() const { return false; }
    @property bool permitsGrammarProduction() const { return false; }
    @property bool permitsGeneralFormSenseAssociation() const { return false; }
}

private JSONValue* field(ref JSONValue obj, string key)
{
    if (obj.type != JSONType.object) return null;
    return key in obj.object;
}
private string stringField(ref JSONValue obj, string key)
{
    auto v = field(obj, key);
    return v !is null && (*v).type == JSONType.string ? (*v).str : "";
}

// Returns false when present but ambiguous/malformed; absence remains valid.
private bool exactQualifier(ref JSONValue statement, string propertyId,
    string datatype, string entityType, out string id, out bool present)
{
    id = "";
    present = false;
    auto qualifiers = field(statement, "qualifiers");
    if (qualifiers is null) return true;
    if ((*qualifiers).type != JSONType.object) return false;
    auto snaks = field(*qualifiers, propertyId);
    if (snaks is null) return true;
    present = true;
    if ((*snaks).type != JSONType.array || (*snaks).array.length != 1)
        return false;
    auto snak = (*snaks).array[0];
    if (snak.type != JSONType.object ||
        stringField(snak, "property") != propertyId ||
        stringField(snak, "datatype") != datatype ||
        stringField(snak, "snaktype") != "value") return false;
    auto dv = field(snak, "datavalue");
    if (dv is null || stringField(*dv, "type") != "wikibase-entityid") return false;
    auto value = field(*dv, "value");
    if (value is null || stringField(*value, "entity-type") != entityType)
        return false;
    id = stringField(*value, "id");
    return id.length != 0;
}

/** Every P5831 statement from the verified receipt is retained, including
 *  partial, deprecated, and ambiguous examples. Only two literal P5830 and
 *  P6072 qualifiers on ONE statement yield explicitSameStatementPair.
 *  A Sense owner is independently recorded as ownerSenseId, NEVER copied into
 *  explicitSenseId; analogously for Form owners.
 */
ScopedUsageBatch extractScopedUsageExamples(OriginalLexemeReceipt receipt)
{
    ScopedUsageBatch batch;
    batch.error = "Original Lexeme receipt not validated";
    if (!receipt.valid) return batch;
    OriginalScopedUsageSource[] originals;
    if (!receiptScopedUsageSources(receipt, originals))
    {
        batch.error = "Malformed or duplicate original P5831 statement";
        return batch;
    }
    batch.snapshot = receiptSourceSnapshot(receipt);
    batch.validInput = true;
    batch.error = "";
    foreach (record; originals)
    {
        ScopedUsageExample evidence;
        evidence.snapshot = record.snapshot;
        evidence.source = record.source;
        evidence.status = ScopedUsageStatus.invalidOrAmbiguous;
        if (record.source.ownerId == receipt.lexemeId)
            evidence.ownerKind = ScopedUsageOwner.lexeme;
        else if (receiptFormMembership(receipt, record.source.ownerId).present)
        {
            evidence.ownerKind = ScopedUsageOwner.form;
            evidence.ownerFormId = record.source.ownerId;
        }
        else if (receiptContainsSenseId(receipt, record.source.ownerId))
        {
            evidence.ownerKind = ScopedUsageOwner.sense;
            evidence.ownerSenseId = record.source.ownerId;
        }
        else
        {
            // Should be impossible for receipt enumerator; fail closed.
            batch.validInput = false;
            batch.examples = null;
            batch.error = "Original owner ID is not part of verified Lexeme";
            return batch;
        }
        auto statement = record.source.originalStatement;
        auto main = field(statement, "mainsnak");
        if (record.source.rank == "deprecated" ||
            record.source.snakType != "value")
            evidence.status = ScopedUsageStatus.deprecatedOrNonValue;
        else if ((record.source.rank == "normal" ||
                  record.source.rank == "preferred") &&
                 main !is null &&
                 stringField(*main, "property") == "P5831" &&
                 stringField(*main, "datatype") == "monolingualtext")
        {
            auto dv = field(*main, "datavalue");
            if (dv !is null && stringField(*dv, "type") == "monolingualtext")
            {
                auto value = field(*dv, "value");
                if (value !is null)
                {
                    evidence.text = stringField(*value, "text");
                    evidence.languageTag = stringField(*value, "language");
                }
            }
            bool hasForm, hasSense;
            string formId, senseId;
            bool validForm = exactQualifier(statement, "P5830", "wikibase-form",
                "form", formId, hasForm);
            bool validSense = exactQualifier(statement, "P6072", "wikibase-sense",
                "sense", senseId, hasSense);
            if (evidence.text.length && evidence.languageTag.length &&
                validForm && validSense)
            {
                // Literal well-typed original qualifiers remain visible even
                // when they refer to IDs absent from this exact snapshot.
                // Such unresolved references are NOT positive membership.
                evidence.explicitFormId = formId;
                evidence.explicitSenseId = senseId;
                if ((hasForm && !receiptFormMembership(receipt, formId).present) ||
                    (hasSense && !receiptContainsSenseId(receipt, senseId)))
                    evidence.status = ScopedUsageStatus.unresolvedReferencedEntity;
                else if ((hasForm && evidence.ownerFormId.length != 0 &&
                          formId != evidence.ownerFormId) ||
                         (hasSense && evidence.ownerSenseId.length != 0 &&
                          senseId != evidence.ownerSenseId))
                    evidence.status = ScopedUsageStatus.invalidOrAmbiguous;
                else if (hasForm && hasSense)
                    evidence.status = ScopedUsageStatus.explicitSameStatementPair;
                else if (hasForm)
                    evidence.status = ScopedUsageStatus.explicitFormQualifierOnly;
                else if (hasSense)
                    evidence.status = ScopedUsageStatus.explicitSenseQualifierOnly;
                else if (evidence.ownerKind == ScopedUsageOwner.form)
                    evidence.status = ScopedUsageStatus.formOwnedExample;
                else if (evidence.ownerKind == ScopedUsageOwner.sense)
                    evidence.status = ScopedUsageStatus.senseOwnedExample;
                else
                    evidence.status = ScopedUsageStatus.lexemeExampleOnly;
            }
        }
        batch.examples ~= evidence;
    }
    return batch;
}
