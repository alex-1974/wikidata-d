# M5.8 — Audit of Wikidata grammatical feature combinations

## Purpose

M5.8 follows Scribe-Data's *audit the combinations that actually exist* idea,
implemented independently in D. It reads the **complete M5.5 coverage report**
and collects **all grammatical Form feature combinations of the matched Lexemes**.
The Perugia reference catalogue, Wikidata entities and earlier reports are never
modified. The scope is the matched Lexemes, not the 32 **unmatched** M5.7 Form
candidates; those remain in their own report.

## Input, output, and accounting

Input: `reports/local/it-A1-category-coverage.json` (M5.5).

Output: `reports/local/it-A1-grammar-audit.json` and separately cached SPARQL
responses under `...json.batches/`.

- Deduplicate Lexeme IDs across all catalogue entries and all candidates.
- Find Forms via `?lexeme ontolex:lexicalForm ?form`.
- Read `wikibase:grammaticalFeature` with `OPTIONAL`, retaining Forms with no
  grammatical features rather than silently discarding them.
- Normalize each Form's feature Q-IDs as a sorted set, not an ordered string.
- Count Forms and distinct Lexemes per `(lexicalCategoryId, featureSet)`.
- Preserve every returned `formId` and `lexemeId` with its feature IDs for
  subsequent declarative grammar contracts.
- All categories in the source set remain present, including those for which
  no Forms are returned by SPARQL.

`lexemesWithoutReturnedForms` means **the query returned no Forms**, not proof
that the authoritative Wikibase entity does not contain Forms. WDQS may lag the
Wikibase API. Results reflect a potentially mixed-time view because checkpoints
are obtained at different times; do not label this a synchronized Wikidata dump.

The report includes the original `catalogEntries` count for context, but does
not assert that each recorded Form is itself an A1 learning target. A Lexeme
with multiple Senses and Forms remains whole; CEFR selection stays in the
separate catalogue.

## DMD / LDC quality gates

```sh
dub test --compiler=dmd
dub test --compiler=ldc2
```

## Live run (only after both tests pass)

```sh
dmd -i -I=source examples/catalog_grammar_audit.d \
  -L-lcurl -of=/tmp/wikidata-catalog-grammar-audit
/tmp/wikidata-catalog-grammar-audit \
  reports/local/it-A1-category-coverage.json \
  reports/local/it-A1-grammar-audit.json
```

Network batches are limited to 20 lexemes per query, cached by the exact query,
retried on timeouts (maximum three attempts), and paced. If the server refuses
a request or throttles it, the process stops; it can resume from successful
checkpoints. A report is written atomically only once all batches are present.

## Next phase: grammar contracts

Study the most frequent feature combinations per part of speech, then define
versioned, *language-specific* exercise contracts such as Italian singular/
plural and present-indicative conjugations. The contracts should reference
Wikidata Q-IDs, not Form IDs or English labels, and must not overwrite unknown
features or infer missing grammatical facts. Do not treat frequency as proof
of correctness or automatically discard rare combinations.

## Reference

- Scribe-Data grammar audit:
  https://github.com/scribe-org/Scribe-Data/blob/main/src/scribe_data/cli/audit/wikidata_lexeme_forms.py
- Scribe-Data form combinations query:
  https://github.com/scribe-org/Scribe-Data/blob/main/src/scribe_data/cli/audit/lexeme_form_combinations.sparql
- Scribe-Data contracts overview:
  https://github.com/scribe-org/Organization/blob/main/DATA_CONTRACTS.md

Scribe-Data is GPL-3.0-or-later; M5.8 reimplements the general approach without
copying Scribe source code or its data contracts.
