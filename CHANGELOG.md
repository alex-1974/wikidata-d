# Changelog

Public GitHub releases: v0.1.0 (BSL-1.0) and v0.1.1 (MIT).

## [Unreleased]

- Clarified the released version and the boundary with Tessera.

## [0.1.1] — 2026-10-17

- Added the opt-in Blazegraph lemma-first SPARQL query strategy (PR #43).
- Adopted MIT for v0.1.1 while preserving the historical v0.1.0 license.
- Preserved original v0.1.0 function signatures and function-pointer types;
  exposed optimization through separately named APIs (PR #46).
- Published at `bb56ba1db89906c190e2d0f79da45f4647a53082` after release PR #45.

## [0.1.0] — first GitHub release (BSL-1.0)

- Added a lean ten-module D library for SPARQL query construction, Wikidata
  client access, Lexeme/Form/Sense parsing, independent vocabulary catalogues,
  candidate matching, category evidence, coverage, relations and batch cache.
- Preserved independent source catalogue contents and original Wikidata JSON;
  no invented lexical data or implicitly verified translations.
- Recorded an internal source-API compatibility baseline (17 types,
  34 callable declarations and 75 fields). This is not a binary ABI guarantee.
- Added API-adjacent offline Ddoc examples and generated DDOX documentation
  published through GitHub Pages.

The signed `v0.1.0` tag and its GitHub release remain immutable.
No DUB registry publication is asserted here. The internal API-freeze tag
is separate from public release tags.
