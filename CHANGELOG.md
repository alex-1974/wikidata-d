# Changelog

All notable changes will be recorded here when a public release is approved.
The first GitHub release, **v0.1.0**, has been published under BSL-1.0.

## [Unreleased] — preparation for v0.1.1

- Added the opt-in Blazegraph lemma-first SPARQL query strategy (PR #43).
- Prepared the MIT license transition for subsequent releases (Issue #42);
  copyright/provenance review and release approval remain required.

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
