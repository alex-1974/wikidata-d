# wikidata-d

GUI-independent D library for working with Wikidata entities, Lexemes, Forms, Senses, and evidence-based multilingual grammar research.

**Status:** active research/development through **R1.11-D1**. This is not a released vocabulary-trainer application, and the research classifiers do not authorize grammatical construction or automatic word-form selection.

## What is implemented

- **Wikidata access:** SPARQL SELECT/ASK queries and `wbgetentities` fetching of Q/L/P entities, preserving the original JSON (`wikidata.client`, `wikidata.query`).
- **Lexical models:** typed, lossless Lexeme/Form/Sense views, grammatical features, form representations, and lexical relations (`wikidata.lexeme` and related modules).
- **Independent vocabulary catalogues:** language- and CEFR-level-neutral source catalogues and separate mapping/coverage results. Perugia import and normalization are research components; external reference lists are **not** silently changed or reduced when Wikidata lacks a match.
- **Evidence-based grammar research:** original statement witnesses, typed expressions and bindings, conservative Q-item dimension candidates, and the R1.11-D1 semantic facet review contract (`wikidata.grammar_evidence`, `grammar_expression`, `grammar_binding`, `grammar_dimension`, `grammar_facet`).
- **Declarative research contracts:** existing grammar-contract experiments evaluate stated conditions over attested Forms; they do not synthesize Forms or infer a language's grammar from unchecked ontology links.

The R1.11-D1 facet contract is **evidence-only**. Even a reviewed facet does not permit grammar production, composition, or Form selection. Missing data stays unknown; original Q/L/P IDs, Form identities, statement IDs, and source provenance must remain distinct.

See [R1.11-D1](docs/R1-11-D1-FACET-CONTRACT.md), [R1.11-B](docs/R1-11-B-Q-ITEM-DIMENSION-CLASSIFIER.md), and the other [research notes](docs/).

## Build and offline tests

Requirements: DMD **2.111.0** or LDC **1.41.0** (baseline), DUB, a C compiler/linker, and **libcurl development headers/library** (for example `libcurl4-openssl-dev` on Ubuntu).

```bash
git clone https://github.com/alex-1974/wikidata-d.git
cd wikidata-d
git switch develop

dub test --compiler=dmd --force
dub test --compiler=ldc2 --force
dub build --build=release --compiler=dmd --force

python3 tools/r1_11b_reference.py
python3 tools/r1_11b_graph_inventory.py --self-test
```

The Python checks use checked-in research fixtures; `dub test` is intended to run without live Wikidata requests. The existing `examples/lookup.d` example performs **live** requests and is deliberately **not** run by CI.

A real, identifiable application User-Agent with a contact address/URL is required before any live Wikidata requests. Respect Wikidata rate limits, API usage rules, and the Query Service's timeout/usage policies.

## Basic client example

```d
import wikidata.client;

auto client = WikidataClient(
    "my-vocabulary-project/0.1 (https://YOUR-REAL-CONTACT)");
auto entity = client.getEntity("L5577"); // Original Wikibase JSON entity
auto results = client.findLexemes("it", "Q652", ["gatto", "nero", "andare"]);
```

The example makes network requests when executed; its User-Agent contact URL is a placeholder and must be replaced.

## Source-of-truth policy

- Complete A1/A2/etc. reference catalogues are stored and versioned independently of Wikidata coverage, with their original source metadata and applicable rights information.
- Lexical content for the Wikidata-backed trainer comes from **attested Wikidata Lexemes, Forms, Senses, statements, and representations**, not locally invented fillers.
- Catalogue-to-Wikidata associations and their matching status are kept in a separate layer.
- Absence of evidence is **not** negative evidence. A Q-item classification or an ontology relationship alone is **not** a licensed grammatical production rule.
- Research hypotheses, quarantined ontology anomalies, and source snapshots must remain distinguishable from approved application behavior.

## Branches and continuous integration

- **`develop`** – active development; [CI workflow](.github/workflows/ci.yml) runs offline tests and release builds with DMD 2.111.0 and LDC 1.41.0.
- **`main`** – release branch; [release gate](.github/workflows/release-gate.yml) targets pull requests and pushes to `main` with the supported DMD/LDC compiler matrix. Changes should be reviewed and gated before merging.
- No release or production grammar approval is implied by a passing CI build.

[Set up a working copy](LOCAL_SETUP.md).

## Upstream references

- [Wikidata Query Service](https://www.mediawiki.org/wiki/Wikidata_Query_Service/User_Manual)
- [Wikibase API](https://www.mediawiki.org/wiki/Wikibase/API)
- [D std.net.curl](https://dlang.org/library/std/net/curl.html)
