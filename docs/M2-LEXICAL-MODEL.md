# M2 – Typed, lossless lexical view

This increment adds `source/wikidata/lexeme.d` without changing the M1 API.
It maps one `wbgetentities` Lexeme entity onto D structs:

- `WikidataLexeme`: ID, language Q-ID, category Q-ID, forms, senses, statements, raw JSON.
- `WikidataForm`: ID, grammatical feature IDs, statements, raw JSON.
- `WikidataSense`: ID, statements, raw JSON.
- `WikidataStatement`: property ID, optional entity ID target, raw JSON.

`raw` preserves every field as returned by Wikidata, including glosses,
representations, lemma language variants, qualifiers, references, ranks,
unknown properties, and future fields. There is no hardcoded P5137/P9970/P5972
filter and no conflation of word spelling, lexeme ID, and sense ID.

The statement `targetId` is populated only when `mainsnak.datavalue.value.id`
is a string. Textual and numeric statement payloads remain accessible through
`raw`, even when `targetId` is empty. An empty `targetId` does not mean an
absent statement.

## Validation on the XPS

```sh
dub test --compiler=dmd
dub test --compiler=ldc2
dmd -i -I=source examples/inspect.d -L-lcurl -of=inspect
./inspect
```

Inspect output for the four candidate IDs found by the M1 live query:
`L38246`, `L1219303`, `L711417`, `L5577`.

Expected from the user's 2026-10-11 live inspection, subject to Wikidata updates:

| ID | Lexical category | Forms | Senses |
| --- | --- | ---: | ---: |
| L38246 | Q24905 | 53 | 1 |
| L1219303 | Q1084 | 2 | 2 |
| L711417 | Q34698 | 8 | 1 |
| L5577 | Q1084 | 10 | 2 |

## Explicitly not part of this increment

- Catalog import/mapping (separate layer).
- A1 filtering (never discard catalog entries missing from Wikidata).
- Translation inference via SPARQL / graph traversal.
- Database caching, revision handling, sync logic.
- Network integration tests as part of `dub test`.
