# R1.8 – Language-neutral grammar evidence core (D)

## Research boundary

`wikidata.grammar_evidence` ports the 15 R1.7 Python evidence regressions to
D. It is **not** an implementation of natural-language grammar, a Wikidata
sync operation, or a word-form generator. All information comes from the
recorded Wikidata statement fixture; no lexical data is created or completed.

It is independent of `wikidata.grammar_contract` (M5.11) for now, so the
successful Italian conjugation behavior is unchanged.

### Types

- `EvidenceStatement`: original Wikidata source level (lexeme/form/sense),
  main snak, statement ID, rank, qualifier snaks, reference count and source.
- `GrammarConstraint`: typed request with original Wikidata IDs. V1 supports
  statement existence, explicit forbidden statements, original form order,
  case-level feature occurrence, and explicitly undecidable requests.
- `ConstraintEvaluation`: `supported | contradicted | unknown`, original
  statement proofs, scope, original direction counts, aggregate frequency.
- `EvidenceIndex`: case/source/property index; **never** joins qualifiers
  from separate claims or silently broadens a Lexeme property to its Forms.
- `FormRelationIndex`: normalizes the *view* of `P11952` and `P11953`, but
  does not write an inverse statement and does not license composition.

`contradicted` is returned **only for an explicitly forbidden statement that
was nevertheless observed**; `P1889`, unobserved Q-IDs, and missing attributes
never imply grammatical incompatibility automatically.

This port intentionally does not use the R1.7 SHA256 computed from Python's
stable sorted JSON serialization: deriving an identical canonical serialization
in D is a separate problem. Preserve the SHA-256 provenance recorded in the
R1.7 fixture/archive; do not substitute an incompatible checksum.

## Verification on Ubuntu XPS

This repository contains the *program code*, not the 810 KB research fixture.
Download the existing `wikidata-r1-7-research.zip` and extract it:

```sh
cd ~/Programmiersprachen/dlang/wikidata-d
unzip -oq "$HOME/Downloads/wikidata-r1-7-research.zip" -d /tmp/

dub test --compiler=dmd
dub test --compiler=ldc2

dmd -i -I=source examples/catalog_grammar_evidence.d \
    -L-lcurl -of=/tmp/wikidata-catalog-grammar-evidence

/tmp/wikidata-catalog-grammar-evidence \
    /tmp/wikidata-r1-7/data/attested-evidence.json \
    /tmp/wikidata-r1-7/data/reference-predicates.json \
    /tmp/wikidata-r1-8-evaluation.json
```

**Expected**: `R1.8 REGRESSION: PASS (15 predicates)`, ten `supported`, five
`unknown`, zero `contradicted`; individual claims have the same *counts* as
R1.7, including two original proofs for the fully attested Swahili order pair
and a single proof for the one-sided pair. An unavailable statement remains
`unknown`.

The full R1.7 assertion set runs through the example, whereas built-in module
unit tests use small entirely synthetic fixtures. The R1.7 data can be retained
outside source control; do not commit the full downloaded research corpus.

## Deliberate omissions

1. There is no linguistic disjointness, transitive `P279` resolution, or
   automatic interpretation of the meaning of a property value.
2. There is no inference of Italian `il/lo` conditions, French article choice,
   Swahili noun-class agreement, or Turkish phonological alternations.
3. Sense requirements via `P5713` remain evidence of recorded requirements,
   **not** a decision about whether simultaneous values mean `AND` or `OR`.
4. Statements with unusual ranks are preserved and may optionally be filtered
   by requested rank; no Wikidata preference policy is imposed in this v1.
5. The multi-source historical snapshot is not atomically consistent.

After the DMD/LDC gates and the 15 original evidence regressions pass, R1.9
can specify a typed constraint expression/DSL intermediate representation.
