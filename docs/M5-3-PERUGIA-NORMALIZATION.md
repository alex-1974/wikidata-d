# M5.3 — Perugia A1 search-target normalization

## Purpose

This source-specific enrichment creates *lookup targets* for the local 486-row
Perugia Italian A1 catalogue. It **does not change, omit, or translate**
reference rows. The entire Perugia-derived JSON stays local under
`catalogs/local/` while redistribution rights remain unclear.

## Part-of-speech mapping

Verified Wikidata lexical categories:

| Perugia abbreviation | Wikidata lexical category |
|---|---|
| s.m., s.f. | noun Q1084 |
| agg. | adjective Q34698 |
| v.t., v.int. | verb Q24905 |
| avv. | adverb Q380057 |
| pron. | pronoun Q36224 |
| inter. | interjection Q83034 |
| art. | article Q103184 |
| prep. | preposition Q4833830 |
| cong. | conjunction Q36484 |

Multi-category annotations generate distinct targets for each category.
`part. pron. luogo` remains without a category restriction and retains
`pos-mapping-unresolved` because its Wikidata modeling is not yet verified.

**Caution:** Wikidata also uses more specific pronoun categories. Exact
`Q36224` matching is not exhaustive. Later coverage work must distinguish
"no exact POS hit" from "no Italian lexeme" (e.g., with an unrestricted
comparison query and optional lexeme-category normalization). A catalogue
row is never removed because of such misses.

Reference: https://www.wikidata.org/wiki/Wikidata:Lexicographical_data/Documentation/Lexical_categories

## Orthographic search variants

The 17 special spellings reported from the source have explicit expansions
in `perugia_import.d`. The mapping is guarded by **both** source position
and exact original spelling; it does not apply blanket replacements. Examples:

- `amico/a` -> `amico`, `amica`
- `aereo(aeroplano)` -> `aereo`, `aeroplano`
- `bici(cletta)` -> `bici`, `bicicletta`
- `chiamare/si` -> `chiamare`, `chiamarsi`
- `professore/ssa` -> `professore`, `professoressa`
- `poco (po’)` -> `poco`, `po'`, `po’` (both apostrophe glyphs)
- `un/o/a` -> `un`, `uno`, `una`

Original `lemma`, `sourcePosition`, `sourceAnnotation`, `sourceHtml` remain
unaltered. Entries with unrecognized complex spelling continue to carry
`complex-source-lemma`. This is **lookup preparation**, not a claim that each
variant is a separate Wikidata Lexeme (it may be a Form).

## Local verification

Run from the repository root:

```sh
dub test --compiler=dmd
dub test --compiler=ldc2
dmd -i -I=source examples/import_perugia.d -of=/tmp/import-perugia
/tmp/import-perugia /tmp/perugia-it-A1.html catalogs/local/it-A1-perugia.json
```

Expected invariant: `SOURCE ROWS: 486` and `CATALOG ENTRIES: 486`.

For the current 99 flagged rows, most flags should disappear. The locative
pronominal particle should remain flagged; any extra review reasons signal a
source/schema discrepancy and should be inspected, not silently ignored.

Next: M5.4 compares filtered and unfiltered Wikidata lookup results, records
missing lexemes and category mismatches separately, and produces coverage
statistics. No translation validation is implied by a lexical match.
