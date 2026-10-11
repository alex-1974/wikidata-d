# M5.1 – Independent reference catalogues with variant/POS-aware lookup

## Verified Italian A1 source

- Perugia `Profilo della lingua italiana`, lexical list for A1.
- Public page numbers entries **1 through 486**.
- The printed source includes a lemma/display form, sequence number and a
  grammatical abbreviation. It does not provide Wikidata IDs.
- Source: https://www.unistrapg.it/profilo_lingua_italiana/site/liste_lessicali_a1.html
- Bibliographic reference: Spinelli, B. and Parizzi, F. (2010), *Profilo della
  lingua italiana. Livelli di riferimento del QCER A1, A2, B1, B2*.

The source does not visibly identify an open licence permitting redistribution
of the entire structured list. **Do not commit a complete extracted copy or
ship it with application packages until rights are clarified.** The small
`it-A1-structure-demo.json` is an illustrative schema fixture only.

## Schema: one immutable original row, many lookup targets

A source record has a stable catalogue-local `id`, its source `lemma`,
source position and original POS annotation. None of these are derived
from Wikidata. Optional `lookupTargets` contains pairs of:

- `lemma`: the exact orthographic string to search in Wikidata.
- `lexicalCategoryId`: optional Wikidata Q-ID limiting that particular query.

When `lookupTargets` is absent, the M4 `lookupLemmas` and
`lexicalCategoryId` rules remain unchanged. `lookupTargets` and
`lookupLemmas` are mutually exclusive. The original record and its
unrecognized metadata are kept in `CatalogEntry.raw` and
`VocabularyCatalog.raw`.

Special cases from the source include `amico/a` (gender variants),
`piacere` (verb + noun), `aereo(aeroplano)` (written alternatives) and
`chiamare/si` (verb and pronominal form). No universal text rewriting
should infer all variants; a language-specific research/import phase
should produce explicit candidates and preserve the original source.

### Important semantics

- `catalog entries` = source rows, never reduced by Wikidata lookup.
- `lookup targets` = one or more search intents per original row.
- `matched lexemes` = 0..N distinct Wikidata Lexeme entities.
- `Senses` and related Q-items remain Wikidata-sourced.
- `multipleCandidates` reflects cardinality, **not** an automatic error:
  several results may be intended due to POS or orthographic alternatives.
- Any misses from *failed* network requests are errors, not `noMatch`.

## Acceptance gates

1. Legacy M4 schema and tests remain valid.
2. New catalogue variants yield correct query batches with deduplicated
   orthographic values.
3. `piacere` matches verb and noun Lexemes without splitting its source row.
4. `amico/a` matches possible `amico` and `amica` Lexemes.
5. Full source list remains **future work**, after reviewing redistribution
   rights and creating an extraction/verification pipeline.
6. Run DMD 2.111.0 and LDC 1.41.0 tests on XPS; no compiler was
   available in the patch authoring environment.
