# R1.14-K — Vorschlag zur Stabilisierung der öffentlichen Source-API

**Status: ENTWURF – NICHT GENEHMIGT; KEIN API-FREEZE; KEIN RELEASE.**
**Stand:** 2026-10-15 · **Produktionsbasis:** `4b015aa9deec48dd9d5045b0633037b919c90e76` (`develop`) · **Research-Belege:** `1ac237aa3453eacc6f3b06cb87c2c5384dd5055a`.

Dieser Text ist eine zu prüfende Kompatibilitätsrichtlinie. Er verändert **keine** bestehende API, erzwingt noch keine zukünftige Versionsgarantie und ersetzt nicht die separate Freigabe des API-Freeze. Die tatsächlichen Source- und Release-Gates sind in den Repository-Workflows maßgeblich.

## 1. Ziel und überprüfter Umfang

`wikidata-d` soll als kleine D-Bibliothek auch künftig ohne Research-Code, GUI- oder Grammatik-Synthese genutzt werden. Nach dem R1.14-I-Review umfasst der überprüfte öffentlich importierbare Bestand genau **zehn Module**, **16 `struct`-Typen**, **ein `enum`**, **28 Modulfunktions-Signaturen einschließlich Überladungen**, **sechs Methoden/Konstruktoren** und **75 öffentliche Datenfelder**. Insgesamt: **17 Typen, 34 aufrufbare Signaturen, 75 Felder**. Dies sind revisionsgebundene Bestandszahlen und **keine** generelle Aussage, dass ein Textsuche-Verfahren beliebige zukünftige D-Symbole zuverlässig erfasst.

Verbindlicher Inventar-Beleg für den Vorschlag ist das manuell geprüfte [`API_SURFACE_MANIFEST.json`](https://github.com/alex-1974/wikidata-d-research/blob/3fdcdf6320147039d9f18d0506715a7ed6d7fcf6/experiments/r1_14i_public_api_review/API_SURFACE_MANIFEST.json) mit der zugehörigen [Auswertung](https://github.com/alex-1974/wikidata-d-research/blob/3fdcdf6320147039d9f18d0506715a7ed6d7fcf6/experiments/r1_14i_public_api_review/API_SURFACE_REVIEW.md). Das Inventar wird **nicht** als Laufzeitabhängigkeit nach `source/` übernommen. Die bestehenden [Ownership- und Cache-Verträge](API_CONTRACTS.md) gelten zusätzlich.

## 2. Zwei unabhängige Kompatibilitätsebenen

**S: öffentliche D-Quellform (empfohlener Freeze-Umfang).** Nach einer gesonderten Freigabe bleiben alle bereits importierbaren Modul-/Typ-/Funktionsnamen, Überladungen, Parameterarten (`ref`, `out`, `const`), zulässigen Standardargumente, Rückgabetypen, Enum-Werte und öffentlichen Struct-Felder **quellkompatibel**. Auch bisherige Hilfsfunktionen und Legacy-Felder sind Teil dieser Oberfläche. Öffentliche Struct-Felder werden nicht stillschweigend entfernt, privat gemacht oder umbenannt. Änderungen an Typ-/Feldlayout, die bestehende Quell-Consumer brechen können, werden als Breaking Change behandelt. Die Prüfung ist eine **Source-API-Zusage für festgelegte Compiler**, keine binäre ABI- oder Bibliotheksdatei-Kompatibilität zwischen Compilern/Builds.

**B: fachliche Semantik (nur im dokumentierten Rahmen).** Von unveränderten Namen ist kein unbegrenztes Verhalten abzuleiten: Garantiert werden dürfen nur die ausdrücklich dokumentierten Invarianten und die überprüften Eingabe-/Fehlerverträge. Wikidata und externe Quellen sind dynamisch. Die generierten SPARQL-Textbytes sind nicht als zeitlich unveränderlich zugesagt; ein Cache-Schlüssel vergleicht aber immer den tatsächlich übergebenen Query-Text **bytegenau**.

Diese Trennung erlaubt interne Optimierungen und neue, qualifizierte Features, ohne die Bedeutung der bestehenden API stillschweigend zu ändern.

## 3. Vorgeschlagene Moduleinstufung

| Modul | Source-Form nach Freigabe | Fachlich zugesicherter / begrenzter Vertrag |
|---|---|---|
| `wikidata.catalog` | **S** einschließlich `CatalogEntry.lookupLemmas`, `lookupTargets`, `raw` und beider `parseCatalog`-Überladungen | Vollständige, geordnete externe Referenzkataloge unabhängig von Wikidata-Abdeckung; keine implizite Deep-Copy. |
| `wikidata.lexeme` | **S** einschließlich `readStatements`, aller `raw`-Felder und beider `parseLexeme`-Überladungen | Original-IDs/ unbekannte Originalfelder bleiben erhalten; Lexeme, Forms und Senses bleiben getrennte Identitäten. |
| `wikidata.catalog_matcher` | **S** mit `CatalogMatchStatus` und `matchMethod` | Kandidaten/Ambiguität, POS je Suchziel, Exact-vor-Subclass, Katalogreihenfolge und Fail-Closed bei unvollständigen Antworten. |
| `wikidata.coverage` | **S** einschließlich `CoverageReport` und `coverageJson` | Reports verändern nie den Katalog; `noLemmaHit` und `posMismatch` gelten **nur** relativ zu den geprüften Antworten. |
| `wikidata.query` | **S** einschließlich `isEntityId` und `sparqlString` | SPARQL-Literale/IDs validieren; **kein** dauerhafter Bytevertrag für die komplette generierte SPARQL-Abfrage. |
| `wikidata.client` | **S** einschließlich aller zugänglichen `WikidataClient`-Felder und Methoden | Ehrlicher User-Agent; Endpunkte/Timeouts sind konfigurierbar; keine Garantie über externe Server, Erreichbarkeit oder alle HTTP-Fehlerarten. |
| `wikidata.form_lookup` | **S** einschließlich `isFormId` und Form-Bericht | Formen sind **Kandidaten**, keine automatisch bestimmten Lexeme/Senses; verschiedene Lexeme/Forms werden nicht zusammengelegt. |
| `wikidata.relations` | **S** einschließlich `isSenseId`, Relationstyp/-richtung | Beziehungen behalten Eigenschaft, Quelle und Richtung; LIMIT und SPARQL-Abdeckung erlauben **keinen** Vollständigkeits- oder Übersetzungsgarantieschluss. |
| `wikidata.lexical_categories` | **S** einschließlich `CategoryCompatibility.add`/`compatible` | Kompatibilität ausschließlich aus vorhandenen Wikidata-P279-Beziehungen; keine regelbasierte Grammatikproduktion. |
| `wikidata.batch_cache` | **S** einschließlich `validateBatchResponse`, Envelope- und Dateifunktionen | Lokaler **Single-Writer**-Cache mit exaktem Query-Text; keine Crash-Durability, parallele Schreibersicherheit oder allgemeine Integritätsgarantie. |

**Wichtig:** `S` bedeutet hier **geplant für eine spätere Source-API-Freigabe**, nicht „bereits eingefroren“. Kein öffentliches Feld wird dadurch privat oder aus der API entfernt. Die private Implementierung (z. B. das Feld `CategoryCompatibility.ancestorsByCategory`) gehört nicht zur S-Oberfläche.

## 4. Beobachtbare Daten- und Fehlerverträge

- **Quelle und Mapping bleiben getrennt.** Sprache und Lernniveau gehören zu unabhängig gepflegten Referenzkatalogen; ein Wikidata-Miss verkleinert nie den Katalog. R1.14-D nutzt 480 historisch aus Wiktionary abgeleitete Einträge und ist **kein** vollständig nachgewiesener italienischer A1-Katalog. Fehlende Lexeme/Forms/Senses werden nicht erfunden oder grammatisch ergänzt.
- **IDs, Mehrdeutigkeit und Originaldaten bleiben erhalten.** Ein Form-Treffer ist kein geprüfter Sense- oder Übersetzungstreffer; die zwei Form-IDs für `glutei` aus dem echten R1.14-G-Capture müssen getrennt bleiben. Auch unerkannte Wikidata-Aussagen und Felder sollen in `raw` verfügbar bleiben.
- **Gültiger leerer Treffer ≠ Fehler.** Parsen, Matchen und Coverage müssen unvollständige/fehlerhafte Eingaben als Fehler behandeln; ein erfolgreiches Resultat ohne Bindings beweist nicht, dass Wikidata weltweit keine entsprechenden Daten besitzt. Exakte Exception-Nachrichtentexte sind nicht eingefroren.
- **Beobachtbare Schemata werden versioniert.** `schemaVersion == 1` der Katalog-/Coverage-/Form-Report-Formate, `CatalogMatchStatus`-Werte sowie publizierte Strings wie `matchMethod`, `direction` und Reportstatus sind fachliche Verträge. Eine Bedeutungsänderung, Umbenennung oder Entfernung erfordert eine dokumentierte Schema-Migration; Zusatzfelder müssen kompatibel behandelt werden.
- **JSON-Ownership bleibt beschränkt.** D-Strukturkopien und `JSONValue.raw` sind keine unabhängigen Deep-Copies. Verwendete Objektgraphen sind nach dem Parsen logisch unveränderlich; parallele Mutationen sind nicht abgedeckt.
- **Cache-Gültigkeit ist eng.** Der Query-Mismatch liefert `false`, bevor der gespeicherte Response-Body validiert wird. Ein strukturell beschädigter Response-Body mit **passendem** Query ist ein Fehler. Eine feste `.tmp`-Datei und `rename` sind keine Transaktion mit garantierter Persistenz.
- **Kein Fixieren externer Datensätze, Ressourcenlimits oder Abfragepläne.** API-Stabilität bedeutet weder feste Wikidata-Abdeckung noch feste Query-Reihenfolge/-Bytes, identische Online-Ergebnisse, garantierte Leistung oder einen hardwareunabhängigen Peak-RSS-Grenzwert.

## 5. Change-Control bei einer später freigegebenen Source-API

1. **Interne Änderungen:** dürfen ohne öffentliche Signaturänderung erfolgen, sofern alle dokumentierten Daten-/Fehlersemantiken erhalten bleiben und die Regressionstests/qualifizierten realen Workloads bestehen. Research-Artefakte bleiben außerhalb der zehn D-Release-Module.
2. **Additive öffentliche API:** neue Namen/Felder nur nach Designreview mit Kompatibilitätsprüfung, DMD/LDC-Consumer-Test und Aktualisierung des Inventars; keine implizite Aussage über neue Features aus dem API-Freeze.
3. **Breaking Change:** Entfernen/Privatisieren/Umbenennen öffentlicher Elemente, inkompatible `ref`-/`out`-/`const`- oder Default-Argument-Änderungen, inkompatible Feldänderungen sowie Wechsel bestehender Schema-/Enum-/Stringbedeutungen nur nach eigenem Issue, dokumentiertem Migrationspfad und bewusster Entscheidung über die nächste **Versionsepoche**. Nicht stillschweigend in einem Optimierungs-PR.
4. **Externe Änderungen:** Versions- und Änderungenachweis für SPARQL-/Wikidata-Schemaanpassungen; bei verändertem Query-Text kann ein neuer Cache-Key entstehen. Kompatibilität bezieht sich auf das API-Versprechen, nicht auf unveränderliche HTTP- oder WDQS-Rohdaten.
5. **Tests:** vor jedem relevanten API-Change prüfbarer Source-Inventar-Diff sowie DMD 2.111.0/LDC 1.41.0, Release-Builds, externer DUB-Consumer und sieben Beispiele (nur kompilieren, wenn sie online zugreifen). Echte, unveränderte offline Wikidata-Replays für Semantik-/Performanceänderungen. Empirische Laufzeit-/Speicherbehauptungen immer mit Betriebssystem, Compiler, Datensatz und Scope angeben.

## 6. Separates Freeze- und Release-Gate (noch nicht ausgeführt)

**API-Freeze-Gate, später auf einem exakten Commit:** Vorliegen des vollständigen Inventars, unterzeichnete Entscheidung über `S`/`B`-Umfang und Schema-Verträge, bestandene Fast-CI auf `develop`, geprüfter unabhängiger Consumer und alle sieben Beispiele unter beiden Baseline-Compilern, Originaldaten-Fingerprints/Fail-Closed-Negativfälle, Peer-Review des Git-Diffs, Freigabe des abgegrenzten Speicher-/Performance-Nachweises sowie eine **explizite Versionierungsentscheidung**. Erst danach darf ein **signierter, eindeutig benannter interner API-Freeze-Tag** für die gewählte Commit-SHA geplant werden. Diese Datei legt weder Tagnamen noch SemVer-Version automatisch fest.

**Release-Gate getrennt:** Promotion nach `main` durch PR und die bestehenden sechs Compiler-Gates: DMD **2.111.0 / 2.112.1 / 2.113.0**, LDC **1.41.0 / 1.42.0 / 1.43.0**. Release-Tag, DUB-Version, DDOX und Distribution bedürfen späterer Entscheidungen; ein grünes API-Freeze-Gate ersetzt den Release-Gate nicht.

## 7. Gegenwärtiger Entscheidungsstatus

**Belege bereits akzeptabel für einen Vorschlag:** R1.14-I hat die 17/34/75-Surface auf dem fixierten Produktionscommit unter DMD/LDC mit externem DUB-Consumer und 14 Beispiel-Builds qualifiziert. R1.14-J hat an 40 unabhängigen XPS-Prozessen für die historische reale 480/453-Coverage-Arbeitslast die Whole-Process-RSS-Mediane reproduziert; bei 50 Aufrufen DMD **44.728 → 44.204 KiB**, LDC **43.740 → 43.184 KiB**. GC-Allokationsvolumen und Peak RSS sind verschiedene Größen. Diese Beobachtungen sind **keine** generelle Hardware-/Speicher-/ABI-Garantie.

**Offen und explizit durch Maintainer zu akzeptieren:** (a) gesamtes bestehendes Source-Shape-Inventar einschließlich Legacy-/Hilfsfunktionen als Kompatibilitätsgrenze oder bewusst versionierte Breaking-Bereinigung; (b) konkrete Versionslinie und Start-SHA der Zusage; (c) Laufzeit der Unterstützung und Änderungs-/Migrationstaktik; (d) tatsächlicher Freeze-Tag auf der freigegebenen Revision. Bis dahin: **NICHT GEFROREN**.

**Referenzen:** [Produktions-Issue #16 (R1.14-K)](https://github.com/alex-1974/wikidata-d/issues/16), [API-Inventar #15](https://github.com/alex-1974/wikidata-d/issues/15), [Freeze-Hauptgate #10](https://github.com/alex-1974/wikidata-d/issues/10), [Research R1.14-J #16](https://github.com/alex-1974/wikidata-d-research/issues/16).
