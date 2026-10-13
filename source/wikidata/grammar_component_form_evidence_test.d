// Research-only SYNTHETIC fixtures. These are NOT Wikidata original responses.
module wikidata.grammar_component_form_evidence_test;
import wikidata.grammar_component_form_evidence;
import wikidata.grammar_evidence_composition;
import wikidata.grammar_statement_witness : SourceSnapshotRef, ComponentWitness;
import std.digest : toHexString;
import std.digest.sha : sha256Of;

private enum string ownerJson = "{\"entities\":{\"L900001\":{\"claims\":{\"P5238\":[{\"id\":\"L900001$part1\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900002\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"1\"},\"property\":\"P1545\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"},{\"id\":\"L900001$part2\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900003\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"2\"},\"property\":\"P1545\",\"snaktype\":\"value\"}],\"P5548\":[{\"datatype\":\"wikibase-form\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"form\",\"id\":\"L900003-F1\"}},\"property\":\"P5548\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"}]},\"forms\":[{\"grammaticalFeatures\":[],\"id\":\"L900001-F1\"}],\"id\":\"L900001\",\"language\":\"Q256\",\"lastrevid\":101,\"lexicalCategory\":\"Q1084\",\"senses\":[{\"claims\":{},\"id\":\"L900001-S1\"}]}}}";
private enum string targetJson = "{\"entities\":{\"L900003\":{\"claims\":{},\"forms\":[{\"grammaticalFeatures\":[],\"id\":\"L900003-F1\",\"representations\":{\"ota\":{\"language\":\"ota\",\"value\":\"\\u062c\\u06cc\"},\"tr\":{\"language\":\"tr\",\"value\":\"ci\"}}},{\"grammaticalFeatures\":[],\"id\":\"L900003-F2\",\"representations\":{\"tr\":{\"language\":\"tr\",\"value\":\"ci\"}}}],\"id\":\"L900003\",\"language\":\"Q256\",\"lastrevid\":303,\"lexicalCategory\":\"Q1084\",\"senses\":[{\"claims\":{},\"id\":\"L900003-S1\"}]}}}";
private enum string wrongTargetJson = "{\"entities\":{\"L900004\":{\"claims\":{},\"forms\":[{\"grammaticalFeatures\":[],\"id\":\"L900004-F1\"}],\"id\":\"L900004\",\"language\":\"Q256\",\"lastrevid\":404,\"lexicalCategory\":\"Q1084\",\"senses\":[{\"claims\":{},\"id\":\"L900004-S1\"}]}}}";
private enum string ambiguousJson = "{\"entities\":{\"L900001\":{\"claims\":{\"P5238\":[{\"id\":\"L900001$part1\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900002\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"1\"},\"property\":\"P1545\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"},{\"id\":\"L900001$part2\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900003\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"2\"},\"property\":\"P1545\",\"snaktype\":\"value\"}],\"P5548\":[{\"datatype\":\"wikibase-form\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"form\",\"id\":\"L900003-F1\"}},\"property\":\"P5548\",\"snaktype\":\"value\"},{\"datatype\":\"wikibase-form\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"form\",\"id\":\"L900003-F2\"}},\"property\":\"P5548\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"}]},\"forms\":[{\"grammaticalFeatures\":[],\"id\":\"L900001-F1\"}],\"id\":\"L900001\",\"language\":\"Q256\",\"lastrevid\":101,\"lexicalCategory\":\"Q1084\",\"senses\":[{\"claims\":{},\"id\":\"L900001-S1\"}]}}}";
private enum string wrongDatatypeJson = "{\"entities\":{\"L900001\":{\"claims\":{\"P5238\":[{\"id\":\"L900001$part1\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900002\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"1\"},\"property\":\"P1545\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"},{\"id\":\"L900001$part2\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900003\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"2\"},\"property\":\"P1545\",\"snaktype\":\"value\"}],\"P5548\":[{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"form\",\"id\":\"L900003-F1\"}},\"property\":\"P5548\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"}]},\"forms\":[{\"grammaticalFeatures\":[],\"id\":\"L900001-F1\"}],\"id\":\"L900001\",\"language\":\"Q256\",\"lastrevid\":101,\"lexicalCategory\":\"Q1084\",\"senses\":[{\"claims\":{},\"id\":\"L900001-S1\"}]}}}";
private enum string wrongEntityTypeJson = "{\"entities\":{\"L900001\":{\"claims\":{\"P5238\":[{\"id\":\"L900001$part1\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900002\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"1\"},\"property\":\"P1545\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"},{\"id\":\"L900001$part2\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900003\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"2\"},\"property\":\"P1545\",\"snaktype\":\"value\"}],\"P5548\":[{\"datatype\":\"wikibase-form\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900003-F1\"}},\"property\":\"P5548\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"}]},\"forms\":[{\"grammaticalFeatures\":[],\"id\":\"L900001-F1\"}],\"id\":\"L900001\",\"language\":\"Q256\",\"lastrevid\":101,\"lexicalCategory\":\"Q1084\",\"senses\":[{\"claims\":{},\"id\":\"L900001-S1\"}]}}}";
private enum string missingTargetFormJson = "{\"entities\":{\"L900001\":{\"claims\":{\"P5238\":[{\"id\":\"L900001$part1\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900002\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"1\"},\"property\":\"P1545\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"},{\"id\":\"L900001$part2\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900003\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"2\"},\"property\":\"P1545\",\"snaktype\":\"value\"}],\"P5548\":[{\"datatype\":\"wikibase-form\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"form\",\"id\":\"L900003-F9\"}},\"property\":\"P5548\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"}]},\"forms\":[{\"grammaticalFeatures\":[],\"id\":\"L900001-F1\"}],\"id\":\"L900001\",\"language\":\"Q256\",\"lastrevid\":101,\"lexicalCategory\":\"Q1084\",\"senses\":[{\"claims\":{},\"id\":\"L900001-S1\"}]}}}";
private enum string wrongParentFormJson = "{\"entities\":{\"L900001\":{\"claims\":{\"P5238\":[{\"id\":\"L900001$part1\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900002\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"1\"},\"property\":\"P1545\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"},{\"id\":\"L900001$part2\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900003\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"2\"},\"property\":\"P1545\",\"snaktype\":\"value\"}],\"P5548\":[{\"datatype\":\"wikibase-form\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"form\",\"id\":\"L900004-F1\"}},\"property\":\"P5548\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"}]},\"forms\":[{\"grammaticalFeatures\":[],\"id\":\"L900001-F1\"}],\"id\":\"L900001\",\"language\":\"Q256\",\"lastrevid\":101,\"lexicalCategory\":\"Q1084\",\"senses\":[{\"claims\":{},\"id\":\"L900001-S1\"}]}}}";
private enum string wrongComponentDatatypeJson = "{\"entities\":{\"L900001\":{\"claims\":{\"P5238\":[{\"id\":\"L900001$part1\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900002\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"1\"},\"property\":\"P1545\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"},{\"id\":\"L900001$part2\",\"mainsnak\":{\"datatype\":\"string\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900003\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"2\"},\"property\":\"P1545\",\"snaktype\":\"value\"}],\"P5548\":[{\"datatype\":\"wikibase-form\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"form\",\"id\":\"L900003-F1\"}},\"property\":\"P5548\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"}]},\"forms\":[{\"grammaticalFeatures\":[],\"id\":\"L900001-F1\"}],\"id\":\"L900001\",\"language\":\"Q256\",\"lastrevid\":101,\"lexicalCategory\":\"Q1084\",\"senses\":[{\"claims\":{},\"id\":\"L900001-S1\"}]}}}";
private enum string deprecatedJson = "{\"entities\":{\"L900001\":{\"claims\":{\"P5238\":[{\"id\":\"L900001$part1\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900002\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"1\"},\"property\":\"P1545\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"},{\"id\":\"L900001$part2\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900003\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"2\"},\"property\":\"P1545\",\"snaktype\":\"value\"}],\"P5548\":[{\"datatype\":\"wikibase-form\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"form\",\"id\":\"L900003-F1\"}},\"property\":\"P5548\",\"snaktype\":\"value\"}]},\"rank\":\"deprecated\"}]},\"forms\":[{\"grammaticalFeatures\":[],\"id\":\"L900001-F1\"}],\"id\":\"L900001\",\"language\":\"Q256\",\"lastrevid\":101,\"lexicalCategory\":\"Q1084\",\"senses\":[{\"claims\":{},\"id\":\"L900001-S1\"}]}}}";
private enum string emptyQualifierJson = "{\"entities\":{\"L900001\":{\"claims\":{\"P5238\":[{\"id\":\"L900001$part1\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900002\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"1\"},\"property\":\"P1545\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"},{\"id\":\"L900001$part2\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900003\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"2\"},\"property\":\"P1545\",\"snaktype\":\"value\"}],\"P5548\":[]},\"rank\":\"normal\"}]},\"forms\":[{\"grammaticalFeatures\":[],\"id\":\"L900001-F1\"}],\"id\":\"L900001\",\"language\":\"Q256\",\"lastrevid\":101,\"lexicalCategory\":\"Q1084\",\"senses\":[{\"claims\":{},\"id\":\"L900001-S1\"}]}}}";
private enum string noValueQualifierJson = "{\"entities\":{\"L900001\":{\"claims\":{\"P5238\":[{\"id\":\"L900001$part1\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900002\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"1\"},\"property\":\"P1545\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"},{\"id\":\"L900001$part2\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900003\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"2\"},\"property\":\"P1545\",\"snaktype\":\"value\"}],\"P5548\":[{\"datatype\":\"wikibase-form\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"form\",\"id\":\"L900003-F1\"}},\"property\":\"P5548\",\"snaktype\":\"novalue\"}]},\"rank\":\"normal\"}]},\"forms\":[{\"grammaticalFeatures\":[],\"id\":\"L900001-F1\"}],\"id\":\"L900001\",\"language\":\"Q256\",\"lastrevid\":101,\"lexicalCategory\":\"Q1084\",\"senses\":[{\"claims\":{},\"id\":\"L900001-S1\"}]}}}";
private enum string wrongDataValueJson = "{\"entities\":{\"L900001\":{\"claims\":{\"P5238\":[{\"id\":\"L900001$part1\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900002\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"1\"},\"property\":\"P1545\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"},{\"id\":\"L900001$part2\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900003\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"2\"},\"property\":\"P1545\",\"snaktype\":\"value\"}],\"P5548\":[{\"datatype\":\"wikibase-form\",\"datavalue\":{\"type\":\"string\",\"value\":{\"entity-type\":\"form\",\"id\":\"L900003-F1\"}},\"property\":\"P5548\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"}]},\"forms\":[{\"grammaticalFeatures\":[],\"id\":\"L900001-F1\"}],\"id\":\"L900001\",\"language\":\"Q256\",\"lastrevid\":101,\"lexicalCategory\":\"Q1084\",\"senses\":[{\"claims\":{},\"id\":\"L900001-S1\"}]}}}";
private enum string formZeroJson = "{\"entities\":{\"L900001\":{\"claims\":{\"P5238\":[{\"id\":\"L900001$part1\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900002\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"1\"},\"property\":\"P1545\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"},{\"id\":\"L900001$part2\",\"mainsnak\":{\"datatype\":\"wikibase-lexeme\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"lexeme\",\"id\":\"L900003\"}},\"property\":\"P5238\",\"snaktype\":\"value\"},\"qualifiers\":{\"P1545\":[{\"datatype\":\"string\",\"datavalue\":{\"type\":\"string\",\"value\":\"2\"},\"property\":\"P1545\",\"snaktype\":\"value\"}],\"P5548\":[{\"datatype\":\"wikibase-form\",\"datavalue\":{\"type\":\"wikibase-entityid\",\"value\":{\"entity-type\":\"form\",\"id\":\"L900003-F0\"}},\"property\":\"P5548\",\"snaktype\":\"value\"}]},\"rank\":\"normal\"}]},\"forms\":[{\"grammaticalFeatures\":[],\"id\":\"L900001-F1\"}],\"id\":\"L900001\",\"language\":\"Q256\",\"lastrevid\":101,\"lexicalCategory\":\"Q1084\",\"senses\":[{\"claims\":{},\"id\":\"L900001-S1\"}]}}}";

private SourceSnapshotRef snapshot(string lexemeId, ulong revision, string original)
{
    auto hex = toHexString(sha256Of(cast(const(ubyte)[]) original));
    string lowercase;
    foreach (c; hex)
        lowercase ~= (c >= 'A' && c <= 'F') ? cast(char)(c + 32) : c;
    return SourceSnapshotRef(lexemeId, revision, lowercase,
        "https://www.wikidata.org/wiki/Special:EntityData/" ~ lexemeId ~ ".json");
}
private OriginalLexemeReceipt ownerReceipt(string body)
{
    return verifyOriginalLexemeBytes(body, snapshot("L900001", 101, body));
}
private ComponentWitness componentAt(OriginalLexemeReceipt receipt, size_t index)
{
    ComponentWitness result;
    assert(receiptComponent(receipt, index, result));
    return result;
}
unittest
{
    auto owner = ownerReceipt(ownerJson);
    auto target = verifyOriginalLexemeBytes(targetJson,
        snapshot("L900003", 303, targetJson));
    auto other = verifyOriginalLexemeBytes(wrongTargetJson,
        snapshot("L900004", 404, wrongTargetJson));
    assert(owner.valid && target.valid && other.valid && owner.componentCount == 2);
    auto noForm = componentAt(owner, 0);
    auto explicitForm = componentAt(owner, 1);
    assert(noForm.componentLexemeId == "L900002");
    assert(explicitForm.componentLexemeId == "L900003");

    auto missing = attestComponentObjectForm(owner, explicitForm);
    assert(missing.status == ComponentObjectFormStatus.targetNotFetched);
    auto positive = attestComponentObjectForm(owner, explicitForm, target);
    assert(positive.status == ComponentObjectFormStatus.verifiedTargetFormMembership);
    assert(positive.formId == "L900003-F1" && positive.ordinalLiteral == "2");
    assert(positive.ownerSnapshot.revision == 101 &&
        positive.targetSnapshot.revision == 303);
    assert(positive.originalComponentStatement.statementId == "L900001$part2");
    assert(positive.originalTargetFormPath == "entities.L900003.forms[0]");
    assert(!positive.permitsFormSelection && !positive.permitsGrammarProduction &&
        !positive.permitsGeneralFormSenseAssociation);
    // The P5238 with no P5548 cannot select any form, even when
    // independently checked target L900002 has precisely one form.
    auto noQualifier = attestComponentObjectForm(owner, noForm);
    assert(noQualifier.status == ComponentObjectFormStatus.noObjectFormQualifier);
    assert(attestComponentObjectForm(owner, noForm, target).status ==
        ComponentObjectFormStatus.noObjectFormQualifier);
    assert(attestComponentObjectForm(owner, explicitForm, other).status ==
        ComponentObjectFormStatus.targetIdentityMismatch);
    OriginalLexemeReceipt invalid;
    assert(attestComponentObjectForm(owner, explicitForm, invalid).status ==
        ComponentObjectFormStatus.sourceNotVerified);
    assert(attestComponentObjectForm(invalid, explicitForm).status ==
        ComponentObjectFormStatus.sourceNotVerified);
    auto mutated = explicitForm;
    mutated.componentLexemeId = "L900004";
    assert(attestComponentObjectForm(owner, mutated, target).status ==
        ComponentObjectFormStatus.sourceNotVerified);
    auto wrongSha = snapshot("L900003", 303, targetJson);
    wrongSha.rawResponseSha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    assert(!verifyOriginalLexemeBytes(targetJson, wrongSha).valid);
    // Two different Form IDs with the same original surface must stay apart.
    auto memberA = receiptFormMembership(target, "L900003-F1");
    auto memberB = receiptFormMembership(target, "L900003-F2");
    assert(memberA.present && memberB.present &&
        memberA.originalEvidencePath != memberB.originalEvidencePath);
}
unittest
{
    auto target = verifyOriginalLexemeBytes(targetJson,
        snapshot("L900003", 303, targetJson));
    foreach (raw; [ambiguousJson, wrongDatatypeJson, wrongEntityTypeJson,
        wrongParentFormJson, emptyQualifierJson, noValueQualifierJson,
        wrongDataValueJson, formZeroJson])
    {
        auto owner = ownerReceipt(raw);
        assert(owner.valid && owner.componentCount == 2);
        auto comp = componentAt(owner, 1);
        assert(attestComponentObjectForm(owner, comp, target).status ==
            ComponentObjectFormStatus.invalidOrAmbiguousQualifier);
    }
    auto missOwner = ownerReceipt(missingTargetFormJson);
    assert(attestComponentObjectForm(missOwner, componentAt(missOwner, 1), target).status ==
        ComponentObjectFormStatus.formNotPresentInTargetSnapshot);
    auto badMain = ownerReceipt(wrongComponentDatatypeJson);
    assert(badMain.valid && badMain.componentCount == 2);
    assert(attestComponentObjectForm(badMain, componentAt(badMain, 1), target).status ==
        ComponentObjectFormStatus.sourceNotVerified);
    auto deprecatedOwner = ownerReceipt(deprecatedJson);
    assert(deprecatedOwner.valid && deprecatedOwner.componentCount == 1);
    // The deprecated P5238 is observed, but never a positive ComponentWitness.
    assert(!receiptFormMembership(target, "L900003-F99").present);
}
