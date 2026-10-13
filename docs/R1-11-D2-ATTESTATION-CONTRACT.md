# R1.11-D2 – Typisierte Original-Form-/Sense-Attestierung (Forschung)

**Status:** XPS-Qualifikation vom 13.10.2026 bestanden (DMD 2.111.0, LDC 1.41.0); Integrationskandidat für `develop`. Keine produktive Grammatikfreigabe.

## Zweck und Datenquellen

R1.11-D1 prüft, ob ein Q-Item-Facet semantisch begutachtet wurde. Das allein bestätigt weder die Existenz einer Wikidata-Form noch deren mögliche Verwendung. R1.11-D2 bindet Q-Feature-Evidenz an eine **konkret vorhandene Wikidata Form-ID innerhalb eines Lexems**, getrennt von der Existenz einer **Sense-ID desselben Lexems**.

- `wikidata.lexeme.parseLexeme()` liefert die typisierte Ansicht und unveränderte Original-JSON-Felder.
- `wikidata.grammar_dimension.FeatureClassification` liefert originale Q-Graph-Kandidaten und Q-Statement-Zeugen.
- `wikidata.grammar_facet.FacetAssessment` bewahrt fachliche Reviews, einschließlich Unaufgelöstheit, Mehrdeutigkeit und Quarantäne.
- `wikidata.grammar_attestation` **führt keine neue linguistische Regel** ein; sie verbindet die drei Arten von Evidenz konservativ.

Die verwendeten SHA-256-Werte sind **nur vom Aufrufer bereitgestellte Quellreferenzen**. Dieses Modul berechnet keinen Hash aus originalen HTTP-Response-Bytes und prüft weder API-Authentizität noch Snapshot-Integrität. Dies ist eine Verpflichtung der vorgelagerten Fetch-/Cache-Schicht. Ein synthetischer Testfixture bleibt ein Fixture, selbst wenn ihm eine 64-stellige Hashreferenz zugewiesen wird.

## Zwei unabhängige Verträge

### A. `bindAttestedFormFeature`

Eingabe: genau benanntes Lexem mit Sprache und Wortart, Form-ID, **ein** Q-Feature, D1-Feature-Klassifikation, D1-Facet-Bewertung sowie externe Snapshot-Referenzen.

Das Modul überprüft:

1. Die strenge ID-Familie `L…`, `L…-F…`, `Q…` und die deklarierte Lexem-/Sprach-/Wortart-Zugehörigkeit.
2. Dass die aus der typisierten Ansicht abgelesenen Identitätsfelder und Feature-Listen mit dem enthaltenen Original-JSON übereinstimmen. Veränderte abgeleitete Ansichten führen nicht zu einem positiven Treffer.
3. Dass alle Form-/Sense-IDs des Lexems eindeutig und innerhalb der angegebenen Lexem-ID gültig sind.
4. Dass die abgefragte Q-ID exakt der D1-Klassifikation und der D1-Review-Bewertung zugeordnet ist.
5. Ob genau diese ursprüngliche Wikidata-Form das Q-Item **literal** in `forms[].grammaticalFeatures` führt.

Ergebnis: `attestedFeatureOnly`, `unknown`, `quarantined` oder `invalidInput`.

**Wichtig:** Der Nachweis eines Q-Items in `grammaticalFeatures` ist keine Wikibase-Statement-ID. Die Quellprovenienz ist hier die originale Form-ID, der JSON-Pfad und der unabhängig zu prüfende Lexem-Snapshot; Q-Ontologie-Statement-IDs bleiben als **separate** `dimensionWitnessStatementIds` erhalten. Die beiden Quellen dürfen nicht zu einem imaginären Wikibase-Statement vermischt werden.

### B. `bindAttestedSenseMembership`

Bestätigt lediglich, dass `L…-S…` unter genau diesem Originallexem vorhanden ist. Das Ergebnis `attestedMembershipOnly` sagt **nichts** über die Zuordnung zu einer bestimmten Form aus. Um eine solche Beziehung zu behaupten, wären separate Originalaussagen mit zutreffendem Bedeutungs-/Beziehungsscope nötig.

## Nicht zugelassene Schlussfolgerungen

| Situation | Konservatives Resultat |
|---|---|
| Form existiert, Q-Feature steht exakt in `grammaticalFeatures` | `attestedFeatureOnly` (nur Mitgliedschaft) |
| Form-ID fehlt oder Feature-ID nicht vorhanden | `unknown`, nicht `false` |
| Ein Q-Feature hat mehrere Dimensionskandidaten | Ursprüngliche Mehrdeutigkeit bleibt bestehen |
| D1-Review weist Quarantäne aus | `quarantined`, nicht produktiv freigegeben |
| Falscher Lexem-Präfix, abweichende Sprache/Wortart, veränderte abgeleitete Formdaten | `invalidInput` |
| Sense existiert unter dem Lexem | `attestedMembershipOnly`, keine Form↔Sense-Aussage |
| Zwei Forms besitzen dieselbe Darstellung | Die unterschiedlichen originalen Form-IDs bleiben getrennt |
| Fehlende Wikidata-Daten | Keine Ersatz-, Synthese- oder Negativinformation |

Beide Ergebnisstrukturen geben `permitsFormSelection`, `permitsGrammarProduction` und `permitsFormSenseAssociation` **immer als `false`** zurück. Artikelkombination, Oberflächenallomorphie, Morphologieerzeugung, „il/lo“-Kontextregeln, `P5713`-Modalität und Form-/Sense-Konstruktionen gehören nicht in D2.

## Qualität und Integration

Auf einem XPS-Checkout von `develop` werden in einem **separaten detached Git-Worktree** folgende Prüfungen ausgeführt, ohne das Benutzerarbeitsverzeichnis zu überschreiben:

- DMD 2.111.0 und LDC 1.41.0: isolierte Modultests.
- DMD und LDC: vollständiges `dub test`.
- DMD und LDC: `dub build --build=release`.
- Die offline Python-Regressionen von R1.11-B.
- SHA-256-Integrität, Git-HEAD und identischer lokaler Git-Status vor/nach den Tests.

Die D-Tests verwenden bewusst **synthetische Forschungsfixtures** und nicht als original behauptete Wikidata-Snapshots. Die Compilerqualität ist bis zur XPS-Ausführung **offen**.

Nächster Schritt nach erfolgreichem XPS-Gate: präzises Code-Review, dann PR auf den geschützten Branch `develop`. Erst danach wird eine eventuelle Erweiterung um **explizite Form-/Sense-Beziehungswitnesses** untersucht.

## XPS-Qualifikation (13.10.2026)

- Commitbasis: `f42db2284b1b712d5ad040137609dd5b8d04e9f9` (`develop`).
- Exakter D-Quellcode-SHA-256: `40b6dda6ccbde76691dc13a942833d44e222cae7d3ff69d9bf3d8eef14da4202`.
- D2-Isolationstests: je 4 Module PASS (DMD/LDC).
- Vollständige `dub test`: je 20 Module PASS (DMD/LDC).
- Release-Builds: DMD/LDC PASS. R1.11-B Offline-Regressionen: PASS.
- Aktiver XPS-Checkout blieb unverändert (`examples/lookup.d` weiterhin lokal modifiziert).
- **Einschränkung:** Der Aufrufer muss die Snapshot-Digests außerhalb dieses Moduls kryptografisch prüfen.
- Testfixtures sind synthetisch. Keine produktive grammatische Freigabe.
