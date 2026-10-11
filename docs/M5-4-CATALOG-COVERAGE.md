# M5.4: Perugia A1 Wikidata coverage

Purpose: compute live Wikidata lexical coverage of a complete independent
reference catalogue. Never prune source rows, never infer a CEFR level from
Wikidata, and never treat one Sense or Q-label as a verified translation.

## Protocol

- Load local Perugia 486-entry JSON; do not commit copyrighted source rows.
- Deduplicate lemma search targets. Query 20 spellings per SPARQL batch.
- Require a valid SPARQL response for **every** batch. A failed request is
  not evidence that a word is absent. Do not publish partial totals.
- Deduplicate SPARQL Sense-generated rows into distinct Lexemes.
- For each of the 486 original entries, report: matched, multiple candidates,
  or no match. Separate true *query no-lemma-hits* from POS category mismatches.
- Retain all candidates and their sense IDs, even when ambiguous.
- Output report JSON under `reports/local/` (excluded from Git).

Each successful batch is saved beside the requested report in a checkpoint
directory `<report.json>.batches/`. Its JSON envelope contains the exact query
and the full response. Restarting with the same catalogue and batch layout
reuses matching checkpoints; changed queries are fetched anew. Corrupt caches
are errors, not negative dictionary results. The final report is written only
when every batch has succeeded. The prior failed run had no checkpoints, so
its already-retrieved results cannot be recovered.

SPARQL HTTP timeout is 70 seconds (Wikidata server limit 60s). Transient
client timeouts get up to three attempts with pauses. HTTP errors including
429 cause the current run to stop; observe `Retry-After` and resume later.
Automatic Retry-After parsing and revision-aware refresh remain future work.

Not yet addressed: API revision caching, remote pagination, lexical category
subclasses, alternative lemma spellings not represented as lemmas, and
cross-language coverage.

Special Perugia entry #99: `ci (part. pron. luogo)` remains under source POS
review; investigate actual Wikidata matches before defining lookup categories.
The documentation for Italian Wikidata lexemes recognizes grammatical
particle `Q184943` and pronoun `Q36224`. Neither guarantees any particular
`ci` lexeme is assigned that category.

## Run

```
mkdir -p reports/local
dmd -i -I=source examples/catalog_coverage.d -L-lcurl -of=/tmp/wikidata-catalog-coverage
/tmp/wikidata-catalog-coverage catalogs/local/it-A1-perugia.json reports/local/it-A1-coverage.json
```

This is a research probe. It must not turn SPARQL outages into missing words.
