# M5.7 – Form grammatical features (Wikidata)

## Goal

Enrich the **M5.6 Form candidate report** with the grammatical features of
Wikidata Forms. Use the public Wikidata Query Service and `wikibase:grammaticalFeature`.

This is **not** a new lexical coverage figure. The 486 Perugia entries and
the M5.5 `matched=446 / multiple=20 / noMatch=20` counts remain unchanged.

## Why

The written form `gli` occurs as an article form of `il`, but can also be
found in a pronoun paradigm. In a catalogue that expects an article, raw
string equality cannot choose between those candidates. The Form's grammar
features and its parent Lexeme's lexical category are evidence for a future
explicit resolver. Wikidata Forms may also lack features; absence is not
proof that a candidate is wrong.

## Input

- `reports/local/it-A1-form-candidates.json` (M5.6)

## Output

- `reports/local/it-A1-form-features.json` (M5.7; review status `pending`)
- `reports/local/it-A1-form-features.json.batches/` (reusable checkpoints)

The results preserve the `formId`, `lexemeId`, `lemma`, spelling, lexical
category, and all available Wikidata grammatical-feature Q-IDs. No loss of
unknown features and no invented translations or senses.

## Run

```bash
dmd -i -I=source examples/catalog_form_features.d -L-lcurl \
  -of=/tmp/wikidata-catalog-form-features
/tmp/wikidata-catalog-form-features \
  reports/local/it-A1-form-candidates.json \
  reports/local/it-A1-form-features.json
```

## Acceptance

1. `dub test --compiler=dmd` and `dub test --compiler=ldc2` pass.
2. M5.6 report is unchanged.
3. M5.7 reports existing Form feature IDs, including absence of features.
4. Missing or malformed API responses fail; they never mean 'zero features'.
5. No Form candidate is automatically promoted to a confirmed match.
6. The source catalogue remains independent from Wikidata coverage.
