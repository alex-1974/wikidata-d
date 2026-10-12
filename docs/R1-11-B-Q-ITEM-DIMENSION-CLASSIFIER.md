# R1.11-B – Typisierter, offlinefähiger Q-Item-Klassifikator

**Status: Forschungsimplementierung, API nicht eingefroren; DMD/LDC-Gates auf dem XPS noch offen.**

R1.11-A bestand auf dem XPS mit 18/18 Offline-Prüfungen (acht Stichproben,
sechs Sprachen). Das vorläufige Q-ID-Mapping klassifizierte nur 10/52
Kisuaheli-Formmerkmal-IDs als Kandidaten; 42 blieben unklassifiziert.
Diese Mengen sind KEIN Beweis, dass die 42 Merkmale keine grammatische Bedeutung
haben. Die alte Probe-Tabelle wird **nicht** in den D-Code übernommen.

## Datenquellen und Geltungsgrenzen

1. **Originaler Q-Item-Graph**: `reports/local/r1-3/feature-graph.json`,
   Schema `r1.3-graph-audit-v1`. Die R1.3-Kanten enthalten `source`, `target`,
   `property`, `statementId`, `rank` sowie Flags für Qualifikatoren/Referenzen.
   Sie stammen aus Wikidata Q-Items. Der Graph darf teilweise fehlen oder
   durch die Auswahlbegrenzung abgeschnitten sein.
2. **Auswahl der untersuchten Feature-Q-IDs**: R1.11-A, enthalten in
   `/tmp/wikidata-r1-11/data/r1-6-cross-language-evidence.json`.
3. **Klassifikationsanker**: separate, *explizit geprüfte* Metadaten in einem
   Schema `wikidata-r1.11b-dimension-profile-v1`. Ein Anker enthält
   `dimensionId`, `facet`, `rootQId`, `source`, `allowedPaths`. Anker sind
   **nicht** aus Aggregathäufigkeiten ermittelt und **keine** eigenen Lexikaldaten.
   Unser Paket enthält **nur synthetische Beispielanker**, keine ungeprüfte
   „echte“ Grammatikontologie.

## Begrenzte, typisierte Kanteninterpretation

Die einzigen von R1.11-B auswertbaren Property-Kanten sind `P31` und `P279`.
Ein Pfad wird ausschließlich dann verfolgt, wenn das Profil den *genauen*
Property-Verlauf deklariert, z. B. `[["P31"], ["P31","P279"]]`.
Die Relation `P279` wird niemals global/ungesteuert transitiv verfolgt.
Die erlaubte Pfadlänge beträgt maximal drei Schritte. Hinter einem ersten
`P31` oder `P279` sind nur explizit deklarierte `P279`-Schritte möglich.
Die P279-Unterklassenkette kann verschiedene Rollen berühren; deshalb
bedeutet auch ein übereinstimmender Pfad nur **Klassifikationskandidat**.

- Veraltete (`deprecated`) Wikidata-Kanten werden ignoriert.
- Enthält eine Kante Qualifikatoren, wird sie ignoriert: Der R1.3-Export
  enthält nur `hasQualifiers`, nicht deren vollständige Semantik.
- `P1889` bedeutet *nonidentical*, nicht grammatische Inkompatibilität.
- Labels und Lexem-Schreibweisen dienen nie zum Klassifizieren.
- Mehrere unterschiedliche `(dimensionId, facet)` bleiben als
  `multiple_candidates` erhalten. Mehrere Pfade zur selben Kombination
  werden als **mehrere originale Zeugnisse** gruppiert.
- `unclassified` bedeutet nur „mit dem vorhandenen Graph und Profil nicht
  nachgewiesen“, keinesfalls „keine grammatische Funktion“.
- Scope, Sprache, Kongruenz, synthetische Forms, XOR zwischen
  Singular/Plural und `P5713`-Modalität werden aus diesem Graph nicht
  abgeleitet. Der Resolver zertifiziert **keine** Produktionsregel.

## Neue D-Schnittstellen

`source/wikidata/grammar_dimension.d` enthält:

```d
ItemGraph parseItemGraph(JSONValue r13);
DimensionProfile parseDimensionProfile(JSONValue reviewedProfile);
FeatureClassification classifyFeature(ref ItemGraph graph,
    ref DimensionProfile profile, string featureQId);
JSONValue asJson(FeatureClassification result);
JSONValue evaluateDimensionFixture(JSONValue graph, JSONValue profile,
    JSONValue checks);
```

`FeatureClassification.kind` ist `unclassified`, `candidate` oder
`multipleCandidates`, **nicht** `supported` als grammatical truth.
`DimensionCandidate` bewahrt jeden möglichen Facet/Dimensionspfad und
`ClassificationWitness` die Statement-IDs, Q-Knoten, Property-Folge und
Profilquelle. Die Snapshot-Metadaten für fehlende Knoten/Trunkierung werden
im Ergebnis erhalten.

## Reproduzierbare Tests

Die neue Regression verwendet ausschließlich **synthetische** Q-Graphen
und synthetische Metadatenanker. Kein Q-Item wird als tatsächliche Wikidata-
Aussage ausgegeben. Ein separater Python-Oracle bestätigt 11/11 Fälle.

```bash
python3 tools/r1_11b_reference.py
python3 tools/r1_11b_graph_inventory.py --self-test

dub test --compiler=dmd --force
dub test --compiler=ldc2 --force

dmd -i -I=source examples/catalog_feature_classification.d \
    -of=/tmp/wikidata-r1-11b-classification
/tmp/wikidata-r1-11b-classification \
    research/r1-11b-synthetic-graph.json \
    research/r1-11b-synthetic-profile.json \
    research/r1-11b-synthetic-checks.json \
    /tmp/wikidata-r1-11b-evaluation.json
```

Zu prüfende Fälle: direkte `P31`-Relation, ausdrücklich begrenzter
`P31`→`P279`-Pfad, mehrere Dimensionskandidaten, zwei Zeugnispfade für
nur eine Dimension, nicht freigegebenes `P279`, `deprecated`, unlesbare
Qualifikatoren, `P1889`, fehlende Zwischendaten und andere Facets.

## Der nächste reale Wikidata-Schritt (ohne Netzwerk)

Die Q-Graph-Rohdaten aus R1.3 liegen, sofern der frühere Forschungslauf
abgeschlossen wurde, bereits unter `reports/local/r1-3/feature-graph.json`.
Aus ihnen wird zunächst ein **unbegutachtetes Zielinventar** erstellt:

```bash
python3 tools/r1_11b_graph_inventory.py \
  --graph reports/local/r1-3/feature-graph.json \
  --features /tmp/wikidata-r1-11/data/r1-6-cross-language-evidence.json \
  --output reports/local/r1-11b/unreviewed-anchors.json
```

Dieses Inventar zählt originale direkte Kanten `P31`/`P279` aus den
acht Stichproben. Es zeigt mögliche Q-Typanker mit Original-Statement-IDs,
klassifiziert aber **keine** Dimension automatisch. Es markiert fehlende
Feature-Q-Items und übersprungene qualifizierte/deprecated Kanten.

Nach Begutachtung der tatsächlichen Ziel-Items können wir ein versioniertes
Profil mit belegten Typankern erstellen, und erst dann echte R1.11-B-
Klassifikationstests laufen lassen. Ohne einen begutachteten Anker gibt es
keinen seriösen automatischen `number`/`gender`/`noun_class`-Zuordnungsbeweis.

## Nicht gelöst

- R1.3-Graphdaten sind keine vollständige Q-Item-Ontologie; Daten können
  aus unterschiedlichen Zeitpunkten stammen.
- Begutachtung der realen Anker und Validierung der Rollen von Q-Knoten
  (insbesondere Kisuaheli-Nominalklassen) sind offen.
- Vollständige Qualifikatorsemantik für Q-Item-Aussagen benötigt später
  einen reichhaltigeren Graphsnapshot.
- Syntax einer künftigen DSL, vollständige Artikelregeln und Kongruenz sind
  noch **nicht** implementiert.
- Die vorläufige Probe-Tabelle aus R1.11-A ist ein Forschungsartefakt, kein
  produktiver Bestandteil von `wikidata-d`.
