# Changelog

All notable changes will be recorded here when a public release is approved.
The intended first public release is **v0.1.0** (not yet tagged or published).

## [Unreleased] — preparation for v0.1.0

- Added a lean ten-module D library for SPARQL query construction, Wikidata
  client access, Lexeme/Form/Sense parsing, independent vocabulary catalogues,
  candidate matching, category evidence, coverage, relations and batch cache.
- Preserved independent source catalogue contents and original Wikidata JSON;
  no invented lexical data or implicitly verified translations.
- Recorded an internal source-API compatibility baseline (17 types,
  34 callable declarations and 75 fields). This is not a binary ABI guarantee.
- Added API-adjacent offline Ddoc examples and generated DDOX documentation
  published through GitHub Pages.

The first public version number is agreed as **v0.1.0**. The public release
tag, licensing and DUB publication are **not yet authorized or completed**.
The internal API-freeze tag is separate from the public release tag.
