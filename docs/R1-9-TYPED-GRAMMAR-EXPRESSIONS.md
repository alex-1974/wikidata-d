# R1.9 – Typed grammar evidence expressions

## Objective and non-objectives

The new `wikidata.grammar_expression` module adds an **expression IR** on top of
R1.8's `EvidenceIndex`, *not* a natural-language sentence generator. It is
language-neutral. It reads **only attested R1.7 statements and feature counts**;
no Forms, Senses, lexemes, grammatical values, or reciprocal edges are created.

**Important:** A rule evaluated as `supported` means its *evidence predicate
expression* is supported, **not** that a phrase is grammatical. For example:
- `P5713` on one Sense does not define whether separate values must be combined
  with `all` or `any`. R1.9 does not choose a reading automatically.
- Co-presence of a subject-case statement and a lexeme-gender statement proves
  two records were present; it is not syntactic agreement.
- Observing Arabic dual in the aggregate does not certify a specific Form-ID.
- A `P11952`/`P11953` order claim is **not** a license to construct a missing
  conjugation, even when the statement is documented in both directions.

## Intermediate representation

The JSON research fixture is a *serialization of the typed IR*, not a finalized
user-facing grammar DSL. A rule supplies its case and a tree of operations:

```json
{
  "id": "it-context-not-sufficient-for-choice",
  "case": "it-articles",
  "expectedStatus": "unknown",
  "expr": {
    "op": "all",
    "args": [
      {"op": "predicate", "id": "it-attested-context"},
      {"op": "predicate", "id": "it-il-lo-rule-not-established"}
    ]
  }
}
```

Leaves refer to existing typed R1.8 predicates by ID. Operators:

- `predicate`: R1.8 original statement, form-order or aggregate check.
- `all`: strong Kleene `AND` across **evidence checks**, never between
  qualifiers belonging to different statements. The leaf predicate is still
  responsible for checking its qualifiers on the **same original claim**.
- `any`: strong Kleene `OR` across checks.

The three values `supported`, `contradicted`, and `unknown` combine as follows:

| A | B | all | any |
|---|---|---|---|
| supported | supported | supported | supported |
| supported | unknown | unknown | supported |
| supported | contradicted | contradicted | supported |
| unknown | unknown | unknown | unknown |
| unknown | contradicted | contradicted | unknown |
| contradicted | contradicted | contradicted | contradicted |

**No implicit NOT.** If a statement is absent from Wikidata, the answer remains
`unknown`, not `contradicted`. R1.8's explicit `statement_forbidden` leaf can
report `contradicted` only if it matches an actual original statement;
otherwise it reports `unknown`. `P1889` is never automatic exclusion.

The interpreter checks that every referenced predicate uses exactly the rule's
configured research case; cross-case evidence cannot leak into another
language. Empty conjunctions/disjunctions, unknown operators, duplicate IDs,
more than 256 AST nodes and nesting deeper than 32 are rejected.

The output retains *leaf-scoped* original statement IDs, rather than merging
proofs into a misleading new claim. `certifiesGrammaticality=false` and
`doesNotCreateLexicalData=true` remain explicit.

## Verification (XPS, DMD 2.111.0 and LDC 1.41.0)

The 17 research rules in `research/r1-9-expression-regressions.json` reuse the
15 attested/unknown R1.7 predicates, including Italian articles, German Sense
arguments, Turkish stem context, Swahili order claims, and Arabic aggregates.
The R1.7 reference archive is **not** committed to the D repository.

```bash
cd ~/Programmiersprachen/dlang/wikidata-d

dub test --compiler=dmd
dub test --compiler=ldc2

dmd -i -I=source examples/catalog_grammar_expression.d \
  -L-lcurl -of=/tmp/wikidata-catalog-grammar-expression

/tmp/wikidata-catalog-grammar-expression \
  /tmp/wikidata-r1-7/data/attested-evidence.json \
  /tmp/wikidata-r1-7/data/reference-predicates.json \
  research/r1-9-expression-regressions.json \
  /tmp/wikidata-r1-9-evaluation.json
```

Expected result: `R1.9 REGRESSION: PASS (17 rules)`; 11 supported,
6 unknown, 0 contradicted. Exact status is validated by each rule's
`expectedStatus`, not just by total counts.

R1.8's separate 15-predicate regression must continue to pass unchanged.

## What comes later

R1.9 does not provide an agreement engine, a feature hierarchy solver, a
phonology evaluator, or a textual DSL. A future grammar rule layer will decide
which evidence claims should be interpreted as applicability, selection,
agreement, sequence, or morphology constraints. It must not silently fill
Wikidata's lexical gaps.
