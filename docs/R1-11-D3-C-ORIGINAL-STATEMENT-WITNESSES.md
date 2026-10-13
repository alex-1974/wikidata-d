# R1.11-D3-C – Original-Statement-Witnesses (Implementierungskandidat)

**Status:** XPS-Qualifikation am 13.10.2026 mit DMD 2.111.0 und LDC 1.41.0 bestanden; PR-Integrationskandidat. Keine Grammatikproduktionsfreigabe.

## Grundlage

Vier lexikalische EntityData-Antworten sind auf dem XPS vorhanden und im Forschungsindex mit den folgenden SHA-256-Referenzen aufgeführt:

| Lexem | Version | SHA-256 |
|---|---:|---|
| L7 | 2549796276 | `0f2a03a6e144a356999bf32b09239e70151b6625ac9ec12e4a9c536785b92072` |
| L6888 | 2139838255 | `e5de413f75b1e107f76a632c0d68de157f4367c4dfbc03a13feb9d174046916d` |
| L252527 | 2344138429 | `caa8454adecaeed003295dbbae187b0d366ee9fca45663dff8cc80c5dc65e5f8` |
| L1340 | 2549857249 | `6adbe30cd64f7d5ca3af13d5d2649188c9437d7e2e0cb2beb8007ba597cb72d5` |

Der hier vorhandene D3-A-Index bildet 13 Originalstatements ab. Der vollständige originale 4er-Datensatz liegt **nur auf dem XPS**, nicht im vorliegenden Entwicklungspaket. Dieser Parser soll deshalb **am Originallexem** getestet werden; der Index dient lediglich zum nachträglichen strukturellen Abgleich. Fälschlich rekonstruierte Raw-JSON-Testfixtures sind **keine** Wikidata-Quelle.

## Verträge

Neues Modul: `source/wikidata/grammar_statement_witness.d`.

- `SourceSnapshotRef`: originale Lexem-ID, Revision, extern verifizierte Antwortbytes-SHA-256 und URL. Die Syntax wird im D-Modul geprüft; die kryptografische Bindung an Originalbytes erfolgt **außerhalb** mit `tools/verify_d3_originals.py`.
- `OriginalStatementProof`: originale Statement-ID mit unveränderter Groß-/Kleinschreibung, Owner-Scope, Property, Rang, Snak-Typ, Referenzanzahl, **vollständigem ursprünglichem Statement-JSON** inklusive Qualifikatoren und Referenzen.
- `StatementObservation`: bewahrt jedes relevante Statement separat, auch `partial`, `ambiguous` und `unresolved`. Es findet **kein Join zwischen Statements** statt.
- `UsageExampleWitness`: `P5831`-Hauptwert ist Monolingualtext; **genau eine** `P5830`-Form und **genau ein** `P6072`-Sense im selben Statement. Form und Sense müssen tatsächlich im Originallexem existieren. Für Sense-Scope muss der explizite `P6072`-Sense mit dem Owner übereinstimmen.
- `ComponentWitness`: `P5238` mit originalem Lexem-Ziel. Optional wird ein einzelnes unverändertes `P1545`-Ordinal als Literal übernommen. Ein `P5548`-Qualifikator wird im Original erhalten und mit `hasUnverifiedObjectFormQualifier` markiert, aber **nicht** als verifizierte Objektform ausgewiesen, solange der Originalsnapshot des Komponentenlexems fehlt.
- `SemanticArgumentWitness`: `P9971` nur auf originalem Sense-Scope; Q-Argument und maximal eine ausdrückliche `P3831`-Rolle. Beide Q-IDs bleiben uninterpretierte Originalkennungen. Ohne Rolle nur Argumentbeleg.
- `StatementWitnessBatch`: alle drei Witness-Familien plus alle Statement-Beobachtungen und ein fail-closed Input-Status.

**Nicht enthalten:** Klassifikations-/Review-Freigabe, syntaktische Wortstellung, Flexionsgenerierung, Kasuszuweisung, `P5713`/`P5401`-Interpretation, `P5548`-Objektformprüfung über mehrere Lexeme und allgemeine Form↔Sense-Zuordnungen. Der Parser ergänzt D1/D2, ersetzt deren Verträge aber nicht.

Alle Ergebnis-Typen geben `permitsGrammarProduction == false`, `permitsFormSelection == false` und – soweit relevant – `permitsGeneralFormSenseAssociation == false` zurück.

## Beleggrenzen

1. Derselbe Original-Statement-GUID ist der zwingende gemeinsame Scope für Form und Sense. Eine Form aus einem `P5831`-Statement darf nicht mit einem Sense eines zweiten Statements kombiniert werden. **L1340 ist der Negativfall.**
2. Mehrere Form-/Sense-Qualifikatorwerte werden als `ambiguous` dokumentiert, **ohne kartesische Kombination**. Fehlende Werte bleiben `partial`.
3. Veraltete Aussagen, `novalue`, `somevalue`, falsche Besitzer und fehlerhafte IDs erzeugen keine positiven Witnesses. Strukturell falsche Originalstatements lassen die gesamte Eingabe scheitern.
4. `P5238` ist nur Bestandteilreferenz; die referenzierten Lexeme können ohne ihre eigenen Originaldaten nicht als vollständig geprüft gelten. `P5548` bleibt deshalb zunächst opaque.
5. `P9971`/`P3831` sind nur originale semantische Rollenaussagen; sie erlauben keine neue Grammatikregel, keine Kasusannahme und keine Interpretation einer Q-ID ohne weitere Q-Graph-Snapshots.
6. `referenceCount` ist **nur die Anzahl** der originalen Referenzblöcke, kein Qualitäts- oder Wahrheitsmaßstab. Die kompletten Referenzen bleiben im Statement-JSON verfügbar.
7. Die SHA-256-Vergleichsprüfung bestätigt **Konsistenz mit gespeicherten Rohbytes**. Ursprung/HTTPS-Authentizität und inhaltliche Zuverlässigkeit werden dadurch nicht unabhängig bewiesen.

## Quality Gates

Der XPS-Gate ist vollständig offline und arbeitet in einem *detached* Git-Worktree auf dem aktuellen `origin/develop`, ohne das aktive Arbeitsverzeichnis oder `examples/lookup.d` zu ändern.

```bash
bash "$HOME/Downloads/r1-11d3-c/run_r1_11d3c_on_xps.sh" --check
bash "$HOME/Downloads/r1-11d3-c/run_r1_11d3c_on_xps.sh" --run
```

- D3-C-Paketintegrität und SHA-256.
- Rohdatenverifikation der vier Originaldateien aus `~/Downloads/wikidata-r1-11d3-source-state` mit per-item source manifest, Revision, Index und D3-B-Matrix.
- D3-C isolierte Unittests auf DMD 2.111.0 und LDC 1.41.0.
- Vollständige `dub test`- und Release-Build-Gates auf beiden Compilern.
- Bereits bestehende R1.11-B-Python-Regressionen.
- Aktiver Git-HEAD und Arbeitsstatus vor/nach dem Worktree-Lauf müssen exakt identisch sein.

Erst bei erfolgreichem Test ist ein PR über den geschützten Branch `develop` sinnvoll. Ein PR wäre weiterhin keine automatische Freigabe grammatischer Produktionsregeln.

## Offizielle Spezifikationen

- [P5831 – usage example](https://www.wikidata.org/wiki/Property:P5831)
- [P5830 – subject lexeme form](https://www.wikidata.org/wiki/Property:P5830)
- [P6072 – subject sense](https://www.wikidata.org/wiki/Property:P6072)
- [P5238 – combines lexemes](https://www.wikidata.org/wiki/Property:P5238)
- [P5548 – object form](https://www.wikidata.org/wiki/Property:P5548)
- [P9971 – semantic role](https://www.wikidata.org/wiki/Property:P9971)
- [P3831 – object of statement has role](https://www.wikidata.org/wiki/Property:P3831)

## XPS-Qualifikation (13.10.2026)

- Getestete Ausgangsbasis: `9c53fd469db4ccc6e405f4a47dc01275c5b0aa8a` (`develop`).
- Exakt getesteter D-Quellcode SHA-256: `66dc83ea52da641c226d1b4dab9bc5b70be6f600042aeeaf195d4a93d31bbbfa`.
- DMD 2.111.0 und LDC 1.41.0: isolierte Modultests mit je 2 Modulen PASS.
- `dub test`: je 21 Module PASS; beide Release-Builds PASS.
- R1.11-B-Python-Regressionen: 11/11 PASS; Graph-Inventar PASS.
- Offline-Originaldatenprüfung: vier Wikidata-Snapshots, 13 Statements und sechs eindeutige kontextgebundene Form-Sense-Beispiele bestätigt.
- Aktiver XPS-Checkout blieb auf `9c53fd4`; die lokale Änderung `examples/lookup.d` blieb unverändert.
- Die Snapshot-Authentifizierung gehört weiterhin in die vorgelagerte Quellen-/Cache-Schicht; die D3-C-API erzeugt keine sprachlichen Daten.
- Integrationsprüfung durch GitHub-CI und Pull-Request-Review bleibt vor dem Merge erforderlich.
