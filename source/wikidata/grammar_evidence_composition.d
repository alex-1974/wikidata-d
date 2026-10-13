/**
 * R1.11-D3-D2: read-only, evidence-only composition over ORIGINAL Wikibase
 * response bytes. A co-indexed identity is never a new lexical statement.
 *
 * Receipt checks byte digest, entity ID, revision, and D3-C original-source
 * parsing. It does NOT certify that Wikimedia served the bytes; upstream
 * retrieval and source URL provenance must be established independently.
 */
module wikidata.grammar_evidence_composition;

import std.digest : toHexString;
import std.digest.sha : sha256Of;
import std.json : JSONType, JSONValue, parseJSON;
import wikidata.lexeme : WikidataLexeme, parseLexeme;
import wikidata.grammar_attestation : FormAttestation,
    FormAttestationStatus, SenseMembership, SenseMembershipStatus;
import wikidata.grammar_statement_witness : SourceSnapshotRef,
    OriginalStatementProof, StatementWitnessBatch, UsageExampleWitness,
    ComponentWitness, SemanticArgumentWitness, extractOriginalStatementWitnesses;

enum CompositionStatus : ubyte
{
    invalidInput, notVerified, noPositiveBinding, notSameSnapshot,
    differentLexemes, noIdentityMatch, sameOriginalStatement,
    integrityConflict, unverifiedStatementIdentity,
    sameContextPair, sameFormOnly, sameSenseOnly, parallelEvidence,
    coIndexedSameForm, coIndexedSameSense, parallelSameSense,
    parallelComponents, targetSnapshotPresent
}

/** Constructed only after checking original RESPONSE BYTES and re-parsing D3-C.
 * Its internal batch is not exposed. An invalid/default receipt is unusable.
 */
struct OriginalLexemeReceipt
{
    private bool authenticatedBytes;
    private SourceSnapshotRef source;
    private WikidataLexeme entity;
    private StatementWitnessBatch batch;
    private string failure;

    @property bool valid() const { return authenticatedBytes; }
    @property string error() const { return failure; }
    @property string lexemeId() const { return source.lexemeId; }
    @property ulong revision() const { return source.revision; }
    @property string rawResponseSha256() const { return source.rawResponseSha256; }
    @property size_t usageCount() const { return batch.usageExamples.length; }
    @property size_t componentCount() const { return batch.components.length; }
    @property size_t argumentCount() const { return batch.semanticArguments.length; }
    @property size_t observationCount() const { return batch.observations.length; }
}

private JSONValue* field(ref JSONValue obj, string name)
{
    if (obj.type != JSONType.object) return null;
    return name in obj.object;
}

private string textField(ref JSONValue obj, string name)
{
    auto v = field(obj, name);
    return v !is null && (*v).type == JSONType.string ? (*v).str : "";
}

private bool snapshotEquals(SourceSnapshotRef a, SourceSnapshotRef b)
{
    return a.lexemeId == b.lexemeId && a.revision == b.revision &&
        a.rawResponseSha256 == b.rawResponseSha256;
}

private string byteHash(string originalBytes)
{
    // std.digest's default hexadecimal alphabet is uppercase; Wikidata-D
    // manifests use lowercase SHA-256. Preserve each original input byte.
    auto hex = toHexString(sha256Of(cast(const(ubyte)[]) originalBytes));
    string outHash;
    foreach (c; hex)
        outHash ~= ((c >= 'A' && c <= 'F') ? cast(char)(c + 32) : c);
    return outHash;
}

/** Strict byte/SHA/revision/entity validation; never fetches the network.
 * Caller must independently establish the bytes' original source identity.
 * A caller-claimed digest alone is NOT a validated receipt.
 */
OriginalLexemeReceipt verifyOriginalLexemeBytes(string originalBytes,
    SourceSnapshotRef expected)
{
    OriginalLexemeReceipt result;
    result.failure = "Original response bytes did not validate";
    if (originalBytes.length == 0 || expected.lexemeId.length < 2 ||
        expected.revision == 0 || expected.rawResponseSha256.length != 64 ||
        expected.sourceUrl.length == 0 ||
        byteHash(originalBytes) != expected.rawResponseSha256)
        return result;

    JSONValue root;
    try { root = parseJSON(originalBytes); }
    catch (Exception) { return result; }
    auto entities = field(root, "entities");
    if (entities is null) return result;
    auto target = field(*entities, expected.lexemeId);
    if (target is null || textField(*target, "id") != expected.lexemeId)
        return result;
    auto revision = field(*target, "lastrevid");
    if (revision is null || (*revision).type != JSONType.integer ||
        (*revision).integer <= 0 ||
        cast(ulong)(*revision).integer != expected.revision)
        return result;
    WikidataLexeme parsed;
    try { parsed = parseLexeme(*target); }
    catch (Exception) { return result; }
    auto verifiedBatch = extractOriginalStatementWitnesses(parsed, expected);
    if (!verifiedBatch.validInput) return result;
    result.authenticatedBytes = true;
    result.source = expected;
    result.entity = parsed;
    result.batch = verifiedBatch;
    result.failure = "";
    return result;
}

/** Return original D3-C witnesses from the validated receipt; these are not
 * invented pairs, and edits to a returned copy do not validate in compose.
 */
bool receiptUsage(OriginalLexemeReceipt receipt, size_t index,
    out UsageExampleWitness witness)
{
    if (!receipt.authenticatedBytes || index >= receipt.batch.usageExamples.length)
        return false;
    witness = receipt.batch.usageExamples[index];
    witness.source.originalStatement = parseJSON(witness.source.originalStatement.toString());
    return true;
}

bool receiptComponent(OriginalLexemeReceipt receipt, size_t index,
    out ComponentWitness witness)
{
    if (!receipt.authenticatedBytes || index >= receipt.batch.components.length)
        return false;
    witness = receipt.batch.components[index];
    witness.source.originalStatement = parseJSON(witness.source.originalStatement.toString());
    return true;
}

bool receiptSemanticArgument(OriginalLexemeReceipt receipt, size_t index,
    out SemanticArgumentWitness witness)
{
    if (!receipt.authenticatedBytes || index >= receipt.batch.semanticArguments.length)
        return false;
    witness = receipt.batch.semanticArguments[index];
    witness.source.originalStatement = parseJSON(witness.source.originalStatement.toString());
    return true;
}

private bool proofEquals(OriginalStatementProof a, OriginalStatementProof b)
{
    return a.ownerId == b.ownerId && a.statementId == b.statementId &&
        a.propertyId == b.propertyId && a.rank == b.rank &&
        a.snakType == b.snakType && a.referenceCount == b.referenceCount &&
        a.originalStatement.toString() == b.originalStatement.toString();
}

private bool receiptHasUsage(OriginalLexemeReceipt r, UsageExampleWitness w)
{
    if (!r.authenticatedBytes || !snapshotEquals(r.source, w.snapshot)) return false;
    foreach (trusted; r.batch.usageExamples)
        if (proofEquals(trusted.source, w.source) &&
            trusted.formId == w.formId && trusted.senseId == w.senseId &&
            trusted.text == w.text && trusted.languageTag == w.languageTag)
            return true;
    return false;
}

private bool receiptHasComponent(OriginalLexemeReceipt r, ComponentWitness w)
{
    if (!r.authenticatedBytes || !snapshotEquals(r.source, w.snapshot)) return false;
    foreach (trusted; r.batch.components)
        if (proofEquals(trusted.source, w.source) &&
            trusted.componentLexemeId == w.componentLexemeId &&
            trusted.ordinal == w.ordinal &&
            trusted.hasUnverifiedObjectFormQualifier == w.hasUnverifiedObjectFormQualifier)
            return true;
    return false;
}

private bool receiptHasArgument(OriginalLexemeReceipt r, SemanticArgumentWitness w)
{
    if (!r.authenticatedBytes || !snapshotEquals(r.source, w.snapshot)) return false;
    foreach (trusted; r.batch.semanticArguments)
        if (proofEquals(trusted.source, w.source) &&
            trusted.senseId == w.senseId &&
            trusted.argumentQId == w.argumentQId && trusted.roleQId == w.roleQId)
            return true;
    return false;
}

struct CompositionResult
{
    CompositionStatus status;
    SourceSnapshotRef[] sources;
    OriginalStatementProof[] originalStatements;
    FormAttestation[] formAttestations;
    SenseMembership[] senseMemberships;
    // This is metadata only; it does not invent another Wikibase statement.
    @property bool permitsGrammarProduction() const { return false; }
    @property bool permitsFormSelection() const { return false; }
    @property bool permitsGeneralFormSenseAssociation() const { return false; }
}

private CompositionResult resultOf(CompositionStatus status)
{
    CompositionResult r;
    r.status = status;
    return r;
}

private CompositionStatus checkSameSnapshot(OriginalLexemeReceipt a,
    OriginalLexemeReceipt b)
{
    if (!a.authenticatedBytes || !b.authenticatedBytes)
        return CompositionStatus.notVerified;
    if (a.source.lexemeId != b.source.lexemeId)
        return CompositionStatus.differentLexemes;
    if (!snapshotEquals(a.source, b.source))
        return CompositionStatus.notSameSnapshot;
    return CompositionStatus.parallelEvidence;
}

private CompositionResult pairOriginals(CompositionStatus status,
    SourceSnapshotRef a, OriginalStatementProof aProof,
    SourceSnapshotRef b, OriginalStatementProof bProof)
{
    CompositionResult r = resultOf(status);
    r.sources = [a, b];
    aProof.originalStatement = parseJSON(aProof.originalStatement.toString());
    bProof.originalStatement = parseJSON(bProof.originalStatement.toString());
    r.originalStatements = [aProof, bProof];
    return r;
}

/** Compare TWO already-attested examples. Same GUID is ONE original claim.
 * Same Form or Sense is a metarelation, not a general Form-Sense mapping.
 */
CompositionResult composeUsages(OriginalLexemeReceipt aSource,
    UsageExampleWitness a, OriginalLexemeReceipt bSource,
    UsageExampleWitness b)
{
    if (!aSource.valid || !bSource.valid) return resultOf(CompositionStatus.notVerified);
    if (!receiptHasUsage(aSource, a) || !receiptHasUsage(bSource, b))
        return resultOf(CompositionStatus.integrityConflict);
    auto snapshotStatus = checkSameSnapshot(aSource, bSource);
    if (snapshotStatus != CompositionStatus.parallelEvidence) return resultOf(snapshotStatus);
    CompositionStatus kind;
    if (a.source.statementId == b.source.statementId)
    {
        if (!proofEquals(a.source, b.source))
            return resultOf(CompositionStatus.integrityConflict);
        kind = CompositionStatus.sameOriginalStatement;
    }
    else if (a.formId == b.formId && a.senseId == b.senseId)
        kind = CompositionStatus.sameContextPair;
    else if (a.formId == b.formId)
        kind = CompositionStatus.sameFormOnly;
    else if (a.senseId == b.senseId)
        kind = CompositionStatus.sameSenseOnly;
    else
        kind = CompositionStatus.parallelEvidence;
    return pairOriginals(kind, a.snapshot, a.source, b.snapshot, b.source);
}

private bool originalFeaturePresent(OriginalLexemeReceipt receipt,
    string formId, string featureId)
{
    foreach (form; receipt.entity.forms)
        if (form.id == formId)
            foreach (feature; form.grammaticalFeatures)
                if (feature == featureId) return true;
    return false;
}

private bool originalSensePresent(OriginalLexemeReceipt receipt,
    string senseId)
{
    foreach (sense; receipt.entity.senses)
        if (sense.id == senseId) return true;
    return false;
}

/** D2 evidence and D3-C statement only share a Form ID: no usage condition. */
CompositionResult composeUsageForm(OriginalLexemeReceipt receipt,
    UsageExampleWitness usage, FormAttestation form)
{
    if (!receipt.valid) return resultOf(CompositionStatus.notVerified);
    if (!receiptHasUsage(receipt, usage))
        return resultOf(CompositionStatus.integrityConflict);
    if (form.status != FormAttestationStatus.attestedFeatureOnly)
        return resultOf(CompositionStatus.noPositiveBinding);
    if (form.lexemeId != receipt.source.lexemeId ||
        form.lexemeSnapshotSha256 != receipt.source.rawResponseSha256 ||
        form.formId != usage.formId || !form.featurePresentInOriginal ||
        !originalFeaturePresent(receipt, form.formId, form.featureQId))
        return resultOf(CompositionStatus.noIdentityMatch);
    CompositionResult result = resultOf(CompositionStatus.coIndexedSameForm);
    result.sources = [receipt.source];
    result.originalStatements = [usage.source];
    result.formAttestations = [form];
    return result;
}

/** D2 membership does not assert that the member Sense uses this Form. */
CompositionResult composeUsageSense(OriginalLexemeReceipt receipt,
    UsageExampleWitness usage, SenseMembership sense)
{
    if (!receipt.valid) return resultOf(CompositionStatus.notVerified);
    if (!receiptHasUsage(receipt, usage))
        return resultOf(CompositionStatus.integrityConflict);
    if (sense.status != SenseMembershipStatus.attestedMembershipOnly)
        return resultOf(CompositionStatus.noPositiveBinding);
    if (sense.lexemeId != receipt.source.lexemeId ||
        sense.lexemeSnapshotSha256 != receipt.source.rawResponseSha256 ||
        sense.senseId != usage.senseId ||
        !originalSensePresent(receipt, sense.senseId))
        return resultOf(CompositionStatus.noIdentityMatch);
    CompositionResult result = resultOf(CompositionStatus.coIndexedSameSense);
    result.sources = [receipt.source];
    result.originalStatements = [usage.source];
    result.senseMemberships = [sense];
    return result;
}

/** Different original claims on one Sense remain parallel, not grammar. */
CompositionResult composeUsageArgument(OriginalLexemeReceipt receipt,
    UsageExampleWitness usage, SemanticArgumentWitness argument)
{
    if (!receipt.valid) return resultOf(CompositionStatus.notVerified);
    if (!receiptHasUsage(receipt, usage) || !receiptHasArgument(receipt, argument))
        return resultOf(CompositionStatus.integrityConflict);
    if (usage.senseId != argument.senseId)
        return resultOf(CompositionStatus.noIdentityMatch);
    return pairOriginals(CompositionStatus.parallelSameSense,
        usage.snapshot, usage.source, argument.snapshot, argument.source);
}

CompositionResult composeArguments(OriginalLexemeReceipt receipt,
    SemanticArgumentWitness a, SemanticArgumentWitness b)
{
    if (!receipt.valid) return resultOf(CompositionStatus.notVerified);
    if (!receiptHasArgument(receipt, a) || !receiptHasArgument(receipt, b))
        return resultOf(CompositionStatus.integrityConflict);
    if (a.source.statementId == b.source.statementId)
        return pairOriginals(CompositionStatus.sameOriginalStatement,
            a.snapshot, a.source, b.snapshot, b.source);
    if (a.senseId != b.senseId)
        return resultOf(CompositionStatus.noIdentityMatch);
    return pairOriginals(CompositionStatus.parallelSameSense,
        a.snapshot, a.source, b.snapshot, b.source);
}

CompositionResult composeComponents(OriginalLexemeReceipt receipt,
    ComponentWitness a, ComponentWitness b)
{
    if (!receipt.valid) return resultOf(CompositionStatus.notVerified);
    if (!receiptHasComponent(receipt, a) || !receiptHasComponent(receipt, b))
        return resultOf(CompositionStatus.integrityConflict);
    auto status = a.source.statementId == b.source.statementId ?
        CompositionStatus.sameOriginalStatement : CompositionStatus.parallelComponents;
    return pairOriginals(status, a.snapshot, a.source, b.snapshot, b.source);
}

/** Target Lexeme is independently checked; P5548 is NOT validated here. */
CompositionResult composeComponentTarget(OriginalLexemeReceipt owner,
    ComponentWitness component, OriginalLexemeReceipt target)
{
    if (!owner.valid || !target.valid)
        return resultOf(CompositionStatus.notVerified);
    if (!receiptHasComponent(owner, component))
        return resultOf(CompositionStatus.integrityConflict);
    if (component.componentLexemeId != target.lexemeId ||
        target.lexemeId == owner.lexemeId)
        return resultOf(CompositionStatus.noIdentityMatch);
    CompositionResult result = resultOf(CompositionStatus.targetSnapshotPresent);
    result.sources = [owner.source, target.source];
    result.originalStatements = [component.source];
    return result;
}


/** R1.12-C1: lookup of an ALREADY PRESENT target Form in a byte-verified
 *  original Lexeme receipt. Never selects, synthesizes or infers a Form.
 *  The zero-value result means no verified membership.
 */
struct OriginalFormMembership
{
    bool present;
    SourceSnapshotRef targetSnapshot;
    string formId;
    string originalEvidencePath;
    @property bool permitsFormSelection() const { return false; }
    @property bool permitsGrammarProduction() const { return false; }
}

/** Membership only; even a sole Form does not imply a missing P5548 link.
 *  Form IDs remain distinct regardless of identical representations.
 */
OriginalFormMembership receiptFormMembership(OriginalLexemeReceipt receipt,
    string formId)
{
    OriginalFormMembership result;
    if (!receipt.valid) return result;
    result.targetSnapshot = receipt.source;
    foreach (i, form; receipt.entity.forms)
    {
        if (form.id == formId)
        {
            import std.conv : to;
            result.present = true;
            result.formId = formId;
            result.originalEvidencePath = "entities." ~ receipt.source.lexemeId ~
                ".forms[" ~ to!string(i) ~ "]";
            return result;
        }
    }
    return result;
}
