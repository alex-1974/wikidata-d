# Source-API-Kompatibilität: interne Linie v0.1.x

**Stand 2026-10-22: interne Source-API-Kompatibilitätslinie v0.1.x aktiviert.**
Der annotierte interne Tag `api-freeze/v0.1.0` zeigt auf
`94a7c8499806859a90462c99c687c59cc3dff3cc` (R1.14-L-Merge, 2026-10-15).
Er bleibt von den später veröffentlichten GitHub-Releases `v0.1.0` und
`v0.1.1` getrennt. DUB-Registry-Veröffentlichung wird nicht behauptet.

Die vor dem Freeze geprüfte Dokumentationsbasis war
`c573d74ed12fdbd73ed0caac674c77aaab4383f3`, der geprüfte D-Kern
`4b015aa9deec48dd9d5045b0633037b919c90e76`. Der aktuelle veröffentlichte
Release ist `v0.1.1` auf `bb56ba1db89906c190e2d0f79da45f4647a53082`.
Die historische Inventur beschreibt die damalige Basis; additive APIs in
v0.1.1 ändern nicht rückwirkend deren Anzahl.

Diese Richtlinie übernimmt den überprüften Ist-Zustand, statt vor dem Freeze öffentliche Hilfsfunktionen und alte Felder zu entfernen. Der exakte Umfang ist im revisionsgebundenen [R1.14-I-Manifest](https://github.com/alex-1974/wikidata-d-research/blob/3fdcdf6320147039d9f18d0506715a7ed6d7fcf6/experiments/r1_14i_public_api_review/API_SURFACE_MANIFEST.json) erfasst. Die ergänzenden [API-Verträge](API_CONTRACTS.md) gelten unverändert.

## 1. Was wir stabilisieren

Der überprüfte Bestand umfasst **10 D-Module**, **16 öffentliche Structs**, **ein öffentliches Enum**, **28 öffentliche Modulfunktionen inklusive Überladungen**, **6 öffentlich aufrufbare Methoden/Konstruktoren** und **75 öffentliche Felder**. Damit werden die **17 Typen / 34 aufrufbaren Signaturen / 75 Felder** als ursprüngliche Source-API-Kompatibilitätsbasis festgehalten. Die Inventarisierung ist versionsgebunden und manuell geprüft; sie ist kein generischer D-Parser.

Für kompatible Änderungen innerhalb von `v0.1.x` gelten diese Regeln:

- Bestehende Importpfade, öffentliche Typ- und Funktionsnamen, Überladungen, Rückgabetypen, `ref`-/`out`-/`const`-Anforderungen, Default-Argumente, Enum-Namen und zugängliche Struct-Felder bleiben für bestehende D-Consumer benutzbar. Die Kompatibilität muss durch unabhängige Consumer-Builds nachgewiesen werden.
- Dazu gehören bewusst die bestehenden Helfer (`isEntityId`, `isFormId`, `isSenseId`, `sparqlString`, `readStatements`, `validateBatchResponse`, `makeBatchEnvelope`, `decodeBatchEnvelope`), `CatalogEntry.lookupLemmas` sowie die öffentlich veränderbaren `WikidataClient`-Konfigurationsfelder. Ein bloßes `private`-Setzen wäre ein Breaking Change.
- Die vollständigen externen Referenzkataloge bleiben sprach-/niveauneutral und unabhängig von der Wikidata-Abdeckung; Reihenfolge, Wortlaut, Metadaten und ursprüngliche Quelle werden durch ein Mapping nicht verändert. Eine Quelle ohne Wikidata-Treffer bleibt Teil des Katalogs.
- Wikidata-Q/L/P-/Form-/Sense-Identitäten, Mehrdeutigkeiten, originale `raw`-Daten und unbekannte Felder bleiben erhalten. Ein Form-Treffer ist nur ein Kandidat, **kein** automatisch bestätigter Lexeme-/Sense-/Übersetzungstreffer. Wir erzeugen keine fehlenden Lexikaldaten oder Formen.
- Validierte leere Antworten bleiben von Parser-, Netzwerk- und unvollständigen Batchfehlern unterscheidbar. Der dokumentierte Vorrang exakter POS-Treffer, Katalogreihenfolge und Statusbedeutungen bleibt erhalten.
- Bestehende JSON-Schema-Versionen (`schemaVersion == 1`), veröffentlichte Status-/Methoden-/Richtungswerte und Enum-Bedeutungen werden nicht stillschweigend umdefiniert. Ein inkompatibler Wechsel bedarf expliziter Schema-Versionierung und Migration.

## 2. Was wir ausdrücklich NICHT garantieren

- **Keine binäre ABI** über Compiler, D-Versionen, Architektur oder Builds hinweg. Der Source-Freeze ist kein Freeze des Speicherlayouts oder der internen Implementierung.
- **Keine garantierte Wikidata-Abdeckung**, keine unveränderlichen WDQS-/HTTP-Ergebnisse, Serverreaktionszeiten, Erreichbarkeit oder fehlerfreie externe Dienste.
- **Keine unveränderlichen SPARQL-Abfragetexte**: Die Query-Builder-Signaturen sind kompatibel zu halten; der konkrete generierte Text darf sich fachlich begründet ändern. Batch-Cache-Identität bedeutet *exakten Vergleich des tatsächlich gespeicherten und übergebenen Textes*, nicht unveränderliche Query-Bytes über Versionen.
- **Keine Deep-Copy-Garantie** für `JSONValue.raw`, D-Structkopien oder Slices. Die geparsten Graphen sind logisch unveränderlich zu behandeln; parallele Mutationen bleiben außerhalb des Vertrags.
- **Kein Concurrent-Writer-/Crash-Durability-Versprechen** für `batch_cache`: ein Writer pro Pfad, feste `.tmp`, keine fsync-Garantie. Eine andere Query wird vor vollständiger gespeicherter Response-Validierung als Cache-Miss erkannt. Fehler bei passender Query werden nicht als gültige leere Wikidata-Antwort behandelt.
- **Keine automatische Übersetzung aus Sense-Beziehungen**, keine Vollständigkeit der durch `LIMIT` begrenzten Relationen und keine sprachspezifisch erfundene Grammatik. P279-Kompatibilität wird nur aus vorhandenen Wikidata-Belegen gelesen.
- **Keine portable Performance- oder Peak-RSS-Obergrenze**. Die R1.14-J-Messungen gelten ausschließlich für ihre dokumentierte XPS-Offline-Arbeitslast mit authentischen historischen 480 Katalogzeilen und 453 WDQS-Bindings. Das ist **kein** vollständiger A1-Referenzkatalog.

## 3. Änderungs- und Versionsregeln

| Änderungstyp | Innerhalb von `v0.1.x` | Erforderliches Gate |
|---|---|---|
| Implementierungsoptimierung / Fehlerkorrektur | Erlaubt, wenn bestehende Verträge erhalten bleiben | Beide Compiler, Consumer, Semantik- und bei Bedarf authentische Performancebelege |
| Additive API | Nur nach Designreview, wenn existierende Consumer weiter kompilieren und ihr Verhalten bewahren | API-Inventar-Diff, unabhängiger Consumer und Beispiele |
| Zusätzliche optionale JSON-Felder | Nur rückwärtskompatibel | Schema-Review, Parser-/Consumer-Tests |
| Geänderte öffentliche Signatur/Feldart/Enum-Bedeutung oder entfernte API | **Nicht innerhalb der bestehenden Linie** | Breaking-Issue, neue Versionslinie, Migrationsplan und explizite Genehmigung |
| Geänderte bestehende JSON-/Cache-Semantik | Nicht stillschweigend | Schema-/Versionsentscheidung, positive und negative Tests |
| Andere generierte SPARQL-Bytes | Möglich bei erhaltener Abfrage-/Fehlersemantik | Nachvollziehbare Review, Cache-Invalidierungs- und Datenbelege |

**Versionsentscheidung:** `v0.1.x` bezeichnet die Source-Kompatibilitätslinie; die öffentlichen Releases v0.1.0 und v0.1.1 wurden später separat freigegeben. Ein inkompatibler Schnitt ist mindestens als **neue Linie** (etwa `v0.2.x`) zu behandeln, nicht als Patch innerhalb von `v0.1.x`. Es gibt keine zeitlich befristete Supportzusage: Die Linie bleibt Referenz, bis eine ausdrücklich beschlossene Nachfolgelinie inklusive Migrationshinweisen sie ersetzt. Eine spätere öffentliche SemVer- und DUB-Release-Politik erfordert eine getrennte Entscheidung.

## 4. Historisches Freeze-Gate (abgeschlossen)

Die folgenden Bedingungen dokumentieren das ursprüngliche Freigabeverfahren.
Der Tag existiert bereits; diese Anleitung ist kein Auftrag zur erneuten
Ausführung oder zum Ersetzen des Tags.

Diese Datei **allein aktiviert keinen Freeze**. Die Annahme erfolgt in einem eigenen, überprüften Dokumentations-PR. Danach ist der exakte Merge-Commit erneut gegen die unveränderten zehn Produktionsmodule, die sieben Beispiele und die beiden Compiler zu prüfen. Der Tagname `api-freeze/v0.1.0` darf nur verwendet werden, wenn er weder lokal noch remote belegt ist und der freigegebene Commit unverändert HEAD von `origin/develop` ist.

Notwendige Belege: DMD 2.111.0 und LDC 1.41.0 Unit-/Release-Builds; unabhängiger DUB-Consumer; alle sieben Beispiele jeweils mit beiden Compilern **nur kompilieren** (keine Netzwerkbeispiele starten); Release-Boundary-Gate; unverändertes R1.14-I-API-Inventar/Originalarchiv; R1.14-G-Form-/Negativbelege; akzeptierter R1.14-J-Peak-RSS-Nachweis; erfolgreiche GitHub-Fast-CI genau am Freeze-Commit. Änderungen an `source/`, `examples/`, `dub.json` oder Workflows gegenüber `c573d74` sind für diesen reinen Dokumentations-Freeze **nicht zugelassen**. Eine solche Änderung erfordert einen neuen Review.

Erst der **explizite XPS-Befehl `--freeze`** darf im getrennten Worktree einen **signierten, annotierten internen Tag** auf dem freigegebenen Merge-Commit erzeugen und ohne Force-Push veröffentlichen. Vorher bleibt die API **NICHT GEFROREN**. Tag und zugehöriger Issue-Kommentar müssen Commit-SHA, CI-Läufe und Grenzen belegen. Weder `main` noch ein öffentliches Release oder DUB-Paket werden durch diesen Vorgang verändert.

## 5. Release-Gate bleibt eigenständig

Ein Release-PR nach `main` benötigt unverändert die sechs Compiler-Gates **DMD 2.111.0 / 2.112.1 / 2.113.0** und **LDC 1.41.0 / 1.42.0 / 1.43.0**, außerdem separate Entscheidungen zu Feature-Freeze, DDOX, Version, DUB-Veröffentlichung und Distribution. Ein erfolgreicher Source-API-Freeze ersetzt keines dieser Gates.

## 6. Originalbelege

- [R1.14-I – öffentlich importierbare Source-API, 17/34/75](https://github.com/alex-1974/wikidata-d-research/pull/15), unverändertes Originalarchiv und beide Compiler.
- [R1.14-J – originale Peak-RSS-Qualifikation](https://github.com/alex-1974/wikidata-d-research/pull/17), 40 unabhängige Prozesse, keine CI-Peak-RSS-Substitution.
- [R1.14-K – geprüfter Richtlinienentwurf](https://github.com/alex-1974/wikidata-d/pull/17); seine Draft-Version wird durch diese zur Annahme vorgelegte Richtlinie ersetzt, **nicht rückwirkend** als früher eingefroren ausgegeben.
- [R1.14-L – Freigabeentscheidung](https://github.com/alex-1974/wikidata-d/issues/18) und [R1.14-H/I-J-K – übergeordnetes Gate](https://github.com/alex-1974/wikidata-d/issues/10).
