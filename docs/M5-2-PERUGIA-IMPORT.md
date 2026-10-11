# M5.2 – Offline import of the Perugia Italian A1 source list

## Scope

The extractor reads the university's *locally downloaded* HTML. It never
queries Wikidata, deletes catalog rows, or derives translations. Its output
is a **local reference catalogue** compatible with M5.1. The page is not
copied into the repository.

Original text, grammatical annotation, source number and the original HTML
line are retained. The automatically constructed lookup targets are separate
from these source fields and intentionally conservative: only verified noun
(Q1084), adjective (Q34698) and verb (Q24905) category identifiers are used.
For other POS, queries are allowed without a POS constraint. Complex source
spellings (e.g. `amico/a`) and uncertain category mappings are marked with
`reviewReasons` but **never removed**.

Do **not** assume that generated lookup targets for slash/parenthesis forms
are already correct. Explicit normalizations and variant mappings belong to
M5.3 and should be independently reviewed.

## Source and redistribution

- https://www.unistrapg.it/profilo_lingua_italiana/site/liste_lessicali_a1.html
- Perugia's published page numbers entries 1–486.
- The site's redistribution licence for the structured reference list is
  not established. Keep output private under `catalogs/local/`, ignored by Git.
- The small test examples in this repository are illustrative only.

## Build and import on XPS

```sh
dub test --compiler=dmd
dub test --compiler=ldc2
dmd -i -I=source examples/import_perugia.d -of=/tmp/import-perugia
mkdir -p catalogs/local
/tmp/import-perugia /tmp/perugia-it-A1.html catalogs/local/it-A1-perugia.json
```

The importer fails if it does not detect exactly 486 numbered entries in
strict source order, or if the output does not conform to the existing
catalogue parser. It does not create an incomplete catalogue as a successful
result. Inspect `reviewReasons` to prepare M5.3.

## Acceptance criteria

- DMD 2.111.0 and LDC 1.41.0 unit tests pass.
- Import from saved HTML reports `SOURCE ROWS: 486` and `CATALOG ENTRIES: 486`.
- Positions 1 and 486 exist; all positions 1..486 are unique and ordered.
- `piacere` retains both noun and verb lookup categories; `nero` retains
  adjective category; source `amico/a` is preserved as written and marked
  for review rather than silently rewritten.
- No Wikidata coverage number is implied by importing reference vocabulary.
