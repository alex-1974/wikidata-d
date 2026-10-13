# R1.12-C2 – Eigentümergebundene Verwendungsbeispiele (Forschung/Integrationskandidat)

**Stand:** 13. Oktober 2026. **Status:** XPS-qualifiziert (DMD 2.111.0 und LDC 1.41.0); Integrations-PR vorbereitet. Keine Grammatikfreigabe. Keine produktive Grammatikfreigabe.

## Ausgangsbasis und echte Gegenbeispiele

R1.12-A/B archivierte 20 Lexeme aus acht Sprachsystemen. Bei einem byte- und metadatengeprüften Quellenabgleich liegen genau **10 `P5831`-Statements** vor: **9 unmittelbar am Lexem**, **1 unmittelbar an einem Sense**, **0 an einer Form**. Die letzten beiden Fälle müssen trotzdem generisch unterstützt werden, auch wenn Form-eigene `P5831`-Statements in dieser Stichprobe fehlen.

- Japanisch **`L1558287-S1`**, Statement `L1558287-S1$c26a226b-421b-2dd1-c7fe-a85e7368d279`: direkt am Sense mit Text `ここでは靴を脱いでください。`; kein `P5830` und kein `P6072`. Der ursprüngliche Eigentümer ist `L1558287-S1`, aber es darf weder eine Form noch ein **expliziter** Sense-Qualifikator hinzugedichtet werden.
- Mandarin **`L641303`**, Statement `L641303$78aea6a4-4963-453c-0676-fb574743ec40`: auf Lexemebene; genau ein `P5830 → L641303-F1` und ein `P6072 → L641303-S1` auf **derselben** Aussage. Diese explizite Kontextpaarung darf erhalten bleiben.
- Türkisch **`L729698`**, Statement `L729698$b52191f3-d881-41ab-a13d-06fbf07e6c22`: auf Lexemebene steht `P6072 → L729698-S1`, aber der archivierte Lexem-Snapshot enthält **nur `L729698-S2`**. `L729698-S1` ist somit eine echte, **im Snapshot unaufgelöste** ursprüngliche Referenz, kein attestierter Sense des aktuellen Snapshots. `P5830` fehlt. Weder ein Formbeleg noch eine Sense-Mitgliedschaft darf ergänzt werden.

## Datenmodell

`grammar_evidence_composition.d` erhält drei additive, schreibgeschützte APIs/Strukturen: `OriginalScopedUsageSource`, `receiptScopedUsageSources(receipt, out sources)` und `receiptContainsSenseId(receipt, senseId)`; `receiptSourceSnapshot(receipt)` liefert eine Kopie der vollständigen Quellmetadaten.

Ein `OriginalScopedUsageSource` enthält **eine** ursprüngliche `P5831`-Aussage, deren **originale Owner-ID**, GUID, Rang, Referenzanzahl, komplette ursprüngliche `JSONValue` und `SourceSnapshotRef`. Die Quelle wird ausschließlich aus einem bereits über Originalantwortbytes und SHA-256 validierten `OriginalLexemeReceipt` gelesen. Es gibt keine automatische Join-Logik. Die Enumeration validiert Owner-IDs sowie duplizierte bzw. beschädigte `P5831`-GUIDs auch bei Form-Eigentümern und schlägt bei Fehlern insgesamt fehl.

Das neue Modul `wikidata.grammar_scoped_usage` bietet `extractScopedUsageExamples(receipt)` und folgende Ebenen **unabhängig** voneinander:

- `ScopedUsageOwner`: `lexeme`, `form`, `sense` – **Speicherort/Eigentümer** des Statements.
- `ownerFormId`, `ownerSenseId`: konkrete Eigentümeridentität **nur durch die Originalstruktur**, keine synthetischen Qualifikatoren.
- `explicitFormId`, `explicitSenseId`: **nur** aus je genau einem validen, originalen `P5830` bzw. `P6072`-Qualifikator derselben Aussage.
- `ScopedUsageStatus`: `lexemeExampleOnly`, `formOwnedExample`, `senseOwnedExample`, `explicitFormQualifierOnly`, `explicitSenseQualifierOnly`, `explicitSameStatementPair`, `unresolvedReferencedEntity`, `invalidOrAmbiguous`, `deprecatedOrNonValue`. Bei `unresolvedReferencedEntity` ist ein Qualifikator syntaktisch wohlgeformt und wörtlich vorhanden, seine Form-/Sense-ID fehlt aber im geprüften Lexem-Snapshot; dies ist **keine positive Mitgliedschaft und keine Aussage über frühere/spätere Revisionen**.

Ein Statement mit einem expliziten Formqualifikator am Sense-Eigentümer hat weiterhin **`ownerSenseId` und `explicitFormId`, aber kein erfundenes `explicitSenseId`**. Auch daraus wird keine allgemeine Form-Sense-Zuordnung behauptet. Dasselbe gilt symmetrisch für Form-eigene Aussagen mit Sensequalifikator. Nur die **beiden tatsächlichen Qualifikatoren derselben Aussage** ergeben `explicitSameStatementPair`.

Alle Ergebnisse liefern `permitsGrammarProduction=false`, `permitsFormSelection=false`, `permitsGeneralFormSenseAssociation=false`.

## Provenienz und Grenzen

- Alle Quellenmetadaten hängen an einem separat validierten, gespeicherten Originalantwort-Snapshot. SHA-256 verifiziert **Bytekonsistenz gegenüber dem angegebenen Digest**, nicht von sich aus die Echtheit des Wikimedia-Ursprungs; Cache-Manifeste und Abrufquelle werden vorgelagert geprüft.
- `JSONValue` ist die semantisch unveränderte Struktur des ursprünglichen Statements. Die Quellantwortbytes bleiben separat unverändert archiviert; eine Re-Serialisierung von `JSONValue` muss nicht dieselbe Bytefolge ergeben.
- `P5831`-Statements mit ungültigen, widersprüchlichen oder mehrfachen Form-/Sensequalifikatoren bleiben als `invalidOrAmbiguous` erhalten, nicht als positive Bindung. Veraltete und Nicht-Wert-Aussagen bleiben sichtbar, erzeugen aber keine positive Evidenz.
- Synthetische Form-eigene Aussagen dienen ausschließlich der Grenzprüfung, **nicht** als echtes Wikimedia-Beispiel.
- Dieses Modul prüft keine sprachliche Richtigkeit eines Beispiels, keine Verwendungskonvention, keinen semantischen Rollen-/Satzbauvertrag. Abwesenheit im Snapshot ist keine zeitübergreifende Negativaussage.

## Abgrenzung von D3-C und D3-D2

D3-C `UsageExampleWitness` verlangt schon bisher auf **derselben** Aussage `P5830` und `P6072`; dieser Vertrag bleibt unverändert. C2 ergänzt eine **verlustarme, schreibgeschützte Sicht auf alle** originalen `P5831`-Aussagen, ohne D3-C-positiv-Witnesses aufzuweichen. Es gibt keine Erweiterung der produktiven Übungs- oder Grammatikfreigabe.

## Prüfverfahren und Integrations-Gate

Das Paket prüft zunächst offline die 20 Originallexeme und die **52** archivierten SHA-256-Einträge sowie synthetische Regressionen. In einem **isolierten, detached Worktree** auf `origin/develop` werden nur das additive Update von `grammar_evidence_composition.d`, `grammar_scoped_usage.d`, `grammar_scoped_usage_test.d` und diese Dokumentation eingesetzt. DMD 2.111.0 / LDC 1.41.0 müssen isolierte Unit-Tests, vollständiges `dub test` und Release-Builds bestehen. Zusätzlich werden die **20 Originalantworten** mit beiden Compilern erneut replayt. Der aktive Checkout einschließlich der nicht committeten `examples/lookup.d` darf nicht verändert werden.

Nach positivem XPS-Gate: Code-Review, eigener Feature-Branch, Pull Request, grüne CI nach Merge. **Bis dahin kein Commit/PR und keine Behauptung einer erfolgreichen D-Compilerqualifikation.**

## XPS-Fehleranalyse und v2-Korrektur (13.10.2026)

Der erste XPS-Lauf war **FAIL**, obwohl das 20/20-Originaldaten-Audit bestanden wurde. DMD/LDC scheiterten beim Lexing der synthetischen JSON-Fixtures durch nicht ausreichend geschützte `\u`-Escapes (unter anderem das UTF-16-Surrogatpaar `\ud83c\udf0d`). v2 verdoppelt die Backslashes innerhalb der D-Stringliterale; die enthaltenen JSON-Szenarien bleiben semantisch unverändert.

Der separate Originaldaten-Replay entdeckte eine echte Datenlücke: `L729698` hat im geprüften Snapshot nur Sense `L729698-S2`, ein eigenes `P5831` referenziert dagegen `L729698-S1`. v2 bewahrt die wörtliche ursprüngliche Qualifikator-ID in `explicitSenseId` und weist `unresolvedReferencedEntity` statt eines positiven `explicitSenseQualifierOnly` aus. Das Replay und die Offline-Tests erzwingen diesen Negativfall.

**Offen:** DMD/LDC-Unittests, vollständiges `dub test`, Release-Build und neuer Originaldaten-Replay auf dem XPS. Kein produktiver Einsatz oder Merge vor grünem Gate.

## XPS-v2-Befund und v3-Korrektur (13.10.2026)

Der zweite XPS-Lauf verifizierte erneut 20/20 echte Lexeme, 52/52 Quellenprüfsummen,
und sowohl DMD als auch LDC bestanden den eigenständigen Originaldaten-Replay.
Die vollständige Unit-/Release-Qualifikation blieb **FAIL**, weil das synthetische
Testmodul `private enum string deprecated` als Namen verwendete: `deprecated`
ist ein reserviertes D-Schlüsselwort. v3 benennt **nur diese Fixture-Variable und
ihre zwei Verwendungsstellen** in `deprecatedFixture` um. Ein zusätzlicher
Python-Regressionstest prüft D-Schlüsselwörter in allen zehn Fixture-Namen.
Die drei D-Dateien mit fachlicher Implementierung bleiben gegenüber v2
byteidentisch; nur die synthetische Testdatei wurde korrigiert.
**Die vollständige DMD-/LDC-v3-Qualifikation ist anhand des XPS-Ergebnisarchivs erfolgreich nachgewiesen.**


## XPS-v3-Qualifikation (13.10.2026)

- Ausgangsbasis: `42e4cb8773481ad0a918c0a5e0dc077cb5167e85` (`develop`).
- DMD 2.111.0 und LDC 1.41.0: je 6 isolierte Unittest-Module **PASS**, vollständiges `dub test` mit je 24 Modulen **PASS**.
- Release-Build mit beiden Compilern **PASS**.
- DMD/LDC-Originaldaten-Replay: 20/20 Lexeme, 10 `P5831` (9 Lexem, 1 Sense), 1 explizites Form-Sense-Paar **PASS**.
- Japanischer Sense-Eigentümer ohne synthetische Qualifikatoren; türkischer Literal-Sense `L729698-S1` bleibt im S2-only-Snapshot unaufgelöst.
- 52/52 Quellenprüfsummen im Replay und 27/27 Ergebnisarchiv-Einträge **PASS**.
- Lokaler HEAD und `examples/lookup.d` blieben unverändert.
- Die drei D-Quelldateien sind byteidentisch mit dem bestandenen v3-XPS-Kandidaten.
- GitHub-CI vor/nach dem Merge bleibt ein eigenständiges Gate.
