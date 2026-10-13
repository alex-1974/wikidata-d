// R1.11-D3-D2 synthetic only: NOT original Wikidata responses.
module wikidata.grammar_evidence_composition_test;
import wikidata.grammar_evidence_composition;
import wikidata.grammar_attestation : FormAttestation, FormAttestationStatus, SenseMembership, SenseMembershipStatus;
import wikidata.grammar_statement_witness : SourceSnapshotRef, UsageExampleWitness, ComponentWitness, SemanticArgumentWitness;

private enum string fakeL7 = "{\"entities\":{\"L7\":{\"id\":\"L7\",\"language\":\"Q1860\",\"lexicalCategory\":\"Q1084\",\"lastrevid\":42,\"forms\":[{\"id\":\"L7-F4\",\"grammaticalFeatures\":[\"Q110786\"]},{\"id\":\"L7-F5\",\"grammaticalFeatures\":[]}],\"senses\":[{\"id\":\"L7-S1\",\"claims\":{}},{\"id\":\"L7-S2\",\"claims\":{}}],\"claims\":{\"P5831\":[{\"id\":\"L7$one\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P5831\",\"datavalue\":{\"type\":\"monolingualtext\",\"value\":{\"text\":\"cat singular\",\"language\":\"en\"}}},\"qualifiers\":{\"P5830\":[{\"snaktype\":\"value\",\"property\":\"P5830\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L7-F4\"}}}],\"P6072\":[{\"snaktype\":\"value\",\"property\":\"P6072\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L7-S1\"}}}]},\"references\":[{\"hash\":\"evidence-preserved\"}]},{\"id\":\"L7$two\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P5831\",\"datavalue\":{\"type\":\"monolingualtext\",\"value\":{\"text\":\"cats plural\",\"language\":\"en\"}}},\"qualifiers\":{\"P5830\":[{\"snaktype\":\"value\",\"property\":\"P5830\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L7-F5\"}}}],\"P6072\":[{\"snaktype\":\"value\",\"property\":\"P6072\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L7-S1\"}}}]},\"references\":[{\"hash\":\"evidence-preserved\"}]},{\"id\":\"L7$three\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P5831\",\"datavalue\":{\"type\":\"monolingualtext\",\"value\":{\"text\":\"cat other sense\",\"language\":\"en\"}}},\"qualifiers\":{\"P5830\":[{\"snaktype\":\"value\",\"property\":\"P5830\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L7-F4\"}}}],\"P6072\":[{\"snaktype\":\"value\",\"property\":\"P6072\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L7-S2\"}}}]},\"references\":[{\"hash\":\"evidence-preserved\"}]},{\"id\":\"L7$four\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P5831\",\"datavalue\":{\"type\":\"monolingualtext\",\"value\":{\"text\":\"cats other sense\",\"language\":\"en\"}}},\"qualifiers\":{\"P5830\":[{\"snaktype\":\"value\",\"property\":\"P5830\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L7-F5\"}}}],\"P6072\":[{\"snaktype\":\"value\",\"property\":\"P6072\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L7-S2\"}}}]},\"references\":[{\"hash\":\"evidence-preserved\"}]}]}}}}";
private enum string fakeL6888 = "{\"entities\":{\"L6888\":{\"id\":\"L6888\",\"language\":\"Q1860\",\"lexicalCategory\":\"Q1084\",\"lastrevid\":22,\"forms\":[{\"id\":\"L6888-F3\",\"grammaticalFeatures\":[]},{\"id\":\"L6888-F15\",\"grammaticalFeatures\":[]}],\"senses\":[{\"id\":\"L6888-S1\",\"claims\":{}}],\"claims\":{\"P5831\":[{\"id\":\"L6888$one\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P5831\",\"datavalue\":{\"type\":\"monolingualtext\",\"value\":{\"text\":\"example 1\",\"language\":\"fi\"}}},\"qualifiers\":{\"P5830\":[{\"snaktype\":\"value\",\"property\":\"P5830\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L6888-F3\"}}}],\"P6072\":[{\"snaktype\":\"value\",\"property\":\"P6072\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L6888-S1\"}}}]},\"references\":[{\"hash\":\"evidence-preserved\"}]},{\"id\":\"L6888$two\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P5831\",\"datavalue\":{\"type\":\"monolingualtext\",\"value\":{\"text\":\"example 2\",\"language\":\"fi\"}}},\"qualifiers\":{\"P5830\":[{\"snaktype\":\"value\",\"property\":\"P5830\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L6888-F15\"}}}],\"P6072\":[{\"snaktype\":\"value\",\"property\":\"P6072\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L6888-S1\"}}}]},\"references\":[{\"hash\":\"evidence-preserved\"}]}]}}}}";
private enum string fakeL252527 = "{\"entities\":{\"L252527\":{\"id\":\"L252527\",\"language\":\"Q1860\",\"lexicalCategory\":\"Q1084\",\"lastrevid\":65,\"forms\":[{\"id\":\"L252527-F1\",\"grammaticalFeatures\":[]}],\"senses\":[{\"id\":\"L252527-S1\",\"claims\":{}}],\"claims\":{\"P5238\":[{\"id\":\"L252527$part1\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P5238\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L40399\"}}},\"qualifiers\":{},\"references\":[{\"hash\":\"evidence-preserved\"}]},{\"id\":\"L252527$part2\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P5238\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L7119\"}}},\"qualifiers\":{},\"references\":[{\"hash\":\"evidence-preserved\"}]}]}}}}";
private enum string fakeL1340 = "{\"entities\":{\"L1340\":{\"id\":\"L1340\",\"language\":\"Q1860\",\"lexicalCategory\":\"Q1084\",\"lastrevid\":54,\"forms\":[{\"id\":\"L1340-F1\",\"grammaticalFeatures\":[]}],\"senses\":[{\"id\":\"L1340-S1\",\"claims\":{\"P9971\":[{\"id\":\"L1340-S1$arg1\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P9971\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"Q20984678\"}}},\"qualifiers\":{\"P3831\":[{\"snaktype\":\"value\",\"property\":\"P3831\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"Q164573\"}}}]},\"references\":[{\"hash\":\"evidence-preserved\"}]},{\"id\":\"L1340-S1$arg2\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P9971\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"Q6460735\"}}},\"qualifiers\":{\"P3831\":[{\"snaktype\":\"value\",\"property\":\"P3831\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"Q116380013\"}}}]},\"references\":[{\"hash\":\"evidence-preserved\"}]},{\"id\":\"L1340-S1$arg3\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P9971\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"Q140430716\"}}},\"qualifiers\":{\"P3831\":[{\"snaktype\":\"value\",\"property\":\"P3831\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"Q2990574\"}}}]},\"references\":[{\"hash\":\"evidence-preserved\"}]}]}}],\"claims\":{\"P5831\":[{\"id\":\"L1340$form-only\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P5831\",\"datavalue\":{\"type\":\"monolingualtext\",\"value\":{\"text\":\"form\",\"language\":\"en\"}}},\"qualifiers\":{\"P5830\":[{\"snaktype\":\"value\",\"property\":\"P5830\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L1340-F1\"}}}]},\"references\":[{\"hash\":\"evidence-preserved\"}]},{\"id\":\"L1340$sense-only\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P5831\",\"datavalue\":{\"type\":\"monolingualtext\",\"value\":{\"text\":\"sense\",\"language\":\"en\"}}},\"qualifiers\":{\"P6072\":[{\"snaktype\":\"value\",\"property\":\"P6072\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L1340-S1\"}}}]},\"references\":[{\"hash\":\"evidence-preserved\"}]}]}}}}";
private enum string fakeL40399 = "{\"entities\":{\"L40399\":{\"id\":\"L40399\",\"language\":\"Q1860\",\"lexicalCategory\":\"Q1084\",\"lastrevid\":99,\"forms\":[{\"id\":\"L40399-F1\",\"grammaticalFeatures\":[]}],\"senses\":[{\"id\":\"L40399-S1\",\"claims\":{}}],\"claims\":{}}}}";
private enum string fakeL12 = "{\"entities\":{\"L12\":{\"id\":\"L12\",\"language\":\"Q1860\",\"lexicalCategory\":\"Q1084\",\"lastrevid\":12,\"forms\":[{\"id\":\"L12-F1\",\"grammaticalFeatures\":[]}],\"senses\":[{\"id\":\"L12-S1\",\"claims\":{\"P9971\":[{\"id\":\"L12-S1$argument\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P9971\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"Q20984678\"}}},\"qualifiers\":{\"P3831\":[{\"snaktype\":\"value\",\"property\":\"P3831\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"Q164573\"}}}]},\"references\":[{\"hash\":\"evidence-preserved\"}]}]}}],\"claims\":{\"P5831\":[{\"id\":\"L12$example-a\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P5831\",\"datavalue\":{\"type\":\"monolingualtext\",\"value\":{\"text\":\"first\",\"language\":\"en\"}}},\"qualifiers\":{\"P5830\":[{\"snaktype\":\"value\",\"property\":\"P5830\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L12-F1\"}}}],\"P6072\":[{\"snaktype\":\"value\",\"property\":\"P6072\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L12-S1\"}}}]},\"references\":[{\"hash\":\"evidence-preserved\"}]},{\"id\":\"L12$example-b\",\"rank\":\"normal\",\"mainsnak\":{\"snaktype\":\"value\",\"property\":\"P5831\",\"datavalue\":{\"type\":\"monolingualtext\",\"value\":{\"text\":\"second\",\"language\":\"en\"}}},\"qualifiers\":{\"P5830\":[{\"snaktype\":\"value\",\"property\":\"P5830\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L12-F1\"}}}],\"P6072\":[{\"snaktype\":\"value\",\"property\":\"P6072\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"id\":\"L12-S1\"}}}]},\"references\":[{\"hash\":\"evidence-preserved\"}]}]}}}}";

private SourceSnapshotRef request(string qid, ulong revision, string raw)
{
    // The hash is computed from the actual bytes of this synthetic fixture.
    return SourceSnapshotRef(qid, revision, byteHashTest(raw),
        "https://www.wikidata.org/wiki/Special:EntityData/" ~ qid ~ ".json");
}
private string byteHashTest(string raw)
{
    import std.digest.sha : sha256Of;
    import std.digest : toHexString;
    auto hex = toHexString(sha256Of(cast(const(ubyte)[]) raw));
    string hash;
    foreach (c; hex)
        hash ~= (c >= 'A' && c <= 'F') ? cast(char)(c + 32) : c;
    return hash;
}

unittest
{
    auto s = request("L7", 42, fakeL7);
    auto r = verifyOriginalLexemeBytes(fakeL7, s);
    assert(r.valid && r.usageCount == 4 && r.observationCount == 4);
    UsageExampleWitness a, b, c, d;
    assert(receiptUsage(r, 0, a) && receiptUsage(r, 1, b));
    assert(receiptUsage(r, 2, c) && receiptUsage(r, 3, d));
    // An out argument is reset on entry, even when the lookup fails.
    // Do not erase the valid fourth witness before comparing a with d.
    UsageExampleWitness missing;
    assert(!receiptUsage(r, 4, missing));
    auto ab = composeUsages(r, a, r, b);
    assert(ab.status == CompositionStatus.sameSenseOnly);
    auto ac = composeUsages(r, a, r, c);
    assert(ac.status == CompositionStatus.sameFormOnly);
    auto ad = composeUsages(r, a, r, d);
    assert(ad.status == CompositionStatus.parallelEvidence);
    auto aa = composeUsages(r, a, r, a);
    assert(aa.status == CompositionStatus.sameOriginalStatement);
    assert(ab.originalStatements.length == 2 && ab.originalStatements[0].statementId == "L7$one");
    assert(!ab.permitsGrammarProduction && !ab.permitsFormSelection &&
        !ab.permitsGeneralFormSenseAssociation);

    auto changed = a;
    changed.formId = "L7-F5";
    assert(composeUsages(r, changed, r, b).status == CompositionStatus.integrityConflict);
    changed = a;
    changed.source.statementId = "L7$fake";
    assert(composeUsages(r, changed, r, b).status == CompositionStatus.integrityConflict);
    changed = a;
    changed.source.originalStatement = b.source.originalStatement;
    assert(composeUsages(r, changed, r, b).status == CompositionStatus.integrityConflict);

    auto wrongHash = request("L7", 42, fakeL7);
    wrongHash.rawResponseSha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    assert(!verifyOriginalLexemeBytes(fakeL7, wrongHash).valid);
    auto wrongRevision = request("L7", 43, fakeL7);
    assert(!verifyOriginalLexemeBytes(fakeL7, wrongRevision).valid);
    auto wrongLexeme = request("L9", 42, fakeL7);
    assert(!verifyOriginalLexemeBytes(fakeL7, wrongLexeme).valid);
    assert(!verifyOriginalLexemeBytes(fakeL7 ~ " ", s).valid);

    // Same Lexeme but changed response bytes: not the same source snapshot.
    auto otherRaw = fakeL7 ~ " ";
    auto otherReceipt = verifyOriginalLexemeBytes(otherRaw,
        request("L7", 42, otherRaw));
    assert(otherReceipt.valid);
    UsageExampleWitness other;
    assert(receiptUsage(otherReceipt, 0, other));
    assert(composeUsages(r, a, otherReceipt, other).status == CompositionStatus.notSameSnapshot);

    FormAttestation form;
    form.status = FormAttestationStatus.attestedFeatureOnly;
    form.lexemeId = "L7";
    form.lexemeSnapshotSha256 = s.rawResponseSha256;
    form.formId = "L7-F4";
    form.featureQId = "Q110786";
    form.featurePresentInOriginal = true;
    assert(composeUsageForm(r, a, form).status == CompositionStatus.coIndexedSameForm);
    assert(composeUsageForm(r, b, form).status == CompositionStatus.noIdentityMatch);
    form.lexemeSnapshotSha256 = wrongHash.rawResponseSha256;
    assert(composeUsageForm(r, a, form).status == CompositionStatus.noIdentityMatch);
    form.lexemeSnapshotSha256 = s.rawResponseSha256;
    form.featureQId = "Q999999";
    assert(composeUsageForm(r, a, form).status == CompositionStatus.noIdentityMatch);

    SenseMembership sense;
    sense.status = SenseMembershipStatus.attestedMembershipOnly;
    sense.lexemeId = "L7";
    sense.lexemeSnapshotSha256 = s.rawResponseSha256;
    sense.senseId = "L7-S1";
    assert(composeUsageSense(r, a, sense).status == CompositionStatus.coIndexedSameSense);
    sense.senseId = "L7-S2";
    assert(composeUsageSense(r, a, sense).status == CompositionStatus.noIdentityMatch);
}

unittest
{
    auto r = verifyOriginalLexemeBytes(fakeL6888, request("L6888", 22, fakeL6888));
    assert(r.valid && r.usageCount == 2);
    UsageExampleWitness a,b;
    assert(receiptUsage(r,0,a) && receiptUsage(r,1,b));
    assert(composeUsages(r,a,r,b).status == CompositionStatus.sameSenseOnly);
    auto l7 = verifyOriginalLexemeBytes(fakeL7, request("L7", 42, fakeL7));
    UsageExampleWitness other;
    assert(receiptUsage(l7,0,other));
    assert(composeUsages(r,a,l7,other).status == CompositionStatus.differentLexemes);
}

unittest
{
    auto r = verifyOriginalLexemeBytes(fakeL1340, request("L1340",54,fakeL1340));
    assert(r.valid && r.usageCount == 0 && r.argumentCount == 3 &&
        r.observationCount == 5);
    UsageExampleWitness bad;
    assert(!receiptUsage(r, 0, bad)); // two partial statements CANNOT be joined
    SemanticArgumentWitness a,b;
    assert(receiptSemanticArgument(r,0,a) && receiptSemanticArgument(r,1,b));
    assert(composeArguments(r,a,b).status == CompositionStatus.parallelSameSense);
    assert(composeArguments(r,a,a).status == CompositionStatus.sameOriginalStatement);
    b.roleQId = "Q777";
    assert(composeArguments(r,a,b).status == CompositionStatus.integrityConflict);
    assert(!composeArguments(r,a,a).permitsGrammarProduction);
}

unittest
{
    auto r = verifyOriginalLexemeBytes(fakeL12, request("L12",12,fakeL12));
    assert(r.valid && r.usageCount == 2 && r.argumentCount == 1);
    UsageExampleWitness a,b;
    SemanticArgumentWitness argument;
    assert(receiptUsage(r,0,a) && receiptUsage(r,1,b));
    assert(receiptSemanticArgument(r,0,argument));
    assert(composeUsages(r,a,r,b).status == CompositionStatus.sameContextPair);
    assert(composeUsageArgument(r,a,argument).status == CompositionStatus.parallelSameSense);
    assert(!composeUsageArgument(r,a,argument).permitsGrammarProduction);
}

unittest
{
    auto r = verifyOriginalLexemeBytes(fakeL252527, request("L252527",65,fakeL252527));
    assert(r.valid && r.usageCount == 0 && r.componentCount == 2);
    ComponentWitness a,b;
    assert(receiptComponent(r,0,a) && receiptComponent(r,1,b));
    assert(composeComponents(r,a,b).status == CompositionStatus.parallelComponents);
    assert(composeComponents(r,a,a).status == CompositionStatus.sameOriginalStatement);
    auto target = verifyOriginalLexemeBytes(fakeL40399, request("L40399",99,fakeL40399));
    assert(target.valid);
    assert(composeComponentTarget(r,a,target).status == CompositionStatus.targetSnapshotPresent);
    assert(composeComponentTarget(r,b,target).status == CompositionStatus.noIdentityMatch);
    b.ordinal = "1";
    assert(composeComponents(r,a,b).status == CompositionStatus.integrityConflict);
}
