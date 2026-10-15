# wikidata-d

Small, GUI-independent production D library for Wikidata queries and Lexeme/Form/Sense data.

The production `source/wikidata` directory is deliberately restricted to ten
verified modules: `query`, `client`, `lexeme`, `catalog`, `catalog_matcher`,
`coverage`, `lexical_categories`, `form_lookup`, `relations`, `batch_cache`.

- External CEFR reference catalogues remain complete and independent of
  Wikidata match coverage. Missing Lexeme/Form/Sense data are never invented.
- Research experiments, grammar hypotheses, historical prototypes, and
  frozen original Wikidata snapshots live in the separate private
  `wikidata-d-research` repository; they are not DUB source dependencies.
- The production library makes no grammar synthesis or form-selection claims.
- Full original Lexeme/Form/Sense JSON is retained by `wikidata.lexeme`.

## Build and test

Install DMD 2.111.0 or LDC 1.41.0, DUB, and libcurl dev headers.

```sh
python3 tools/check_release_boundary.py
dub test --compiler=dmd --force
dub test --compiler=ldc2 --force
dub build --build=release --compiler=dmd --force
dub build --build=release --compiler=ldc2 --force
```

The public core API and examples are independent of any Research modules.
The release and develop GitHub workflows enforce this source boundary.

Do not run the live network examples without a real identifying User-Agent.

For the bounded R1.14 memory-ownership, failure and single-writer cache
contracts see [API_CONTRACTS.md](docs/API_CONTRACTS.md). This does **not**
constitute an API freeze.

R1.14-L documents the [internal v0.1.x source-API compatibility decision](docs/API_STABILITY.md). This policy becomes active **only after a separately signed internal API-freeze tag**; it is not a DUB release.

For local setup see [LOCAL_SETUP.md](LOCAL_SETUP.md).

## Development acknowledgement

Assisted by AI.

The library has been developed and reviewed with assistance from multiple AI
systems and models. API compatibility, source correctness and release decisions
remain subject to maintainer review and the repository's verification gates.
