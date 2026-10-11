# wikidata-d – M1 research client

Minimal, GUI-independent Wikidata client written in D.

## Scope

- Execute arbitrary SPARQL SELECT/ASK queries through Wikidata Query Service (JSON result).
- Generate exact-match lexeme queries from BCP-47-style language codes, Wikidata language IDs, lemmas and an optional lexical-category Q-ID.
- Fetch a full Wikidata Q/L/P entity using `wbgetentities` (JSON value).
- Keep all unmodified Wikidata fields in the returned JSON.

Not included in M1: automatic language-Q-ID resolution, persistence, retry/backoff, background execution, typed Wikidata L-F-S models, bidirectional relationships, `P9970` or `P5972` graph expansion, pagination, or GUI.

## Requirements

- DMD 2.111 or LDC 1.41 (target baseline; **not compiled in the generating environment**).
- DUB, libcurl developer library, and internet connectivity for live smoke tests.
- Proper identifying User-Agent. Replace the `example.org` contact URL before making live requests.

## Build and test

```bash
dub test

dmd -i -I=source examples/lookup.d -L-lcurl -of=lookup
./lookup
```

`dub test` exercises the query-building code without network access. The example calls Wikidata live. It must not be run until the User-Agent is changed to a real project contact.

## Public API (M1)

```d
import wikidata.client;
auto client = WikidataClient("my-vocabulary-project/0.1 (https://MY-REAL-CONTACT)");
auto results = client.findLexemes("it", "Q652", ["gatto", "nero", "andare"]);
auto entity = client.getEntity("L5577");
auto raw = client.query("SELECT * WHERE { wd:Q146 ?p ?o } LIMIT 10");
```

`query` returns the SPARQL JSON result; `getEntity` returns the entity object from `entities[ID]`. No Wikidata data is stored or discarded at this layer.

## Synchronization principle

A1/A2 catalogues are complete and independently versioned. Matching status and entity IDs live in a separate mapping layer. Wikidata source data may be missing or incomplete and are *not* overwritten by local translations. All available Forms, Senses and claims should be preserved when storing entities in a later milestone.

## Production considerations for M2+

- Add structured HTTP errors and bounded retries honoring `Retry-After` for HTTP 429/5xx.
- Prefer small, cacheable GET requests; use POST for long SPARQL requests.
- Never block the dcanvas GUI thread on network calls.
- Add request size limits, metrics, request scheduling, and incremental synchronization.
- Use record/replay HTTP fixtures for reproducible integration tests.
- Respect Wikidata WDQS time and rate limits.

Official documentation:
- https://www.mediawiki.org/wiki/Wikidata_Query_Service/User_Manual
- https://www.mediawiki.org/wiki/Wikibase/API
- https://dlang.org/library/std/net/curl.html

## Local repository

The initial Git repository uses the `develop` branch and does **not** configure
any GitHub remote. See [LOCAL_SETUP.md](LOCAL_SETUP.md) to restore the portable
Git bundle at `/home/alexander/Programmiersprachen/dlang/wikidata-d`.
