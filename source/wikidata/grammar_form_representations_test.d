// R1.12-C3 synthetic negative/positive cases. NOT original Wikidata records.
module wikidata.grammar_form_representations_test;

import wikidata.grammar_form_representations;
import wikidata.grammar_evidence_composition :
    verifyOriginalLexemeBytes, OriginalFormRepresentationSource,
    receiptOriginalFormRepresentationSources;
import wikidata.grammar_statement_witness : SourceSnapshotRef;
import std.digest : toHexString;
import std.digest.sha : sha256Of;
import std.string : replace;

private enum string fixture = `{
 "entities": {"L900301": {
   "id":"L900301", "language":"Q8752", "lexicalCategory":"Q1084",
   "lastrevid":301,"claims":{},
   "forms":[
     {"id":"L900301-F1","grammaticalFeatures":["Q111"],"claims":{},
      "representations":{"eu":{"language":"eu","value":"etiketa"},
                         "eu-Latn":{"language":"eu-Latn","value":"etiketa"}}},
     {"id":"L900301-F2","grammaticalFeatures":["Q222"],"claims":{},
      "representations":{"eu":{"language":"eu","value":"etiketa"}}},
     {"id":"L900301-F3","grammaticalFeatures":[],"claims":{},
      "representations":{"eu":{"language":"eu","value":"ezberdin"}}},
     {"id":"L900301-F4","grammaticalFeatures":[],"claims":{}},
     {"id":"L900301-F5","grammaticalFeatures":[],"claims":{},"representations":{}}
   ],"senses":[]
 }}}`;
private enum string noFormsFixture = `{
 "entities":{"L900301":{"id":"L900301","language":"Q8752",
 "lexicalCategory":"Q1084","lastrevid":301,"claims":{},
 "forms":[],"senses":[]}}}`;

private SourceSnapshotRef snapshot(string body)
{
    auto hex = toHexString(sha256Of(cast(const(ubyte)[]) body));
    string lower;
    foreach (c; hex)
        lower ~= c >= 'A' && c <= 'F' ? cast(char)(c + 32) : c;
    return SourceSnapshotRef("L900301", 301, lower,
        "https://www.wikidata.org/wiki/Special:EntityData/L900301.json");
}
private auto receipt(string body)
{
    return verifyOriginalLexemeBytes(body, snapshot(body));
}

unittest
{
    auto r = receipt(fixture);
    assert(r.valid);
    auto batch = extractOriginalFormRepresentations(r);
    assert(batch.validInput && batch.error.length == 0);
    assert(batch.lexemeId == "L900301" && batch.lexemeLanguageQId == "Q8752");
    assert(batch.originalFormIds.length == 5);
    assert(batch.representations.length == 4);
    assert(batch.formsWithoutRepresentations.length == 2);
    assert(batch.collisions.length == 1);
    auto conflict = batch.collisions[0];
    assert(conflict.lexemeId == "L900301" && conflict.representationTag == "eu");
    assert(conflict.literalText == "etiketa" && conflict.distinctFormIds.length == 2);
    assert(conflict.distinctFormIds[0] == "L900301-F1" &&
        conflict.distinctFormIds[1] == "L900301-F2");
    assert(!batch.permitsFormIdMerge && !batch.permitsFormSelection &&
        !batch.permitsGrammarProduction);
    bool euLatin, first, second;
    foreach (e; batch.representations)
    {
        assert(e.snapshot.revision == 301 && e.lexemeLanguageQId == "Q8752");
        assert(!e.permitsFormIdMerge && !e.permitsFormSelection &&
            !e.permitsGrammarProduction);
        if (e.formId == "L900301-F1" && e.representationTag == "eu-Latn")
        {
            euLatin = true;
            assert(e.literalText == "etiketa" &&
                e.originalRepresentationPath == "/entities/L900301/forms/0/representations/eu-Latn");
        }
        if (e.formId == "L900301-F1" && e.representationTag == "eu")
        {
            first = true;
            assert(e.originalGrammaticalFeatureIds == ["Q111"]);
        }
        if (e.formId == "L900301-F2" && e.representationTag == "eu")
        {
            second = true;
            assert(e.originalGrammaticalFeatureIds == ["Q222"]);
        }
    }
    assert(euLatin && first && second);
}

unittest
{
    // Zero Forms must preserve the Lexeme language without synthesizing Forms.
    auto r = receipt(noFormsFixture);
    assert(r.valid);
    auto b = extractOriginalFormRepresentations(r);
    assert(b.validInput && b.lexemeLanguageQId == "Q8752" &&
        b.originalFormIds.length == 0 && b.representations.length == 0 &&
        b.collisions.length == 0);
    auto invalid = extractOriginalFormRepresentations(typeof(r).init);
    assert(!invalid.validInput &&
        invalid.status == FormRepresentationStatus.sourceNotVerified);
}

unittest
{
    // A FORM's absent/empty map is visible, not silently filled in.
    auto b = extractOriginalFormRepresentations(receipt(fixture));
    assert(b.formsWithoutRepresentations == ["L900301-F4", "L900301-F5"]);
    // Modify returned deep-cloned JSON; private receipt must stay unchanged.
    auto r = receipt(fixture);
    import std.json : parseJSON;
    OriginalFormRepresentationSource[] scratch;
    assert(receiptOriginalFormRepresentationSources(r, scratch));
    scratch[0].originalRepresentations = parseJSON(`{"corrupt":true}`);
    auto still = extractOriginalFormRepresentations(r);
    assert(still.validInput && still.representations.length == 4);
}

unittest
{
    // The receipt gate checks original raw digest, even with valid JSON.
    auto s = snapshot(fixture);
    s.rawResponseSha256 = snapshot(noFormsFixture).rawResponseSha256;
    auto invalid = verifyOriginalLexemeBytes(fixture, s);
    assert(!invalid.valid);
    assert(!extractOriginalFormRepresentations(invalid).validInput);
}

unittest
{
    // Do not accept mismatched language tags, even with freshly hashed bytes.
    auto json = fixture.replace(`"eu-Latn":{"language":"eu-Latn"`,
        `"eu-Latn":{"language":"fr"`);
    assert(json != fixture);
    auto r = receipt(json);
    assert(r.valid);
    auto b = extractOriginalFormRepresentations(r);
    assert(!b.validInput && b.status ==
        FormRepresentationStatus.invalidOriginalRepresentations &&
        b.invalidFormId == "L900301-F1" && b.invalidRepresentationTag == "eu-Latn" &&
        b.representations.length == 0 && b.collisions.length == 0);
}

unittest
{
    auto json = fixture.replace(`"value":"ezberdin"`, `"value":17`);
    assert(json != fixture);
    auto b = extractOriginalFormRepresentations(receipt(json));
    assert(!b.validInput && b.invalidFormId == "L900301-F3" &&
        b.representations.length == 0);
}

unittest
{
    // Synthetically turn the first valid representation map into a JSON
    // array. Other Form data stays intact, so invalidity is C3-specific.
    auto json = fixture.replace(
        `"representations":{"eu":{"language":"eu","value":"etiketa"},
                         "eu-Latn":{"language":"eu-Latn","value":"etiketa"}}`,
        `"representations":[]`);
    assert(json != fixture);
    auto r = receipt(json);
    assert(r.valid);
    auto b = extractOriginalFormRepresentations(r);
    assert(!b.validInput && b.invalidFormId == "L900301-F1" &&
        b.representations.length == 0);
}

unittest
{
    auto json = fixture.replace(`"eu":{"language":"eu","value":"ezberdin"}`,
        `"":{"language":"","value":"ezberdin"}`);
    assert(json != fixture);
    auto b = extractOriginalFormRepresentations(receipt(json));
    assert(!b.validInput && b.invalidFormId == "L900301-F3" &&
        b.invalidRepresentationTag.length == 0);
}

unittest
{
    // UTF-8 textual identity is exact; distinct tags are not merged.
    auto json = fixture.replace(`"value":"ezberdin"`, `"value":"etiketa"`);
    auto b = extractOriginalFormRepresentations(receipt(json));
    assert(b.validInput);
    assert(b.collisions.length == 1);
    assert(b.collisions[0].distinctFormIds.length == 3);
}
