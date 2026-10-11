# M5.5 – Wikidata lexical-category compatibility

## Motivation

Perugia's broad categories can differ from Wikidata's more specific
`wikibase:lexicalCategory` Q-items. Exact equality is insufficient.
`Q468801` (personal pronoun) is a subclass of `Q36224` (pronoun), for example.

## Design

- The 486 original catalogue entries remain unchanged.
- Match exact category IDs first; alternatively accept a Wikidata `P279+`
  subclass relationship from the observed category to the expected category.
- Obtain category compatibility from Wikidata, never from a hard-coded list
  for Italian. Cache the SPARQL result with exact query text.
- Record `matchMethod` (`exact` or `subclass`) per candidate; retain the
  observed Wikidata category and all original Sense IDs.
- Never traverse the class hierarchy in reverse. A generic pronoun is not
  automatically a personal pronoun.
- Do not treat unrelated categories as compatible: `Q9788` (letter) is not
  an article merely because its lemma is `i`.
- Direct query categories are deliberately restricted to categories seen in
  unmatched entries and expected catalogue categories.
- This phase does not search Form representations or solve the 15 cases
  without exact-lemma hits; those are a separate future extension.

## Reproducibility

Run `catalog_coverage` first; the new command reads the 26 previously
stored M5.4 checkpoints, performs at most one additional P279 query, and
writes a separate local report:

```
dmd -i -I=source examples/catalog_category_coverage.d -L-lcurl \
    -of=/tmp/wikidata-catalog-category-coverage

/tmp/wikidata-catalog-category-coverage \
    catalogs/local/it-A1-perugia.json \
    reports/local/it-A1-coverage.json \
    reports/local/it-A1-category-coverage.json
```

Do not commit generated Perugia catalogue data or reports until reuse rights
are resolved. The new report is a snapshot and does not modify the source
catalogue, original M5.4 report, or original M5.4 checkpoints.

## Remaining risks

- P279 is a *Wikidata graph assertion*, not proof that two grammatical usages
  are identical. A subclass match is transparent, not an editorial correction.
- Homographs and multiple matched variants must remain multiple candidates.
- No Sense remains no Sense; we do not create meanings automatically.
