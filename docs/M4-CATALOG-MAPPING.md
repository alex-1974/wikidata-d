# M4: Independent vocabulary catalogues and Wikidata candidate matching

## Architecture

- Source catalogues are complete, immutable reference sets at every language
  and level. Wikidata never removes or rewrites an entry.
- Each catalogue includes its own `id`, language, level, source details and
  arbitrary original fields. Several source catalogues may cover one level.
- `CatalogEntry` contains original `lemma`, optional lexical-category Q-ID,
  optional *explicit* `lookupLemmas` (e.g. source `amico/a` -> search `amico`,
  `amica`) and the original JSON under `raw`.
- Separate `CatalogMatch` records match source entries to 0, 1 or many Lexeme
  candidates by exact lemma and lexical category. Duplicate Sense result rows
  are grouped by Lexeme, with all Sense IDs retained.
- This layer does **not** assign a learning level to each Wikidata Sense, infer
  translations or invent absent lexicographic data.

`catalogs/it-A1-demo.json` is a **demonstration fixture**, not a copy of the
Perugia list. A full-source import and associated rights review remain future
work.

## Run on the XPS

```sh
dub test --compiler=dmd
dub test --compiler=ldc2
dmd -i -I=source examples/catalog_lookup.d -L-lcurl -of=catalog_lookup
./catalog_lookup
```

## Next work

The HTTP client is synchronous and must not block dcanvas. A `noMatch` status
means *no candidate in the successful lookup responses*, not a permanent
absence from Wikidata. For large catalogues add request scheduling, retries,
revision-aware caching, persistent mappings and SPARQL paging. Source-catalogue
licensing must be checked before importing redistributable word lists.
