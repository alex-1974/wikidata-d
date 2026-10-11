# M5.10 – Wikidata Form representations

## Goal

Join Wikidata's `ontolex:representation` literal spellings to the M5.8
Form-ID and grammatical-feature audit **without inferring or overwriting data**.
This is infrastructure for declarative grammar exercises, **not** an exercise
answer generator or a confirmation of the disputable Italian imperfect mapping.

## Inputs

1. `reports/local/it-A1-category-coverage.json` – M5.5 catalogue-to-Lexeme
   mappings. It defines the complete Lexeme set, even if M5.8 returned no
   Forms for one of those Lexemes.
2. `reports/local/it-A1-grammar-audit.json` – M5.8 Form IDs and original
   grammatical feature Q-IDs.

The two reports must agree on catalogue ID, language, level and the count of
unique Lexemes.

## Query and output

Queries are batched by 20 unique Lexeme IDs using
`?lexeme ontolex:lexicalForm ?form` and optional
`?form ontolex:representation ?representation`.

Each output Form retains its M5.8 `lexemeId`, `formId`, `lexicalCategoryId`,
`grammaticalFeatureIds`, and a list of `{text, languageCode}` representations.
Multiple representations and missing language tags are preserved, not collapsed
or silently filtered. Every Form in M5.8 remains in the output, even when no
representation is returned.

Because the two reports were collected at different times, the result contains
`missingFormIds`, `newFormsNotInAudit`, and `snapshotConsistency: mixed-time`.
Unknown/new Form IDs are **not** promoted into the M5.8 grammar audit.
Checkpoint files bind the exact query to its response; the final report is
written atomically only after all batches succeed. On HTTP errors the job
stops; retry on a later run, respecting `Retry-After` when rate-limited.

## Gates

```sh
dub test --compiler=dmd
dub test --compiler=ldc2
```

## Live run

```sh
dmd -i -I=source examples/catalog_form_representations.d \
    -L-lcurl -of=/tmp/wikidata-catalog-form-representations
/tmp/wikidata-catalog-form-representations \
    reports/local/it-A1-category-coverage.json \
    reports/local/it-A1-grammar-audit.json \
    reports/local/it-A1-form-representations.json
```

## Non-goals and follow-up

- No new CEFR curriculum or edits to Perugia data.
- No correction of missing or contradictory Wikidata statements.
- No automatic acceptance of grammatical feature paths under review.
- No fabricated translations, IPA, or conjugated strings.
- Next: resolve feature equivalences with provenance, validate the single
  missing present-indicative 1pl slot and the imperfect P279/P1889 discrepancy;
  then define exercises from explicit, versioned grammar contracts.

Reference: https://www.wikidata.org/wiki/Wikidata:Lexicographical_data/Documentation/Query_Service
