# R1.11-D3-D2 – Verifizierte, schreibgeschützte Evidenzkomposition

**Stand:** 13. Oktober 2026. **Status:** XPS-qualifiziert (DMD 2.111.0 und LDC 1.41.0), Integrations-PR vorgesehen. Keine Grammatikfreigabe.

## Zweck

`wikidata.grammar_evidence_composition` setzt den R1.11-D3-D-Forschungsvertrag um, ohne eine weitere lexikalische Wikidata-Tatsache zu behaupten. Die Komposition vergleicht ausschließlich originale D3-C-Nachweise oder D2-Mitgliedschaften und liefert *Metarelationen* mit beiden unveränderten Original-Statements.

## Source-Gate: keine beliebige `externally_verified`-Behauptung

`verifyOriginalLexemeBytes(originalBytes, expected)` berechnet einen SHA-256-Digest der Originalantwort, verifiziert Lexem-ID, `lastrevid`, Wikibase-JSON-Hülle und die gesamte D3-C-Extraktion. Das Ergebnis `OriginalLexemeReceipt` ist bei Fehlern ungültig; ein Default-Receipt ist kein Beleg. Öffentliche `receiptUsage`, `receiptComponent` und `receiptSemanticArgument` geben Witnesses nur aus verifizierten Receipts zurück. Bei der Komposition müssen diese Witnesses nochmals bitgenau hinsichtlich der ursprünglichen Statement-Inhalte, Form-/Sense-IDs und Qualifikatorergebnisse zum gespeicherten Receipt passen.

**Grenze:** Das Modul beweist kryptografische *Integrität gegenüber dem erwarteten Hash*, aber nicht die **Herkunft** des Netzwerkinhalts von Wikimedia. Abrufweg, Host, Cache-Manifeste und Trust Boundary werden außerhalb geprüft. Eine selbst konstruierte gültige JSON-Antwort mit eigenem Hash wird als intern konsistent akzeptiert, aber ist deshalb noch kein echtes Wikidata-Snapshot. Das ist ausdrücklich kein Ersatz für den D3-A-Originalquellenaudit.

## APIs und Grenzen

- `composeUsages(receipt, usage, receipt, usage)` – bewahrt getrennte Quellen, `sameContextPair`, `sameFormOnly`, `sameSenseOnly`, `parallelEvidence` oder `sameOriginalStatement`.
- `composeUsageForm(receipt, usage, FormAttestation)` – `coIndexedSameForm` nur bei identischem Lexem-Hash und ORIGINAL `grammaticalFeatures`-Q-Merkmal. D2 muss zusätzlich seinen Q-Graph separat attestiert haben; diese Funktion prüft die Q-Ontologie **nicht erneut**.
- `composeUsageSense(receipt, usage, SenseMembership)` – `coIndexedSameSense`, keine universelle Form-Sense-Beziehung.
- `composeUsageArgument`, `composeArguments` – `parallelSameSense` ohne Rollen-, Kasus- oder Satzbauregel.
- `composeComponents`, `composeComponentTarget` – eigenständige `P5238`-Aussagen und Identität eines separat geprüften Ziellexems, niemals produktive Zusammensetzung, `P5548`-Formgültigkeit oder implizite Reihenfolge.

**Invarianten:** `permitsGrammarProduction=false`, `permitsFormSelection=false`, `permitsGeneralFormSenseAssociation=false`. Identische Original-Statements sind keine unabhängigen Mehrfachbelege. Keine Kombination von `L1340`-Teilstatements; diese werden von D3-C bereits korrekt als `partial` gespeichert und tauchen hier nicht als positive Usage-Witnesses auf.

## Qualitätsverfahren

Mit dem gelieferten Skript `--check` zuerst den D3-A-Originalcache, die Original-Statement-Matrix, alle Python-Regressionen und sämtliche Paket-Prüfsummen prüfen. `--run` legt einen isolierten **detached** Worktree auf aktuellem `origin/develop` an, kopiert ausschließlich D3-D2-Modul, Unit-Modul und diese Dokumentation, kompiliert beide D-Compiler, führt `dub test` und Release-Builds aus und vergleicht vier Originalantworten zusätzlich mittels `tools/replay_verified_originals.d` im D-Code.

Der aktive Benutzer-Checkout einschließlich `examples/lookup.d` wird nicht verändert. **Der DMD-/LDC-PASS wurde durch das echte XPS-Ergebnisarchiv bestätigt.**

## Research Daten

Die eingebetteten D-Fake-Lexeme sind ausschließlich synthetisch; der vorherige D3-D-Index ist abgeleitet. Nur das vorhandene XPS-Archiv unter `$HOME/Downloads/wikidata-r1-11d3-source-state` enthält die tatsächlich archivierten Originalbytes.

## XPS-Qualifikation und Integration (13.10.2026)

- Basis: `4355fb82f208452d533c04f1c5225f6804a39900` (`develop`).
- Isolierte DMD- und LDC-Unittests: jeweils **6 Module PASS**.
- Vollständiges `dub test`: bei DMD und LDC jeweils **22 Module PASS**.
- Release-Builds: **DMD und LDC PASS**.
- Echte Originaldaten: **4/4 Lexeme**, **13 Aussagen**, **6 explizite Verwendungspaare**, **2 Komponenten**, **3 semantische Argumente** bestätigt; **keine Grammatikfreigabe**.
- R1.11-B: **11/11 Offline-Regressionen PASS**.
- Die XPS-Prüfung verwendete die unveränderten D-Quelldateien aus dem v3-Paket. Die lokale Änderung an `examples/lookup.d` blieb erhalten.
- Unveränderte SHA-256-Werte: Modul `8da71eaaf5b29f997bd0a8de34f77f2a83bcb32be1e87b2cdf773fdbffcf2a10`, Tests `f31d10fce004a0c845331d4af7b2e77c1cc1ed1a5a824d12d1d5bd7ec6548727`.
- GitHub-CI nach PR-Erstellung und Merge ist ein separates Gate; die lokale Prüfung ersetzt dieses nicht.
