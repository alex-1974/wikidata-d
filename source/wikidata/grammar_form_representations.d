/**
 * R1.12-C3: lossless, evidence-only view of original Wikibase Form
 * representations and same-tag/same-text collisions within ONE Lexeme.
 * All values originate in a byte-verified OriginalLexemeReceipt.
 * No language-specific rules, normalization, transliteration, morphology,
 * Form merging, inferred Form selection or grammar production.
 */
module wikidata.grammar_form_representations;

import std.algorithm.sorting : sort;
import std.conv : to;
import std.json : JSONType, JSONValue;
import std.string : replace;
import wikidata.grammar_statement_witness : SourceSnapshotRef;
import wikidata.grammar_evidence_composition : OriginalLexemeReceipt,
    OriginalFormRepresentationSource, receiptOriginalFormRepresentationSources,
    receiptSourceSnapshot, receiptLexemeLanguageQId;

enum FormRepresentationStatus : ubyte
{
    sourceNotVerified,
    valid,
    invalidOriginalRepresentations
}

struct OriginalFormRepresentationEvidence
{
    SourceSnapshotRef snapshot;
    string lexemeId;
    string lexemeLanguageQId;
    string formId;
    string representationTag;
    string literalText;
    /// RFC 6901 JSON pointer into the ORIGINAL response envelope.
    string originalRepresentationPath;
    string[] originalGrammaticalFeatureIds;
    @property bool permitsFormSelection() const { return false; }
    @property bool permitsGrammarProduction() const { return false; }
    @property bool permitsFormIdMerge() const { return false; }
}

struct OriginalRepresentationCollision
{
    SourceSnapshotRef snapshot;
    string lexemeId;
    string representationTag;
    string literalText;
    /// Two or more distinct original Form IDs; no Form identity collapse.
    string[] distinctFormIds;
    @property bool permitsFormSelection() const { return false; }
    @property bool permitsGrammarProduction() const { return false; }
    @property bool permitsFormIdMerge() const { return false; }
}

struct FormRepresentationBatch
{
    FormRepresentationStatus status;
    SourceSnapshotRef snapshot;
    string lexemeId;
    string lexemeLanguageQId;
    /// All original Form IDs, even those with zero representations.
    string[] originalFormIds;
    string[] formsWithoutRepresentations;
    OriginalFormRepresentationEvidence[] representations;
    OriginalRepresentationCollision[] collisions;
    string invalidFormId;
    string invalidRepresentationTag;
    string error;
    @property bool validInput() const { return status == FormRepresentationStatus.valid; }
    @property bool permitsFormSelection() const { return false; }
    @property bool permitsGrammarProduction() const { return false; }
    @property bool permitsFormIdMerge() const { return false; }
}

private JSONValue* field(ref JSONValue object, string key)
{
    if (object.type != JSONType.object) return null;
    return key in object.object;
}

private string textField(ref JSONValue object, string key)
{
    auto value = field(object, key);
    return value !is null && (*value).type == JSONType.string ? (*value).str : "";
}

private string pointerToken(string token)
{
    // JSON-pointer escaping, NOT orthography or Unicode normalization.
    return token.replace("~", "~0").replace("/", "~1");
}

private FormRepresentationBatch malformed(FormRepresentationBatch batch,
    string formId, string tag, string why)
{
    // Fail the complete batch; a prefix of an invalid source is never valid.
    batch.status = FormRepresentationStatus.invalidOriginalRepresentations;
    batch.error = why;
    batch.invalidFormId = formId;
    batch.invalidRepresentationTag = tag;
    batch.representations = null;
    batch.collisions = null;
    batch.originalFormIds = null;
    batch.formsWithoutRepresentations = null;
    return batch;
}

/** Return only representations explicitly present in verified original bytes.
 *  Object-map key and record.language must match exactly. No tag aliases or
 *  fallbacks are invented. Collision keys are exact (tag, text) pairs, scoped
 *  to the input Lexeme; a same-text different-tag pair is NOT a collision.
 */
FormRepresentationBatch extractOriginalFormRepresentations(
    OriginalLexemeReceipt receipt)
{
    FormRepresentationBatch batch;
    batch.status = FormRepresentationStatus.sourceNotVerified;
    batch.error = "Original Lexeme receipt not verified";
    OriginalFormRepresentationSource[] forms;
    if (!receiptOriginalFormRepresentationSources(receipt, forms)) return batch;
    batch.status = FormRepresentationStatus.valid;
    batch.error = "";
    batch.snapshot = receiptSourceSnapshot(receipt);
    batch.lexemeId = receipt.lexemeId;

    // The language is the original Lexeme Q-ID; not a preferred display tag.
    batch.lexemeLanguageQId = receiptLexemeLanguageQId(receipt);

    OriginalRepresentationCollision[] groups;
    // A length-prefixed tag is an injective key with respect to (tag, text).
    // No reserved character can collide with the subsequent literal text.
    size_t[string] positions;
    foreach (form; forms)
    {
        batch.originalFormIds ~= form.formId;
        if (!form.representationsPresent)
        {
            batch.formsWithoutRepresentations ~= form.formId;
            continue;
        }
        JSONValue mapping = form.originalRepresentations;
        if (mapping.type != JSONType.object)
            return malformed(batch, form.formId, "", "Representations must be an object");
        if (mapping.object.length == 0)
        {
            batch.formsWithoutRepresentations ~= form.formId;
            continue;
        }
        string[] tags = mapping.object.keys;
        tags.sort();
        foreach (tag; tags)
        {
            if (tag.length == 0)
                return malformed(batch, form.formId, tag, "Empty representation tag");
            auto raw = field(mapping, tag);
            if (raw is null || (*raw).type != JSONType.object)
                return malformed(batch, form.formId, tag, "Representation must be an object");
            auto lang = field(*raw, "language");
            auto value = field(*raw, "value");
            if (lang is null || (*lang).type != JSONType.string ||
                (*lang).str != tag)
                return malformed(batch, form.formId, tag, "Representation language differs from original map key");
            if (value is null || (*value).type != JSONType.string)
                return malformed(batch, form.formId, tag, "Representation value is not a string");
            // Preserve the original text byte-for-byte as a UTF-8 D string.
            string literalText = (*value).str;
            OriginalFormRepresentationEvidence evidence;
            evidence.snapshot = form.snapshot;
            evidence.lexemeId = form.lexemeId;
            evidence.lexemeLanguageQId = form.lexemeLanguageQId;
            evidence.formId = form.formId;
            evidence.representationTag = tag;
            evidence.literalText = literalText;
            evidence.originalRepresentationPath = "/entities/" ~
                pointerToken(form.lexemeId) ~ "/forms/" ~
                to!string(form.originalFormIndex) ~ "/representations/" ~
                pointerToken(tag);
            evidence.originalGrammaticalFeatureIds =
                form.originalGrammaticalFeatureIds.dup;
            batch.representations ~= evidence;

            string key = to!string(tag.length) ~ ":" ~ tag ~ literalText;
            auto existing = key in positions;
            if (existing is null)
            {
                OriginalRepresentationCollision group;
                group.snapshot = form.snapshot;
                group.lexemeId = form.lexemeId;
                group.representationTag = tag;
                group.literalText = literalText;
                group.distinctFormIds = [form.formId];
                groups ~= group;
                positions[key] = groups.length; // store index + 1
            }
            else
            {
                size_t index = *existing - 1;
                bool duplicate;
                foreach (prior; groups[index].distinctFormIds)
                    if (prior == form.formId) { duplicate = true; break; }
                if (!duplicate) groups[index].distinctFormIds ~= form.formId;
            }
        }
    }
    foreach (group; groups)
        if (group.distinctFormIds.length > 1)
            batch.collisions ~= group;
    return batch;
}
