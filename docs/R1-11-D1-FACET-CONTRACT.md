# R1.11-D1 – Typologie- und Freigabevertrag (Forschungsstufe)

**Stand:** 13. Oktober 2026
**Status:** Python-Offline-Audit 15/15 PASS; auf dem XPS isoliert **DMD/LDC jeweils 2 Unittest-Module PASS**. Diese Integration enthält eine zusätzliche, bislang **nicht auf dem XPS kompilierte** Review-Konfliktprüfung. Vollständiger `dub test` nach Integration, Commit und produktive Freigabe bleiben offen.

## Ausgangslage

Die geprüften XPS-Archive R1.11-C4 und R1.11-C7F belegen 88 Q-Item-Merkmale und sechs zusätzliche originale Ontologie-Items. R1.11-B liefert `candidate` (53), `multiple_candidates` (3) und `unclassified` (32). Diese Zustände sind **Ontologie-/Klassifikationsevidenz**, nicht Sprachgrammatik und nicht Verwendungsbedingungen einer Wikidata-Form. Die 59 originalen Dimensionszeugen bleiben mit ihren direkten Wikidata-Statement-IDs erhalten. Die sechs nachgeladenen Items enthalten zehn geprüfte direkte P31/P279-Aussagen.

## Die fünf unabhängig zu prüfenden Ebenen

1. **Originalaussage:** Q-/L-Statement, Quelle, Scope, Statement-ID, Rang, Qualifikatoren, Snapshot. Ein Textlabel allein ist kein Beleg.
2. **Klassifikationskandidat:** `dimensionId` und exakt erlaubter Pfad aus R1.11-B. Mehrfachkandidaten bleiben erhalten; fehlende Übereinstimmung ist `unknown`.
3. **Semantische Rolle:** grammatische Dimension, Wert, Wortart/Kategorie, Formtyp, morphologischer Begriff, Repräsentationsart, Verwendung/Register oder mehrdeutig/unaufgelöst. Status und Herkunft separat speichern.
4. **Konstruktionsvertrag:** deklarierter Operator mit Sprach-/Konstruktionsscope und prüfbarer Modalität (`required`/`typical`/`optional`/`unknown`). **In D1 gibt es noch keinen aktivierten Vertrag.** `P5713` darf nicht pauschal `required` bedeuten.
5. **Attestiertes Lexem-/Form-/Sense-Binding:** Der Operator müsste mit einer tatsächlich existierenden Wikidata-Form bzw. passendem Sense und Provenienz verknüpft sein. Weder ein vorliegendes Q-Item noch ein freigegebenes Facet stellt dieses Binding bereit.

Die neue D-Datei `source/wikidata/grammar_facet.d` setzt **ausschließlich den Übergang von Ebene 2 zu einer überprüfbaren Metadatenbewertung auf Ebene 3** um. Die beiden letzten Stufen werden nicht simuliert.

## API-Vorschlag

- `SemanticRole` unterscheidet `grammaticalDimension`, `grammaticalValue`, `lexicalCategory`, `inflectionFormType`, `morphologicalConcept`, `representationKind`, `usageOrRegister`, `mixedOrAmbiguous`, `unresolved`.
- `FacetReviewDisposition` unterscheidet Forschungs-Hypothese, geprüfte Evidenz, Facet-Freigabe, Verschiebung, Ablehnung und Quarantäne.
- `assessFacet(FeatureClassification, FacetReview[], verifiedGraphSha256)` bindet eine einzelne manuelle Revisionsentscheidung an die exakte Q-ID, den Dimensionskandidaten und originale R1.11-B-Zeugen. Hash-Mismatch, nicht belegte Statement-ID und doppelte Reviewdatensätze ergeben `invalidReview`.
- Der Fall `multiple_candidates` bleibt `ambiguityPreserved`, auch wenn einzelne Facets später überprüft werden.
- **Auch `facetApprovedNotGrammarUse` gibt keine Wortform oder Produktionsoperation frei.** `permitsFormSelection` und `permitsGrammarProduction` bleiben explizit `false`.

`FeatureFacet.inflection` ist im R1.11-C4-Replay nur ein **Testplatzhalter** und wird in R1.11-D1 **nicht** als fachlich bewiesene Flexionskategorie übernommen. Die zusätzlich erfasste `semanticRoleHypothesis` liegt bewusst in einem separaten Forschungsprofil.

## Konservatives 88-Merkmale-Profil

`research/r1-11d1-facet-research-profile.json` enthält:

- 88 Original-Q-IDs mit unveränderten 53/3/32-Klassifikationszuständen und allen 59 Zeugnisstatement-IDs;
- fünf besonders gut direkt belegte Wertzuordnungen: Nominativ, Dativ, Akkusativ, Genitiv, Dual (**nur evidence-only**);
- drei ausdrücklich mehrdeutige Merkmale: `Q10345583`, `Q12717679`, `Q52434302`;
- drei separate Rollen-Hypothesen ohne R1.11-B-Dimension: Oberflächenrepräsentation `Q124100534`, lexikalische Repräsentation `Q124100536`, umgangssprachliche Form `Q55228835`;
- sechs C7F-Ontologie-Sidecars mit Originalquellenhashes; `Q63315203 P31→Q27949697` bleibt als **auffälliger Sonderfall gesperrt**;
- **0 Konstruktionsfreigaben, 0 attestierte Form-Bindings, 0 lexikalische Synthesen**.

Nicht individuell geprüfte semantische Rollen bleiben `unresolved`, selbst wenn ein R1.11-B-Klassifikationskandidat existiert.

## Quellen-/Semantikgrenzen

- Die vorhandenen XPS-Snapshots sind zeitlich nicht atomar und keine vollständige Wikidata-Ontologie.
- Ein Folgeitem kann weitere bislang ungesehene P31/P279-Zielknoten besitzen; keine unbeschränkte P279-Closure.
- `P461` ist keine XOR-Regel; `P1889` ist keine generelle grammatische Exklusion.
- Insbesondere bei italienischen Artikeln, Türkisch und Kisuaheli ist noch keine vollständige, attestierte Produktions- oder Kontextwahlregel belegt.
- Auch ein einzeln semantisch gut verstandener Kasuswert oder ein Wortstamm berechtigt nicht zur Form-/Sense-Generierung.

## Qualität und nächster Arbeitsschritt

15 Python-Regressionen sind auf den tatsächlich hochgeladenen C4/C7F-Artefakten bestanden. Die D-Datei enthält zusätzlich eingebaute synthetische D-Unittests, hat die bisherige XPS-Isolationsprüfung mit DMD 2.111/LDC 1.41 bestanden (je 2 Unittest-Module). **Die neue Konfliktprüfung und die vollständigen `dub test`-Gates auf beiden Compilern bleiben bis zum Integrationslauf offen.**

Danach sollte R1.11-D2 die Form- und Sense-Scope-Prüfung vorbereiten und einen nicht ausführbaren `ConstructionGrant`-Typ mit überprüfbarer Provenienz definieren. Erst nach realen, gebundenen Fällen eine konkrete deklarative Regelauswertung entwerfen. Keine vorgezogene Text-DSL.

## Integrationsprüfung (nach XPS-D1-Lauf)

Der neue Quellstand verschärft eine bewusst konservative Eigenschaft: Zwei
Reviewdatensätze für denselben `(featureQId, dimensionId, classifierFacet)`
dürfen nicht widersprüchliche `semanticRole`- oder `disposition`-Werte
tragen. Für ein klassifiziertes Facet wird deshalb schon das zweite Review
mit `invalidReview` zurückgewiesen. Für ein unklassifiziertes Merkmal
können mehrere **unterschiedliche hypothetische Rollen** weiterhin ohne
Freigabe erhalten bleiben.

Die zusätzlichen D-Unittests wurden nach dem ursprünglichen XPS-Lauf ergänzt.
**Die 2/2 Modul-PASS des ursprünglichen Laufs beweisen noch nicht diesen Patch.**

Die Bezeichner `reviewSource`, `reviewId` und `graphSnapshotSha256` sind
Metadaten bzw. vom Aufrufer übergebene Prüfwerte. Diese Funktion authentisiert
keinen Reviewer, lädt keine Original-Wikidata-Statements nach und prüft nicht
selbst, ob `verifiedGraphSha256` tatsächlich zu den übergebenen Kandidaten
gehört. Ihr Aufrufer muss die Snapshotbindung und Herkunft des ursprünglichen
`FeatureClassification` bereits verifiziert haben.

Für die Integration werden **nur zwei neue Repository-Dateien** vorgeschlagen:
`source/wikidata/grammar_facet.d` und diese Dokumentation. Vor einem Commit
müssen DMD und LDC die gesamten `dub test`-Gates bestehen. Die lokale Änderung
an `examples/lookup.d` bleibt unangetastet.
