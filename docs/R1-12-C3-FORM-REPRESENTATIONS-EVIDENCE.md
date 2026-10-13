# R1.12-C3 – Original Form Representations und Schreibkollisionen

**Stand:** 2026-10-13. **Status:** XPS-qualifiziert mit DMD 2.111.0 und LDC 1.41.0; Integrations-PR vorbereitet; keine Grammatikfreigabe. Basis: `develop` `2f7bc9208f864a884f85597e1a5754e8a7a4b27d` (PR #7/C2, CI grün).

## Originalbelege

Die quellentreue Prüfung des R1.12-B2-Archivs ergibt aus 22 Lexemen (absichtsvoll ausgewählte acht Sprachsysteme): **273 originale Forms**, **300 originale Representation-Einträge**, **26 Forms mit mehreren Repräsentationen**, **45 Kollisionsgruppen** (gleicher Tag und Text, verschiedene Form-IDs innerhalb genau eines Lexems), **14 Tags**. **52/52 SHA-256-Manifesteinträge** und Cache-/Revision-/Quell-URL-Konsistenz geprüft. Kein repräsentativer Abdeckungswert und keine Aussage über externe A1-Wortlisten.

Echte Referenzfälle:

- `L741449-F1` – `ja=開く`, `ja-hira=あく`: eine Form, zwei gespeicherte Darstellungen.
- `L656255-F1` – `zh-hant=長`, `zh-hans=长`, `zh-x-Q42222=cháng`: alle Tags exakt bewahren.
- `L62892-F1`/`L62892-F2` – `eu=etiketa`: gleiche Darstellung, **zwei originale Formidentitäten**.
- `L728512-F1` – `tr=ci`, `ota=جی`: C1 bestätigt unabhängig die exakte Form-ID via `P5548`, **nicht** deren Auswahl für eine grammatische Umgebung. Mehrere weitere Forms besitzen ebenfalls `ota=جی`.
- `L1134429-F1` – `id=sepatu`, `ms-arab=سڤاتو`: originaler Representation-Tag ist kein sprachlicher Ersatz für die Lexem-Q-ID.
- `L1331010` – 0 Forms, 0 Senses: zulässiger Leerfall ohne Ableitung.

Originaldaten stammen laut archivierten Metadaten aus dem Wikidata `Special:EntityData`-Endpunkt. Prüfsumme und Revision sichern interne Konsistenz der **übergebenen Bytes**, nicht unabhängig deren Ursprung oder sprachliche Korrektheit.

## D-API, rein lesend

Im neuen Modul `wikidata.grammar_form_representations`:

```d
FormRepresentationBatch extractOriginalFormRepresentations(
    OriginalLexemeReceipt receipt);
```

- `OriginalFormRepresentationEvidence` enthält `snapshot`, `lexemeId`, `lexemeLanguageQId`, `formId`, `representationTag`, `literalText`, `originalRepresentationPath` als **RFC-6901-JSON-Pointer** und die originalen Q-Merkmale der Form.
- `OriginalRepresentationCollision` enthält denselben Snapshot, das ursprüngliche Lexem, das **exakte** `(tag, text)`-Paar sowie die **verschiedenen** Original-Form-IDs; keine Fusion oder Grammatikentscheidung.
- `FormRepresentationBatch` enthält außerdem `originalFormIds` und `formsWithoutRepresentations`, die auch Forms ohne gespeicherte Darstellung identifizierbar halten. Bei null Forms bleibt die originale Lexem-Sprach-Q-ID erhalten.
- `FormRepresentationStatus` unterscheidet `sourceNotVerified`, `valid`, `invalidOriginalRepresentations`. Bei einem ungültigen Objekt wird die **gesamte** Ergebnisliste als ungültig zurückgewiesen; keine positive Teilliste.

Der schmale Adapter `receiptOriginalFormRepresentationSources` in `grammar_evidence_composition.d` bietet ausschließlich **tiefe JSON-Kopien** der aus einem verifizierten Originalreceipt re-parsten Formrepräsentationen. `receiptLexemeLanguageQId` liest die ursprüngliche Lexem-Sprach-Q-ID, auch bei null Forms. Das bisherige C2-Modul und die C1-API bleiben unverändert.

Die Sortierung der Tags ist lediglich eine stabile Ausgabereihenfolge, **keine** sprachliche Normalisierung. Text und Tag werden als originale Strings übertragen. Gleichheit wird ausschließlich an Byte-identischem Stringvergleich gemessen: weder Unicode-Normalisierung noch Sprach-/Schriftsystem-Aliase, Transliteration oder erzeugte IPA-/Schreibvarianten. Die Kollision ist ein Vergleichsergebnis, **keine** zusätzliche Wikidata-Form.

## Schutzregeln

- Keine Erzeugung von Forms, Senses oder grammatischen Regeln.
- Keine abgeleiteten Repräsentationen; fehlende gewünschte Tags bleiben fehlend.
- `permitsGrammarProduction`, `permitsFormSelection`, `permitsFormIdMerge` sind überall `false`.
- Keine `if language == Japanese/Turkish/...`-Sonderfalllisten.
- Ungültige Map-Typen, fehlende oder ungleiche `language`-Tags, untypisierte `value`-Felder und leere Tags führen zu `invalidOriginalRepresentations`.
- Die Ergebnisansicht bewahrt Quellrevision und SHA-256, aber sie authentifiziert Wikimedia nicht eigenständig.

## Qualitäts-Gates

**Bereits lokal offline:** Paketmanifest, 22/22 Originallexeme, 52/52 Archivprüfsummen, 11/11 Python-Quellenregressionen plus Implementierungsvertragstests. Die D-Quelldatei `grammar_evidence_composition.d` enthält die komplette C2-Basis byteidentisch **als Präfix** und nur additive Funktionen am Ende.

**XPS-qualifiziert:** `dmd 2.111.0`, `ldc2 1.41.0`: isolierte Unittests, vollständiges `dub test`, Release-Build und Replay gegen 22 originale SHA-/Revisionswerte. Das XPS-Skript prüft den richtigen HEAD, einen unmodifizierten Basis-Composition-SHA und die unveränderte Arbeitskopie (`examples/lookup.d`) vor/nach dem isolierten Worktree. **Kein Commit, PR oder Merge vor positiven Compiler-Gates.**

## Wissenschaftliche Einordnung

Die `FormRepresentationBatch` ist eine **Anzeige- und Analyseprojektion** vorhandener Wikidata-Daten. Die externe Referenzkatalogschicht (vollständige Perugia-Listen, weitere Sprachen/Niveaus) bleibt unabhängig und unverändert; für den Übungsbetrieb folgt keine neue Zulassungsregel. Spätere UI-Präferenzen dürfen unter den **tatsächlich vorhandenen** Tags auswählen, nicht selbst lexikalische Fakten erzeugen.


## XPS-Qualifikation (13.10.2026)

- Unveränderte Ausgangsbasis: `2f7bc9208f864a884f85597e1a5754e8a7a4b27d` (`develop`).
- DMD 2.111.0 / LDC 1.41.0: je 6 isolierte Unittest-Module und je 25 vollständige `dub test`-Module **PASS**.
- Release-Build mit beiden Compilern **PASS**.
- Originaldaten-Replay mit beiden Compilern: 22/22 Lexeme, 273 Forms, 300 Repräsentationen, 26 Forms mit mehreren Repräsentationen, 45 Schreibkollisionsgruppen, 14 Tags **PASS**.
- C1-Regression: `P5548 → L728512-F1` in der originalen Ziel-Formidentität bewahrt **PASS**.
- Originalquellen: 52/52 Manifest-Einträge geprüft; XPS-Ergebnisarchiv: 27/27 SHA-256-Einträge geprüft.
- Arbeitskopie auf dem XPS unverändert: `examples/lookup.d` bleibt lokal modifiziert.
- Alle drei D-Quelldateien sind byteidentisch zum qualifizierten XPS-Kandidaten.
- GitHub-CI vor/nach dem Merge ist ein eigenständiges Integrations-Gate.
