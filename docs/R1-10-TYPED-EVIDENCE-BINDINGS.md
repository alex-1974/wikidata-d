# R1.10 – Typisierte Evidenzbindungen (Forschungsstand)

**Ziel:** R1.8/R1.9 werten originale Aussagen und ihre logischen Kombinationen aus. R1.10 darf solche Nachweise nur dann verknüpfen, wenn sie auf dieselben ausdrücklich gebundenen Entitäten und denselben Konstruktionskontext verweisen.

**Wichtig:** `supported` bescheinigt eine *gemeinsame Evidenzbindung*, **nicht** eine grammatisch gültige Wortfolge. Die Engine erzeugt weder Lexeme noch Forms noch Senses. Kein implizites `not`, keine automatische `P279`-Vererbung, kein `P1889`-Unverträglichkeitsbeweis.

## Implementierte Grenzen

* Neues Modul `source/wikidata/grammar_binding.d` – R1.8/R1.9 werden **nicht** geändert.
* Getypte `BindingVariable`, `BindingValue`, `EvidenceBinding` mit `BindingType` (lexeme/form/sense/feature/language/statement/role).
* `EvidenceCandidate`: `caseId`, `languageId`, `constructionId`, getypte Bindungen und originale `EvidenceProof[]`.
* `BoundAtom`: Menge vorhandener Alternativen für eine explizite Voraussetzung.
* `BoundConstraint`: Variablendeklarationen, mindestens eine explizite `joinOn`-Variable und nichtleere Atommenge.
* `BoundEvaluation`: `supported` bei belegten, konsistenten gemeinsamen Bindungen, sonst `unknown`; alle unabhängigen Kandidaten/Beweispfade erhalten.
* Identität wird ausschließlich über (Variablentyp, **Original-ID**) geprüft – niemals über Darstellungstext. Jedes gemeinsam benutzte Variablenlabel muss gleichen Typ und dieselbe ID haben.
* `caseId`, `languageId` und `constructionId` aller Kandidaten müssen zu der Regel passen. Ein fehlender Pflicht-Join-Schlüssel ist **ein Konfigurationsfehler**, kein kartesisches Produkt.
* Reine Aggregatstatistiken können keine atomaren Form-Witnesses erzeugen. `scanAttestedSource` akzeptiert nur R1.8-`statementExists` mit tatsächlich vorhandenen Originalaussagen, einschließlich Qualifikatorprüfung auf demselben Statement.
* Synthetische Kandidaten benötigen die ausdrückliche, standardmäßig deaktivierte `allowSynthetic`-Freigabe. Attestierte Kandidaten benötigen originale Statement-Provenienz. Testdaten werden niemals zu Wikidata-Fakten hochgestuft.
* Unbestätigte Alternativen führen zu `unknown`, nicht zu `contradicted`.
* Harte Grenzen: höchstens 64 deklarierte Variablen, Join-Variablen und Atome; maximal 8.192 Ergebnis-Witnesses, sonst Fehler und kein stilles Abschneiden. Noch kein optimierter Hash-Join oder Produktions-API-Freeze.

## Neue API

```d
import wikidata.grammar_binding;

// Alles typisiert, Sprache und Kontext explizit.
BoundConstraint rule;
rule.id = "evidence-join";
rule.caseId = "de-examples";
rule.languageId = "Q188";
rule.constructionId = "example-argument";
rule.variables ~= BindingVariable("sense", BindingType.sense);
rule.joinOn ~= "sense";

// 'predicate' muss eine R1.8-Statement-Prüfung mit realer Quelle sein.
rule.atoms ~= scanAttestedSource(index, predicate,
    "nominative-subject", "sense", BindingType.sense,
    rule.languageId, rule.constructionId);

BoundEvaluation result = evaluateBound(rule);
// result.status = supported nur bei nachgewiesenem Treffer;
// result.candidates enthält Original-Statement-IDs und Qualifikatoren.
```

Die Sprache des Lexems wird im *bestehenden* R1.7-Snapshot nicht auf Statement-Ebene gespeichert. Deshalb muss der Aufrufer `languageId` anhand eines **gesondert verifizierten Lexemdatensatzes** übergeben. R1.10 prüft Scope-Gleichheit, aber kann die sprachliche Herkunft der IDs aus diesem Snapshot nicht unabhängig verifizieren. Das ist eine explizite Integrationsanforderung für die spätere produktive API.

## Tests

### Quality Gates

```bash
dub test --compiler=dmd --force
dub test --compiler=ldc2 --force
```

R1.8/R1.9 bleiben durch ihre eigenen Tests/Beispiele regressionsgeschützt (15 bzw. 17 Originalfälle).

### Zehn synthetische Bindungsfälle

```bash
dmd -i -I=source examples/catalog_grammar_binding.d -of=/tmp/wikidata-binding-synthetic
/tmp/wikidata-binding-synthetic \
    research/r1-10-binding-regressions.json \
    /tmp/wikidata-r1-10-synthetic-evaluation.json
```

Erwartet: `R1.10 SYNTHETIC BINDING REGRESSION: PASS (10 cases)`.

Die Fälle sind aus der erfolgreich geprüften Python-Referenz R1.10 übertragen: dieselbe Form, unterschiedliche Forms, gleicher Text/differente Form-IDs, Sense-Isolierung, zwei attestierte Alternativen, Sprachgrenze, übereinstimmende/nicht übereinstimmende Rollenmerkmale, fehlender Positivnachweis und fehlende Join-Variable (erwarteter Fehler). **Es sind synthetische Probe-IDs, keine Wikidata-Fakten.**

### Neun reale Wikidata-Nachweise aus dem vorhandenen Snapshot

```bash
dmd -i -I=source examples/catalog_grammar_binding_attested.d \
    -of=/tmp/wikidata-binding-attested
/tmp/wikidata-binding-attested \
    /tmp/wikidata-r1-7/data/attested-evidence.json \
    /tmp/wikidata-r1-7/data/reference-predicates.json \
    research/r1-10-attested-checks.json \
    /tmp/wikidata-r1-10-attested-evaluation.json
```

Erwartet: `R1.10 ATTESTED BINDING REGRESSION: PASS (9 checks)`.

Die Tests binden reale Forms/Senses/Lexeme aus Italienisch, Deutsch, Türkisch und Kisuaheli und bewahren Statement-IDs/Qualifikatoren. Zwei auf denselben Kisuaheli-Sense bezogene Aussagen werden als **gemeinsam beobachtet**, nicht ohne gesonderte Regel als obligatorische Kongruenz oder Konjunktion ausgelegt. Die arabische Aggregatstatistik eignet sich nicht für die Bindung einer konkreten Form-ID.

**Netzwerk:** Keines der R1.10-Beispiele benötigt Netzwerkzugriff.

## Noch ausdrücklich offen

1. Integration in den M5.11-Form-Resolver, inklusive echter lexemweiter Sprachzuordnung und notwendiger grammatischer Dimensionen.
2. Ein Operator für belegte Form-zu-Form-Beziehungen (P11952/P11953), ohne erfundene Kehrbeziehungen.
3. Performance: aktuell einfacher, hart begrenzter Natural-Join statt indiziertem Hash-Join.
4. Präzise Behandlung von Aussagen, die in Wikidata als *üblich*, *wahlweise* oder *verpflichtend* modelliert werden. Mehrfaches P5713 belegt keine automatische Konjunktion.
5. Keine Morphologie-Synthese oder automatische Lautanalyse. Das Modell ist eine **IR-Forschungsstufe**, kein eingefrorenes Grammatik-DSL-Schema.
