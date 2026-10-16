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

## Using wikidata-d

This is a DUB library, not a command-line program. Add it as a dependency
in your DUB project after an actual package release, or use a local
path-based DUB dependency during development. The package is **not yet**
announced as published to the DUB registry.

A small offline consumer example:

```d
import wikidata.query : buildLexemeQuery, isEntityId;
import wikidata.catalog : parseCatalog;

void main()
{
    assert(isEntityId("Q652"));
    auto catalog = parseCatalog(`{"schemaVersion":1,"id":"it-A1",
        "languageCode":"it","languageEntityId":"Q652","level":"A1",
        "source":{},"entries":[{"id":"1","lemma":"gatto"}]}`);
    assert(catalog.entries.length == 1);
    auto sparql = buildLexemeQuery("it", "Q652", ["gatto"]);
    assert(sparql.length != 0); // Query text only; no HTTP request.
}
```

API documentation: https://alex-1974.github.io/wikidata-d/

Wikidata responses and network access are separate from independent source
catalogues. A Lexeme/Form/Sense candidate does not prove a translation.

## License

Current development and future releases (subject to release approval): MIT.
See [LICENSE](LICENSE). The already published `v0.1.0` tag and GitHub
release remain historically distributed under BSL-1.0; see the
[original Boost license](LICENSE_1_0.txt).

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

## Ddoc rendering

The repository's `docs/ddoc/macros.ddoc` defines `$(D ...)` for
offline DMD Ddoc generation. Use the repeatable renderer:

```sh
python3 tools/build_ddoc.py --repo . --out /tmp/wikidata-ddoc-html
```

This is a DMD Ddoc rendering gate, **not** a DDOX or GitHub Pages
qualification. API changes and network calls are not part of this build.

## Development acknowledgement

Assisted by AI.

The library has been developed and reviewed with assistance from multiple AI
systems and models. API compatibility, source correctness and release decisions
remain subject to maintainer review and the repository's verification gates.
