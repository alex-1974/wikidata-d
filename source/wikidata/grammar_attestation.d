/**
 * R1.11-D2: evidence-only attachment of D1 metadata to ORIGINAL Lexeme objects.
 *
 * A grammatical feature is attestable ONLY via one existing Form's
 * grammaticalFeatures in the original Lexeme JSON. Sense membership is a
 * separate claim and never implies that a Form expresses that Sense.
 *
 * No Form creation, surface-form equality matching, grammar execution,
 * ontology inference, or word-form selection is implemented here.
 * Source digests are EXTERNALLY VERIFIED references, not hashes computed here.
 */
module wikidata.grammar_attestation;

import std.algorithm.searching : startsWith;
import std.json : JSONType;

import wikidata.lexeme : WikidataLexeme, parseLexeme;
import wikidata.grammar_dimension : FeatureClassification, ClassificationKind;
import wikidata.grammar_facet : FacetAssessment, FacetAssessmentKind;

enum FormAttestationStatus : ubyte
{
    unknown,
    attestedFeatureOnly,
    quarantined,
    invalidInput
}

enum SenseMembershipStatus : ubyte
{
    unknown,
    attestedMembershipOnly,
    invalidInput
}

/** The source digest must be checked against ORIGINAL response bytes outside
 *  this module. A digest supplied by a caller is not a cryptographic proof.
 */
struct FormAttestationRequest
{
    string lexemeId;
    string languageId;
    string lexicalCategoryId;
    string formId;
    string featureQId;
    string lexemeSnapshotSha256;
    string itemGraphSnapshotSha256;
}

struct SenseMembershipRequest
{
    string lexemeId;
    string languageId;
    string senseId;
    string lexemeSnapshotSha256;
}

struct FormAttestation
{
    FormAttestationStatus status;
    string lexemeId;
    string languageId;
    string lexicalCategoryId;
    string formId;
    string featureQId;
    string lexemeSnapshotSha256;
    string itemGraphSnapshotSha256;
    /// Original Q-item statement witnesses, NOT lexical Form statements.
    string[] dimensionWitnessStatementIds;
    ClassificationKind classification;
    FacetAssessmentKind semanticReview;

    /// Location in the supplied original Lexeme JSON, not a statement ID.
    string originalEvidencePath;
    bool featurePresentInOriginal;

    @property bool permitsGrammarProduction() const { return false; }
    @property bool permitsFormSelection() const { return false; }
    @property bool permitsFormSenseAssociation() const { return false; }
}

struct SenseMembership
{
    SenseMembershipStatus status;
    string lexemeId;
    string languageId;
    string senseId;
    string lexemeSnapshotSha256;
    string originalEvidencePath;

    @property bool permitsGrammarProduction() const { return false; }
    @property bool permitsFormSelection() const { return false; }
    @property bool permitsFormSenseAssociation() const { return false; }
}

private bool isId(string id, char prefix)
{
    if (id.length < 2 || id[0] != prefix || id[1] == '0') return false;
    foreach (c; id[1 .. $])
        if (c < '0' || c > '9') return false;
    return true;
}

private bool isOwnedSubId(string id, string lexemeId, char suffix)
{
    auto prefix = lexemeId ~ "-" ~ suffix;
    if (!id.startsWith(prefix) || id.length <= prefix.length ||
        id[prefix.length] == '0') return false;
    foreach (c; id[prefix.length .. $])
        if (c < '0' || c > '9') return false;
    return true;
}

private bool isSha256(string hash)
{
    if (hash.length != 64) return false;
    foreach (c; hash)
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')))
            return false;
    return true;
}

/** Do not trust a caller-mutated typed view over the embedded original JSON.
 *  Parse the JSON anew and demand that the key derived fields still agree.
 *  This does not authenticate the original response; an upstream digest audit
 *  is required for original-Wikidata provenance.
 */
private bool canonicalize(WikidataLexeme supplied, out WikidataLexeme canonical)
{
    // Malformed original JSON throws from parseLexeme (no silent fallback).
    if (supplied.raw.type != JSONType.object) return false;
    canonical = parseLexeme(supplied.raw);
    if (!isId(canonical.id, 'L') || !isId(canonical.languageId, 'Q') ||
        !isId(canonical.lexicalCategoryId, 'Q') ||
        supplied.id != canonical.id ||
        supplied.languageId != canonical.languageId ||
        supplied.lexicalCategoryId != canonical.lexicalCategoryId ||
        supplied.forms.length != canonical.forms.length ||
        supplied.senses.length != canonical.senses.length)
        return false;

    bool[string] seen;
    foreach (i, form; canonical.forms)
    {
        if (!isOwnedSubId(form.id, canonical.id, 'F') ||
            (form.id in seen) !is null ||
            supplied.forms[i].id != form.id ||
            supplied.forms[i].grammaticalFeatures != form.grammaticalFeatures)
            return false;
        seen[form.id] = true;
        foreach (qid; form.grammaticalFeatures)
            if (!isId(qid, 'Q')) return false;
    }
    foreach (i, sense; canonical.senses)
    {
        if (!isOwnedSubId(sense.id, canonical.id, 'S') ||
            (sense.id in seen) !is null ||
            supplied.senses[i].id != sense.id)
            return false;
        seen[sense.id] = true;
    }
    return true;
}

/**
 * Confirm only whether the literal Q-ID is present in the specified original
 * Form's grammaticalFeatures list. A D1 classification/review supplies
 * interpretations, not permission to use the Form grammatically.
 *
 * A missing Form/feature is UNKNOWN, not evidence of absence or contradiction.
 * Quarantined ontology roles cannot become a positive grammatical binding.
 */
FormAttestation bindAttestedFormFeature(
    WikidataLexeme lexeme,
    in FeatureClassification classified,
    in FacetAssessment review,
    FormAttestationRequest request)
{
    FormAttestation outResult;
    outResult.status = FormAttestationStatus.invalidInput;
    outResult.lexemeId = request.lexemeId;
    outResult.languageId = request.languageId;
    outResult.lexicalCategoryId = request.lexicalCategoryId;
    outResult.formId = request.formId;
    outResult.featureQId = request.featureQId;
    outResult.lexemeSnapshotSha256 = request.lexemeSnapshotSha256;
    outResult.itemGraphSnapshotSha256 = request.itemGraphSnapshotSha256;
    outResult.classification = classified.kind;
    outResult.semanticReview = review.kind;

    if (!isId(request.lexemeId, 'L') ||
        !isId(request.languageId, 'Q') ||
        !isId(request.lexicalCategoryId, 'Q') ||
        !isOwnedSubId(request.formId, request.lexemeId, 'F') ||
        !isId(request.featureQId, 'Q') ||
        !isSha256(request.lexemeSnapshotSha256) ||
        !isSha256(request.itemGraphSnapshotSha256) ||
        classified.featureQId != request.featureQId ||
        review.featureQId != request.featureQId ||
        review.candidateCount != classified.candidates.length ||
        review.kind == FacetAssessmentKind.invalidReview ||
        (classified.kind == ClassificationKind.unclassified &&
            classified.candidates.length != 0) ||
        (classified.kind == ClassificationKind.candidate &&
            classified.candidates.length != 1) ||
        (classified.kind == ClassificationKind.multipleCandidates &&
            classified.candidates.length < 2) ||
        (classified.kind == ClassificationKind.multipleCandidates &&
            review.kind != FacetAssessmentKind.ambiguityPreserved &&
            review.kind != FacetAssessmentKind.quarantined))
        return outResult;

    WikidataLexeme original;
    if (!canonicalize(lexeme, original) ||
        original.id != request.lexemeId ||
        original.languageId != request.languageId ||
        original.lexicalCategoryId != request.lexicalCategoryId)
        return outResult;

    // Copy the ORIGINAL dimension-witness IDs as independent provenance.
    // Their authenticity belongs to the externally audited Q-item graph;
    // they are NEVER claimed to be Wikibase Form statements.
    foreach (candidate; classified.candidates)
        foreach (witness; candidate.witnesses)
            foreach (statement; witness.statementIds)
            {
                bool alreadySeen;
                foreach (old; outResult.dimensionWitnessStatementIds)
                    if (old == statement) alreadySeen = true;
                if (!alreadySeen)
                    outResult.dimensionWitnessStatementIds ~= statement;
            }

    outResult.status = FormAttestationStatus.unknown;
    foreach (form; original.forms)
    {
        if (form.id != request.formId) continue;
        foreach (feature; form.grammaticalFeatures)
        {
            if (feature != request.featureQId) continue;
            outResult.featurePresentInOriginal = true;
            outResult.originalEvidencePath =
                "forms[id=" ~ request.formId ~ "].grammaticalFeatures";
            outResult.status = review.kind == FacetAssessmentKind.quarantined ?
                FormAttestationStatus.quarantined :
                FormAttestationStatus.attestedFeatureOnly;
            return outResult;
        }
        return outResult; // Form exists, feature not listed: still unknown.
    }
    return outResult; // No original Form with this identity: still unknown.
}

/** Sense membership is Lexeme identity evidence ONLY. It cannot be joined
 *  to a particular Form without a separate, original, explicit relationship.
 */
SenseMembership bindAttestedSenseMembership(
    WikidataLexeme lexeme, SenseMembershipRequest request)
{
    SenseMembership outResult;
    outResult.status = SenseMembershipStatus.invalidInput;
    outResult.lexemeId = request.lexemeId;
    outResult.languageId = request.languageId;
    outResult.senseId = request.senseId;
    outResult.lexemeSnapshotSha256 = request.lexemeSnapshotSha256;

    if (!isId(request.lexemeId, 'L') ||
        !isId(request.languageId, 'Q') ||
        !isOwnedSubId(request.senseId, request.lexemeId, 'S') ||
        !isSha256(request.lexemeSnapshotSha256))
        return outResult;

    WikidataLexeme original;
    if (!canonicalize(lexeme, original) ||
        original.id != request.lexemeId ||
        original.languageId != request.languageId)
        return outResult;

    outResult.status = SenseMembershipStatus.unknown;
    foreach (sense; original.senses)
        if (sense.id == request.senseId)
        {
            outResult.status = SenseMembershipStatus.attestedMembershipOnly;
            outResult.originalEvidencePath =
                "senses[id=" ~ request.senseId ~ "]";
            return outResult;
        }
    return outResult;
}

unittest
{
    import wikidata.grammar_facet : assessFacet;
    enum digest = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    // Synthetic research fixture, NOT an original Wikidata snapshot.
    auto lexeme = parseLexeme(`{
        "id":"L12","language":"Q652","lexicalCategory":"Q1084",
        "forms":[
          {"id":"L12-F1","representations":{"it":{"value":"x"}},
           "grammaticalFeatures":["Q101"]},
          {"id":"L12-F2","representations":{"it":{"value":"x"}},
           "grammaticalFeatures":["Q102"]}
        ],"senses":[{"id":"L12-S1","glosses":{"de":{"value":"X"}}}]
    }`);
    FeatureClassification c;
    c.featureQId = "Q101";
    c.kind = ClassificationKind.unclassified;
    auto facet = assessFacet(c, null, digest);
    FormAttestationRequest req;
    req.lexemeId = "L12";
    req.languageId = "Q652";
    req.lexicalCategoryId = "Q1084";
    req.formId = "L12-F1";
    req.featureQId = "Q101";
    req.lexemeSnapshotSha256 = digest;
    req.itemGraphSnapshotSha256 = digest;

    auto hit = bindAttestedFormFeature(lexeme, c, facet, req);
    assert(hit.status == FormAttestationStatus.attestedFeatureOnly);
    assert(hit.featurePresentInOriginal);
    assert(hit.originalEvidencePath ==
        "forms[id=L12-F1].grammaticalFeatures");
    assert(!hit.permitsGrammarProduction && !hit.permitsFormSelection);
    assert(!hit.permitsFormSenseAssociation);
    assert(hit.classification == ClassificationKind.unclassified);

    // Same spelling, different original Form ID: never coalesce.
    req.formId = "L12-F2";
    auto other = bindAttestedFormFeature(lexeme, c, facet, req);
    assert(other.status == FormAttestationStatus.unknown);
    assert(!other.featurePresentInOriginal);

    req.formId = "L12-F3";
    assert(bindAttestedFormFeature(lexeme, c, facet, req).status ==
        FormAttestationStatus.unknown);
    req.formId = "L99-F1";
    assert(bindAttestedFormFeature(lexeme, c, facet, req).status ==
        FormAttestationStatus.invalidInput);
    req.formId = "L12-F1";

    // Classification and review cannot be silently rebound to a new Q-ID.
    req.featureQId = "Q102";
    assert(bindAttestedFormFeature(lexeme, c, facet, req).status ==
        FormAttestationStatus.invalidInput);
    req.featureQId = "Q101";
    req.lexemeSnapshotSha256 = "unverified";
    assert(bindAttestedFormFeature(lexeme, c, facet, req).status ==
        FormAttestationStatus.invalidInput);
    req.lexemeSnapshotSha256 = digest;

    facet.kind = FacetAssessmentKind.quarantined;
    auto blocked = bindAttestedFormFeature(lexeme, c, facet, req);
    assert(blocked.status == FormAttestationStatus.quarantined);
    assert(blocked.featurePresentInOriginal);
    facet.kind = FacetAssessmentKind.invalidReview;
    assert(bindAttestedFormFeature(lexeme, c, facet, req).status ==
        FormAttestationStatus.invalidInput);

    // The canonical raw snapshot outranks a forged derived Form record.
    facet = assessFacet(c, null, digest);
    auto altered = lexeme;
    altered.forms = lexeme.forms.dup;
    altered.forms[0].grammaticalFeatures = ["Q102"];
    assert(bindAttestedFormFeature(altered, c, facet, req).status ==
        FormAttestationStatus.invalidInput);

    SenseMembershipRequest sr;
    sr.lexemeId = "L12";
    sr.languageId = "Q652";
    sr.senseId = "L12-S1";
    sr.lexemeSnapshotSha256 = digest;
    auto sense = bindAttestedSenseMembership(lexeme, sr);
    assert(sense.status == SenseMembershipStatus.attestedMembershipOnly);
    assert(sense.originalEvidencePath == "senses[id=L12-S1]");
    assert(!sense.permitsFormSenseAssociation);
    sr.senseId = "L12-S2";
    assert(bindAttestedSenseMembership(lexeme, sr).status ==
        SenseMembershipStatus.unknown);
    sr.senseId = "L99-S1";
    assert(bindAttestedSenseMembership(lexeme, sr).status ==
        SenseMembershipStatus.invalidInput);
    sr.senseId = "L12-S1";
    sr.languageId = "Q188";
    assert(bindAttestedSenseMembership(lexeme, sr).status ==
        SenseMembershipStatus.invalidInput);
}

unittest
{
    import wikidata.grammar_facet : assessFacet;
    enum digest = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    auto raw = parseLexeme(`{
        "id":"L23","language":"Q652","lexicalCategory":"Q1084",
        "forms":[{"id":"L23-F1","grammaticalFeatures":["Q101"]}],
        "senses":[{"id":"L23-S1"}]
    }`);
    FeatureClassification c;
    c.featureQId = "Q101";
    c.kind = ClassificationKind.unclassified;
    auto facet = assessFacet(c, null, digest);
    FormAttestationRequest req;
    req.lexemeId = "L23";
    req.languageId = "Q652";
    req.lexicalCategoryId = "Q1084";
    req.formId = "L23-F1";
    req.featureQId = "Q101";
    req.lexemeSnapshotSha256 = digest;
    req.itemGraphSnapshotSha256 = digest;
    assert(bindAttestedFormFeature(raw, c, facet, req).status ==
        FormAttestationStatus.attestedFeatureOnly);

    // Same sub-ID twice means the original identity is unusable.
    auto duplicate = parseLexeme(`{
        "id":"L23","language":"Q652","lexicalCategory":"Q1084",
        "forms":[{"id":"L23-F1","grammaticalFeatures":["Q101"]},
                 {"id":"L23-F1","grammaticalFeatures":["Q101"]}],
        "senses":[]
    }`);
    assert(bindAttestedFormFeature(duplicate, c, facet, req).status ==
        FormAttestationStatus.invalidInput);
    auto badFeature = parseLexeme(`{
        "id":"L23","language":"Q652","lexicalCategory":"Q1084",
        "forms":[{"id":"L23-F1","grammaticalFeatures":["not-Q"]}],
        "senses":[]
    }`);
    assert(bindAttestedFormFeature(badFeature, c, facet, req).status ==
        FormAttestationStatus.invalidInput);
}

unittest
{
    import wikidata.grammar_facet : assessFacet;
    import wikidata.grammar_dimension :
        DimensionCandidate, ClassificationWitness, FeatureFacet;
    enum digest = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";
    auto lexeme = parseLexeme(`{
        "id":"L77","language":"Q188","lexicalCategory":"Q24905",
        "forms":[{"id":"L77-F1","grammaticalFeatures":["Q10"]}],
        "senses":[{"id":"L77-S1"}]
    }`);
    FeatureClassification c;
    c.featureQId = "Q10";
    c.kind = ClassificationKind.candidate;
    ClassificationWitness w;
    w.statementIds = ["Q10$synthetic-witness"];
    DimensionCandidate candidate;
    candidate.dimensionId = "synthetic-number";
    candidate.facet = FeatureFacet.inflection;
    candidate.witnesses = [w];
    c.candidates = [candidate];
    auto facet = assessFacet(c, null, digest);
    FormAttestationRequest req;
    req.lexemeId = "L77";
    req.languageId = "Q188";
    req.lexicalCategoryId = "Q24905";
    req.formId = "L77-F1";
    req.featureQId = "Q10";
    req.lexemeSnapshotSha256 = digest;
    req.itemGraphSnapshotSha256 = digest;
    auto a = bindAttestedFormFeature(lexeme, c, facet, req);
    assert(a.status == FormAttestationStatus.attestedFeatureOnly);
    assert(a.dimensionWitnessStatementIds == ["Q10$synthetic-witness"]);
    assert(a.semanticReview == FacetAssessmentKind.candidateOnly);
    assert(!a.permitsFormSelection);

    // A second competing interpretation stays ambiguous, although the
    // Q-feature is indeed present in the ORIGINAL Form feature list.
    DimensionCandidate other = candidate;
    other.dimensionId = "synthetic-tense";
    c.candidates ~= other;
    c.kind = ClassificationKind.multipleCandidates;
    facet = assessFacet(c, null, digest);
    assert(facet.kind == FacetAssessmentKind.ambiguityPreserved);
    auto ambiguous = bindAttestedFormFeature(lexeme, c, facet, req);
    assert(ambiguous.status == FormAttestationStatus.attestedFeatureOnly);
    assert(ambiguous.semanticReview == FacetAssessmentKind.ambiguityPreserved);
    assert(ambiguous.dimensionWitnessStatementIds.length == 1);
    assert(!ambiguous.permitsFormSelection);

    facet.kind = FacetAssessmentKind.facetApprovedNotGrammarUse;
    assert(bindAttestedFormFeature(lexeme, c, facet, req).status ==
        FormAttestationStatus.invalidInput);
}
