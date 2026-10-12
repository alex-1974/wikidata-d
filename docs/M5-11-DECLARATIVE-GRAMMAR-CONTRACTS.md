# M5.11 – Declarative grammar contracts (offline, no inference)

## Input

- A **versioned JSON contract** defining language, Wikidata lexical category,
  grammatical slots, and explicit feature-implication rules.
- M5.10 `reports/local/it-A1-form-representations.json` with Form IDs,
  original feature Q-IDs, and language-tagged spellings.

`grammar_contract.d` is GUI-independent. It does not alter the Perugia A1
curriculum, the Wikidata lexicographical data, or any earlier report. It makes
no requests to Wikidata.

## Matching statuses

- `exact`: all requested Q-IDs occur directly on the Wikidata Form.
- `inherited`: a requested feature is covered by an explicitly curated,
  **approved** implication (e.g. Q56682909 ⇒ Q682111 and Q192613).
  This version does NOT perform dynamic P279 traversal or check an implication
  against the latest Wikidata graph. Contracts must be reviewed and versioned.
- `review`: a contract implication with status `review` yields the match;
  the result is **not counted as confirmed**.
- `missing`: no direct, approved or review match exists.

For missing slots, `incompleteCandidates` includes Forms satisfying the
slot's `anchorFeatureIds` (e.g. grammatical person and number) but not all
required features. An incomplete candidate is **never** an answer. Thus
`L21251-F9`, `stiamo`, remains a reviewable candidate for 1pl, rather than a
fabricated, automatically accepted present-indicative conjugation.

A slot can return more than one matching Form (e.g. `andare`: `vado` and
`vo`); all candidates and their original feature IDs and representations
remain visible.

A contract's `implications` include an `evidence` string, but this is curated
metadata, not a cryptographically verified provenance trail. Never use this
first implementation to assert that Wikidata's P279 / P1889 graph is conflict
free. The disputed imperfect relationship `Q12547192` ↔ `Q108524486` is
not approved or included in the initial contract.

## Run

```sh
dub test --compiler=dmd
dub test --compiler=ldc2

dmd -i -I=source examples/catalog_grammar_contract.d \
    -L-lcurl -of=/tmp/wikidata-catalog-grammar-contract

/tmp/wikidata-catalog-grammar-contract \
    grammar_contracts/it-verb-present-indicative.json \
    reports/local/it-A1-form-representations.json \
    L21251 L38246
```

Expected with the M5.10 report from 2026-10-11:
- `L21251` (*stare*): 5 of 6 slots confirmed; `stiamo` occurs only among
  unverified/incomplete 1pl candidates due to missing tense/mood Q-IDs.
- `L38246` (*andare*): all 6 slots confirmed; both `vado` and `vo` survive.


## M5.11.1: Explicitly incompatible features in diagnostic candidates

An anchored near-miss must not be any Form with the same person and number.
For example, `stare` has 1pl `stavamo` (imperfect), `stemmo` (preterite),
`staremo` (future), `staremmo` (conditional), and multiple `stiamo`
Forms in different moods. These are **not** all equally plausible
present-indicative candidates.

The optional contract-level `incompatibleFeatureIds` lists explicit,
curated Q-IDs that rule out a Form as evidence for **any** slot of this
particular contract. The evaluator suppresses such Forms from confirmed,
review, and near-miss results. For auditability, it reports them under
`excludedCandidates` with the exact disqualifying Q-IDs. They never raise
coverage or appear as proposed exercise answers.

This is deliberately not a global grammar ontology. Future contracts may
have different exclusions, and no exclusion is inferred from missing data.
Forms without contradictory evidence, like `L21251-F9` (`stiamo`), remain
**unverified** and still do not count as confirmed.

The initial Italian present-indicative exclusion set covers explicitly
marked imperfect, preterite, future, conditional, subjunctive and imperative
Forms. It is a curated research rule, not a claim that this list covers every
potentially incompatible grammatical Q-ID in Wikidata. False-negative
exclusions are safer than falsely confirming an exercise answer; we preserve
original features in the M5.10 data for later reevaluation.

## Limitations / following milestone

This is an **MVP for contract evaluation**, not a full Wikidata ontology reasoner.
It does not infer missing grammatical facts from surrounding Forms, resolve
contradictory P1889 statements, assign CEFR grammar levels, rank alternate
spellings, or select among Sense meanings. Before using as an exercise engine,
add explicit conflict detection, graph provenance, and per-curriculum exercise
selection.

## M5.11.2: Exclude Italian simple future from present diagnostics

Wikidata's `Q1475560` is **simple future** and a `P279` subclass of
`Q501405` (future tense). The MVP resolver checks literal excluded Q-IDs,
not their subclass closure, so merely excluding `Q501405` does not exclude
Forms carrying `Q1475560`. For Italian present indicative the curated
incompatibility list now contains both Q-IDs.

Regression fixture: `L21251-F28` (`staremo`, indicative simple future)
must be excluded from present 1pl incomplete candidates; `L21251-F9`
(`stiamo`, person+number only) remains an **unverified** candidate.
Neither counts as a confirmed answer. General ontology-aware negative
reasoning is future work, and all Form statements remain unchanged.
