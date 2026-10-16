# API contracts: ownership, error behavior and batch checkpoints

**Scope:** `wikidata-d` R1.14, production baseline
`858cdd3c28e38939ff0ba5fc76ecd1bc02da2f72`.
This documents the **current, bounded behavior**, not a public API/ABI freeze.
The authoritative source is `source/wikidata/`; any broader guarantee requires
separate tests and an explicit design decision.

## Source catalogues and lexical data are separate

A `VocabularyCatalog` represents a complete external reference catalogue.
Its source entries, order, spelling, POS/source metadata and level are not
filtered, shortened, replaced or supplemented as a consequence of Wikidata
lookup results. Mapping and coverage live in separate results. A `noMatch`
means **no matching candidate in the supplied successfully validated
responses**, not that Wikidata contains no lexical information, and never that
a reference entry should be removed. No Lexeme, Form or Sense is synthesized.

## Memory ownership: shared, logically immutable graphs

`parseCatalog(JSONValue)` and `parseLexeme(JSONValue)` retain original JSON in
`raw` fields. The returned typed values and their `raw` fields are **not
promised to be independent deep snapshots** of their input. D arrays and JSON
object/array storage may be shared across value copies. In particular:

- `CatalogEntry.raw` shares mutable underlying JSON data with the parsed
  source in tested cases. `VocabularyCatalog.raw` and `source` also retain
  original source data; **do not presume deep copying**.
- `WikidataLexeme.raw` and `WikidataForm.raw` share underlying parsed JSON
  data in tested cases. The same conservative no-deep-copy rule applies to
  other `raw` members, including Senses and statements.
- Copying `VocabularyCatalog` by D struct assignment shares its `entries`
  backing array; copying a containing struct or array slice is not a deep
  clone. Immutable D `string` characters do not make the enclosing
  collections or `JSONValue` object graph immutable.

**Consumer rule:** Treat a source JSON graph, its typed views, the associated
`raw` fields and collection slices as **logically immutable after parsing**.
Do not mutate them through any alias. Mutating raw JSON can leave previously
extracted typed fields inconsistent; mutating a shallow copy can alter the
original. For an independent mutable graph, explicitly construct/reparse an
independent representation and validate that method for the desired nested
fields. There is intentionally **no implicit recursive clone**, allocation
budget or deep-copy guarantee.

D's GC retains reachable managed storage; this is not a promise that a
consumer can manually free or mutate referenced buffers safely. Concurrent
mutations or reads racing with mutations have **no supported synchronization
contract**. Coordinate ownership and synchronization at the application
boundary.

## Errors, complete replies and missing-data semantics

- Parsers and matching routines use exceptions to reject malformed input.
  An exception is **not** an empty list of Wikidata results. Callers must
  propagate/handle failures separately from successful zero-binding replies.
- `matchCatalog` and `buildCoverageReport` require one successful response
  for each specified batch and validate the complete response sequence
  before producing the report. A malformed *later* response must not become
  an inferred `noMatch` for the missing batch.
- `parseFormLookupResponse` accepts only requested representation strings,
  well-formed Lexeme/Form/category identifiers and correctly owned Forms.
  Distinct Form IDs for the same written word remain distinct candidates.
  Repeated `(word, formId)` pairs preserve the first candidate in response
  order. This is candidate discovery, **not** a semantic Lexeme/Sense match.
- Completeness is relative to the actual input response set, query text,
  retrieval time and source; a WDQS batch with zero bindings is not proof
  of worldwide/long-term absence in Wikidata.

## Batch cache: one writer per checkpoint path

`wikidata.batch_cache` checkpoints one successful SPARQL JSON envelope keyed
by the **exact query-text bytes** (`schemaVersion == 1`). Its interface is a
small local convenience cache, **not** a concurrent or crash-durable store.

- `saveCachedBatch(path, query, response)` rejects an empty query or an
  envelope without `results.bindings` as an array, *before* writing. It then
  writes to the fixed `path ~ ".tmp"` and calls `rename` to replace `path`.
  It does not validate every lexical binding; downstream matching/parser
  functions must still perform semantic validation.
- `loadCachedBatch(path, query, out response)` returns `false` for a missing
  checkpoint file or a checkpoint whose validated envelope header contains
  **nonidentical** query text. Callers must not use the `out` value when the
  return value is false. With an exact query match, malformed/missing response
  structure is an **error**, not a zero-result Wikidata reply. Truncated or
  invalid JSON, unreadable files, unsupported schema and invalid query-header
  fields also raise. Importantly, a query-text mismatch returns `false`
  **before validating the saved response body**; it is not a comprehensive
  integrity check of an unrelated cache entry.
- Writers must be **serialized externally per path**; a fixed `.tmp` name
  can collide or overwrite existing staging files. Do not share a checkpoint
  path between independent concurrent writers. No documented guarantee is
  made for racing readers and writers.
- There is **no guaranteed fsync**, process-crash recovery, cross-filesystem
  transaction, cross-platform atomic replacement, multi-process locking,
  time-to-live, freshness check or content-authentication mechanism.
  The rename step alone is not a durable-transaction guarantee. An existing
  stale `.tmp` may be overwritten. The caller controls checkpoint location,
  synchronization, file permissions and recovery policy.

The choice of a bounded single-writer contract avoids adding locking or
allocation-heavy copying to the small production core. If stronger cache
semantics become necessary, qualify them separately and revise this
contract explicitly before changing the implementation.

## Evidence and API-freeze boundary

- XPS contract observation: `wikidata-r1-14-ownership-cache-xps-20261015T070740Z.tar.gz`,
  SHA-256 `1bcde92e68f3cbdbcbeacdded251063c13028df04cbba664b7be0a0e7696a031`;
  12/12 archived file hashes and DMD 2.111.0 / LDC 1.41.0 observations
  agree. Tested: raw/catalog array aliases, round trip, exact query identity,
  invalid-save preservation, malformed checkpoint rejection, stale `.tmp`
  overwrite. This **does not** prove all nested alias graphs or crash safety.
- Production Git blobs for `catalog.d`, `lexeme.d` and `batch_cache.d`
  are unchanged between the experimental production pin `e75b4d0` and the
  scope pin `858cdd3`.
- Authentic WDQS Form capture and parser replay live only in the separate
  Research repository; 12 actual Form candidates and eight synthetic
  malformed-input cases passed under both compilers. The larger 2,000-row
  Form benchmark is **synthetic**, not proof of a common real workload.
- See [production issue #10](https://github.com/alex-1974/wikidata-d/issues/10),
  [ownership/cache issue #12](https://github.com/alex-1974/wikidata-d/issues/12)
  and [Research Form issue #12](https://github.com/alex-1974/wikidata-d-research/issues/12).

**Freeze state: NOT frozen.** The document states explicitly bounded contracts
proposed for adoption. Public API freeze requires separate sign-off and CI.
