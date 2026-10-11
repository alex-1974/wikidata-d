# M5.6 — Form candidate lookup for unresolved catalogue records

## Purpose

M5.5 matched 466 of 486 Perugia A1 catalogue entries by language,
lemma and lexical category, including `P279` subclass relationships.
The remaining 20 records require further investigation. M5.6 checks whether
any of their search spellings occur as `ontolex:representation` of a Wikidata
Form. No source catalogue entries are removed, and no previous matches change.

## Query semantics

```sparql
SELECT DISTINCT ?word ?lexeme ?form ?lemma ?category WHERE {
  VALUES ?word { "gli"@it "la"@it }
  ?lexeme dct:language wd:Q652 ;
    wikibase:lemma ?lemma ;
    wikibase:lexicalCategory ?category ;
    ontolex:lexicalForm ?form .
  ?form ontolex:representation ?word .
}
```

The D query builder supplies all prefixes and validates language identifiers.
The query is bounded to unresolved catalogue words and uses no category
filter: even a different POS may be relevant as a diagnostic clue.

**A Form candidate is not an accepted mapping.** An Article Form found under
an unrelated Lexeme or a homographic representation may not match the
reference entry. Later work can inspect grammatical features and the owning
Lexeme, then adopt verified associations with provenance.

## Usage

```bash
dmd -i -I=source examples/catalog_form_coverage.d -L-lcurl \
  -of=/tmp/wikidata-catalog-form-coverage

/tmp/wikidata-catalog-form-coverage \
  catalogs/local/it-A1-perugia.json \
  reports/local/it-A1-category-coverage.json \
  reports/local/it-A1-form-candidates.json
```

The output is independent of the category report. Successful HTTP responses
are checkpointed, validated, and reused if their full SPARQL query is unchanged.
Failures do not generate partial reports masquerading as complete results.
HTTP 429 ends the run rather than immediately retrying.

## Quality gates

- `dub test --compiler=dmd` and `dub test --compiler=ldc2`.
- No changes to the catalogue or prior coverage reports.
- 20 unresolved entries in the input yield 20 entries in the Form candidate
  output regardless of how many Forms are found.
- Entity and Form identifiers validated, duplicate Forms deduplicated.
- Test fixtures cover positive and invalid query results without network.
- Real output must be reviewed before treating Form candidates as matches.

## Interpretation

Do not add entries with Form candidates to the 466 confirmed Lexeme matches.
They measure additional discoverability only. A later integration milestone
can decide how to represent exact lemma, subclass, and Form matches in the
learner while preserving their distinct evidence levels.
