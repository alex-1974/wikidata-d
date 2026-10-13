/**
 * R1.11-D1: semantic review of R1.11-B candidate evidence.
 *
 * This module intentionally has NO rule executor, synthesizer, language-specific
 * morphology, or binding authority. A reviewed feature facet is not permission
 * to produce, select, combine, or alter a Wikidata Form.
 *
 * Provenance is compared against R1.11-B witnesses. Graph snapshot hashes are
 * supplied by the caller's verified input manifest (not fabricated by a label).
 */
module wikidata.grammar_facet;

import wikidata.grammar_dimension : FeatureClassification, FeatureFacet,
    ClassificationKind;

/// Semantic interpretations are distinct from R1.11-B's coarse feature facets.
enum SemanticRole : ubyte
{
    unresolved,
    grammaticalDimension,
    grammaticalValue,
    lexicalCategory,
    inflectionFormType,
    morphologicalConcept,
    representationKind,
    usageOrRegister,
    mixedOrAmbiguous
}

/// Approval of a FACET, if it ever occurs, is not approval of an operator.
enum FacetReviewDisposition : ubyte
{
    hypothesis,
    reviewedEvidenceOnly,
    approvedFacet,
    deferred,
    rejected,
    quarantined
}

/// Decision for metadata review only: none authorizes grammar production.
enum FacetAssessmentKind : ubyte
{
    unknown,
    candidateOnly,
    semanticHypothesisOnly,
    reviewedEvidenceOnly,
    facetApprovedNotGrammarUse,
    ambiguityPreserved,
    quarantined,
    invalidReview
}

/** A manual/curated record for ONE particular R1.11-B dimension candidate.
 *  Empty dimensionId denotes a role hypothesis not proven by that classifier.
 */
struct FacetReview
{
    string reviewId;
    string featureQId;
    string dimensionId;
    FeatureFacet classifierFacet;
    SemanticRole semanticRole;
    FacetReviewDisposition disposition;
    string[] witnessedStatementIds;
    string graphSnapshotSha256;
    string reviewSource;
}

struct FacetAssessment
{
    string featureQId;
    FacetAssessmentKind kind;
    SemanticRole[] roleHypotheses;
    size_t candidateCount;
    size_t matchingReviews;

    /// Even facetApprovedNotGrammarUse is not a lexical use authorization.
    @property bool permitsGrammarProduction() const { return false; }
    @property bool permitsFormSelection() const { return false; }
}

private bool isLowercaseSha256(string hash)
{
    if (hash.length != 64) return false;
    foreach (digit; hash)
        if (!((digit >= '0' && digit <= '9') ||
              (digit >= 'a' && digit <= 'f'))) return false;
    return true;
}

private bool hasStatement(const ref FeatureClassification classified,
    string dimensionId, FeatureFacet facet, string statementId)
{
    foreach (candidate; classified.candidates)
    {
        if (candidate.dimensionId != dimensionId || candidate.facet != facet)
            continue;
        foreach (witness; candidate.witnesses)
            foreach (sourceStatement; witness.statementIds)
                if (sourceStatement == statementId)
                    return true;
    }
    return false;
}

/**
 * Evidence/semantic boundary with fail-closed review validation.
 *
 * Non-grammatical role hints can be retained even when R1.11-B is unclassified;
 * they remain hypotheses requiring a separate provenance/role validation.
 * An ambiguous R1.11-B result can never become unique by review precedence.
 */
FacetAssessment assessFacet(in FeatureClassification classified,
    in FacetReview[] reviews, string verifiedGraphSha256)
{
    FacetAssessment result;
    result.featureQId = classified.featureQId;
    result.candidateCount = classified.candidates.length;
    // The caller cannot manufacture a status/candidate count disagreement.
    if ((classified.kind == ClassificationKind.unclassified &&
         classified.candidates.length != 0) ||
        (classified.kind == ClassificationKind.candidate &&
         classified.candidates.length != 1) ||
        (classified.kind == ClassificationKind.multipleCandidates &&
         classified.candidates.length < 2))
    {
        result.kind = FacetAssessmentKind.invalidReview;
        return result;
    }
    result.kind = classified.candidates.length > 0 ?
        FacetAssessmentKind.candidateOnly : FacetAssessmentKind.unknown;

    bool hasReviewedEvidence;
    bool hasApprovedFacet;
    bool hasRoleHints;
    bool hasQuarantine;

    foreach (i, review; reviews)
    {
        if (review.featureQId != classified.featureQId)
            continue;
        ++result.matchingReviews;
        // A revision must be bound to the exact audited Q-graph snapshot.
        if (!isLowercaseSha256(review.graphSnapshotSha256) ||
            !isLowercaseSha256(verifiedGraphSha256) ||
            review.graphSnapshotSha256 != verifiedGraphSha256 ||
            review.reviewId.length == 0 || review.reviewSource.length == 0)
        {
            result.kind = FacetAssessmentKind.invalidReview;
            return result;
        }
        // For one classified (dimensionId, facet) candidate, a second
        // semantic review is a conflict, even if it assigns a different
        // role or disposition. Otherwise two contradictory approvals could
        // silently appear as one approved facet. Unclassified role hints
        // may still retain several DIFFERENT hypotheses.
        foreach (previous; reviews[0 .. i])
            if (previous.featureQId == review.featureQId &&
                previous.dimensionId == review.dimensionId &&
                previous.classifierFacet == review.classifierFacet &&
                (review.dimensionId.length != 0 ||
                 previous.semanticRole == review.semanticRole))
            {
                result.kind = FacetAssessmentKind.invalidReview;
                return result;
            }
        result.roleHypotheses ~= review.semanticRole;
        if (review.disposition == FacetReviewDisposition.quarantined ||
            review.disposition == FacetReviewDisposition.rejected)
        {
            hasQuarantine = true;
            continue;
        }
        if (review.dimensionId.length == 0)
        {
            // A role hypothesis without a R1.11-B dimension candidate cannot
            // be given facet approval by this evidence-only interpreter.
            if (review.disposition == FacetReviewDisposition.approvedFacet ||
                review.disposition == FacetReviewDisposition.reviewedEvidenceOnly)
            {
                result.kind = FacetAssessmentKind.invalidReview;
                return result;
            }
            hasRoleHints = true;
            continue;
        }
        if (review.witnessedStatementIds.length == 0)
        {
            result.kind = FacetAssessmentKind.invalidReview;
            return result;
        }
        foreach (statement; review.witnessedStatementIds)
        {
            if (!hasStatement(classified, review.dimensionId,
                review.classifierFacet, statement))
            {
                result.kind = FacetAssessmentKind.invalidReview;
                return result;
            }
        }
        if (review.disposition == FacetReviewDisposition.approvedFacet)
            hasApprovedFacet = true;
        if (review.disposition == FacetReviewDisposition.reviewedEvidenceOnly)
            hasReviewedEvidence = true;
    }

    // Quarantines and multiple candidates cannot be overridden by ordering.
    if (hasQuarantine)
        result.kind = FacetAssessmentKind.quarantined;
    else if (classified.kind == ClassificationKind.multipleCandidates ||
        classified.candidates.length > 1)
        result.kind = FacetAssessmentKind.ambiguityPreserved;
    else if (hasApprovedFacet)
        result.kind = FacetAssessmentKind.facetApprovedNotGrammarUse;
    else if (hasReviewedEvidence)
        result.kind = FacetAssessmentKind.reviewedEvidenceOnly;
    else if (hasRoleHints)
        result.kind = FacetAssessmentKind.semanticHypothesisOnly;
    return result;
}

unittest
{
    import wikidata.grammar_dimension : DimensionCandidate, ClassificationWitness;

    enum hash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    FeatureClassification c;
    c.featureQId = "Q131105";
    c.kind = ClassificationKind.candidate;
    ClassificationWitness w;
    w.statementIds = ["Q131105$real-statement-id"];
    w.nodes = ["Q131105", "Q128234"];
    w.properties = ["P31"];
    DimensionCandidate d;
    d.dimensionId = "case";
    d.facet = FeatureFacet.inflection;
    d.witnesses = [w];
    c.candidates = [d];

    auto baseline = assessFacet(c, null, hash);
    assert(baseline.kind == FacetAssessmentKind.candidateOnly);
    assert(!baseline.permitsFormSelection);

    FacetReview r;
    r.reviewId = "R-review-1";
    r.featureQId = "Q131105";
    r.dimensionId = "case";
    r.classifierFacet = FeatureFacet.inflection;
    r.semanticRole = SemanticRole.grammaticalValue;
    r.disposition = FacetReviewDisposition.reviewedEvidenceOnly;
    r.witnessedStatementIds = ["Q131105$real-statement-id"];
    r.graphSnapshotSha256 = hash;
    r.reviewSource = "independent ontology review";

    auto reviewed = assessFacet(c, [r], hash);
    assert(reviewed.kind == FacetAssessmentKind.reviewedEvidenceOnly);
    assert(!reviewed.permitsGrammarProduction);

    r.disposition = FacetReviewDisposition.approvedFacet;
    auto approved = assessFacet(c, [r], hash);
    assert(approved.kind == FacetAssessmentKind.facetApprovedNotGrammarUse);
    assert(!approved.permitsFormSelection);

    r.graphSnapshotSha256 = "wrong-hash";
    assert(assessFacet(c, [r], hash).kind == FacetAssessmentKind.invalidReview);
    r.graphSnapshotSha256 = hash;
    r.witnessedStatementIds = ["Q131105$invented"];
    assert(assessFacet(c, [r], hash).kind == FacetAssessmentKind.invalidReview);
    r.witnessedStatementIds = ["Q131105$real-statement-id"];
    assert(assessFacet(c, [r, r], hash).kind == FacetAssessmentKind.invalidReview);

    // Distinct semantic roles cannot both review the same classified facet.
    // Before the hardening check, this would have returned
    // facetApprovedNotGrammarUse despite the contradictory role review.
    FacetReview conflicting = r;
    conflicting.reviewId = "R-review-conflicting-role";
    conflicting.semanticRole = SemanticRole.representationKind;
    assert(assessFacet(c, [r, conflicting], hash).kind ==
        FacetAssessmentKind.invalidReview);
    conflicting.semanticRole = r.semanticRole;
    conflicting.disposition = FacetReviewDisposition.rejected;
    assert(assessFacet(c, [r, conflicting], hash).kind ==
        FacetAssessmentKind.invalidReview);

    // Do not allow an unrelated dimension to borrow a valid statement ID.
    conflicting = r;
    conflicting.dimensionId = "gender";
    assert(assessFacet(c, [conflicting], hash).kind ==
        FacetAssessmentKind.invalidReview);

    // Evidence for two dimensions must stay ambiguous even with an approval.
    c.kind = ClassificationKind.multipleCandidates;
    DimensionCandidate second = d;
    second.dimensionId = "mood";
    c.candidates ~= second;
    assert(assessFacet(c, [r], hash).kind == FacetAssessmentKind.ambiguityPreserved);

    c.kind = ClassificationKind.unclassified;
    c.candidates = null;
    r.dimensionId = "";
    r.disposition = FacetReviewDisposition.hypothesis;
    r.witnessedStatementIds = null;
    r.semanticRole = SemanticRole.representationKind;
    assert(assessFacet(c, [r], hash).kind == FacetAssessmentKind.semanticHypothesisOnly);
    r.disposition = FacetReviewDisposition.approvedFacet;
    assert(assessFacet(c, [r], hash).kind == FacetAssessmentKind.invalidReview);
    r.disposition = FacetReviewDisposition.quarantined;
    assert(assessFacet(c, [r], hash).kind == FacetAssessmentKind.quarantined);
}
