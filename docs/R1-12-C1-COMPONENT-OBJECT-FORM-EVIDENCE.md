# R1.12-C1 – Typisierte Evidenz für referenzierte Komponentenformen

**Stand:** 13. Oktober 2026. **Status:** XPS-qualifiziert (DMD 2.111.0 / LDC 1.41.0), PR vorbereitet; keine produktive Grammatikfreigabe.

## Originalquellen

Aus dem 22-Lexeme-Archiv R1.12-B2 (20 Cross-Family-Fälle + 2 separat geladene türkische Komponentenlexeme):

- Eigentümerlexem `L729698`, Revision `2272830740`, SHA-256 `5cf4651319ba6e8c972fa935eb3f6381caac38a6dad0395a49aab8601199a8ea`.
- `P5238`-Statement `L729698$f428c2c1-461f-f4c9-c2e8-4d868fd7f48d` verweist auf `L728512`, hat `P1545 = "2"` sowie einen einzelnen `P5548` mit `datatype=wikibase-form`, `entity-type=form`, `id=L728512-F1`.
- Ziellexem `L728512`, Revision `2429128721`, SHA-256 `fe2f8ad073fd8e26ea61b81bed69ce30aa6a69322f579ed7d77f706489e360de`. Seine `forms[]` enthalten `L728512-F1` explizit mit Darstellungen `tr=ci`, `ota=جی`.
- Zweites `P5238`-Statement `L729698$9b1792d5-464d-0c71-cd89-7231f1d18e05` verweist auf `L729694` mit `P1545 = "1"`, **ohne** `P5548`. Das Ziel hat nur eine Form; diese darf **nicht** implizit als ausgewählt gelten.

Alle Originalbytes, Referenzen und GUIDs bleiben beim Aufrufer/Receipt. Beide Ziellexeme wurden in verschiedenen Revisionen archiviert; es gibt keinen atomaren Gesamt-Snapshot und keine externe Referenz an den zwei Komponentenstatements. Die Prüfung belegt Original-Wikidata-Aussagen und Formmitgliedschaft, nicht die linguistische Richtigkeit oder eine produktive Regel.

## Änderungsumfang

1. `grammar_evidence_composition.d` erhält die additive, schreibgeschützte API `receiptFormMembership(receipt, formId)` und den Datenträger `OriginalFormMembership`. Sie vergleicht die **Original-Form-ID** mit der aus bytegeprüften Originalbytes re-parsten Liste und nennt den ursprünglichen JSON-Pfad. Identischer Formtext führt nie zur Identitätsfusion.
2. Neues Modul `grammar_component_form_evidence.d`: `ComponentObjectFormEvidence`, `ComponentObjectFormStatus` und zwei Überladungen von `attestComponentObjectForm(owner, component[, target])`.
3. Eigenes Testmodul und Originaldaten-Replay.

### Statusverträge

| Status | Fachliche Aussage |
|---|---|
| `sourceNotVerified` | Eigentümer/Witness oder ausdrücklich übergebener Ziel-Receipt nicht verifiziert |
| `noObjectFormQualifier` | Im Originalstatement fehlt `P5548`; keine implizite Auswahl |
| `targetNotFetched` | Explizit gültiger `P5548`-Wert, Ziel-Receipt nicht übergeben |
| `invalidOrAmbiguousQualifier` | `P5548`-Snak fehlt an Syntax/Typvalidierung oder kommt mehrfach vor |
| `targetIdentityMismatch` | Separat verifiziertes Ziel gehört nicht zur originalen `P5238`-Objekt-ID |
| `formNotPresentInTargetSnapshot` | Eindeutige `P5548`-Form steht nicht in genau diesem verifizierten Ziel-Snapshot |
| `verifiedTargetFormMembership` | Explizites `P5548`, exakter Form-ID-Treffer unter passendem, verifiziertem Ziellexem |

**Semantikgrenzen:** Alle Ergebnisobjekte geben `permitsFormSelection`, `permitsGrammarProduction` und `permitsGeneralFormSenseAssociation` als `false` zurück. `P1545` ist eine ursprüngliche Zeichenfolge, keine Berechtigung zur Wortbildung. Ein fehlender Ziel-Snapshot oder eine im geprüften Snapshot fehlende Form impliziert keine zeitübergreifende Negativaussage. Veränderte, doppelte, veraltete, falsch typisierte oder unreferenzierte Statements führen nie zu einem positiven Status.

## Trust Boundary und Tests

Die verwendeten `OriginalLexemeReceipt`-Objekte müssen zuvor mit `verifyOriginalLexemeBytes` aus den archivierten Originalantwortbytes und SHA-256-/Revision-Metadaten erstellt werden. Das beweist Bytekonsistenz relativ zum gelieferten Hash, **nicht** die Herkunft der Bytes von Wikimedia. Der separate R1.12-B2-Audit prüft Quelle und Archiv-Manifest. `composeComponents` bestätigt die originale Owner-Witness-Mitgliedschaft; eine vom Aufrufer manipulierte `ComponentWitness`-Kopie wird nicht akzeptiert. `receiptFormMembership` verwendet das unabhängig geprüfte Ziellexem; die beiden Revisionsnummern werden getrennt zurückgegeben.

Erfolgreiche XPS-Prüfungen: DMD 2.111.0 und LDC 1.41.0 (isolierte Tests, vollständiges `dub test`, Release-Build), Originaldaten-Replay auf `L729698` / `L728512` / `L729694`, 52 archivierte SHA-256-Dateien und lokale Git-Status-Invarianz.

## Folgearbeiten

R1.12-C2: Sense-eigene und andere ownergebundene `P5831`-Verwendungsbeispiele. R1.12-C3: Mehrsprachige/repräsentationsspezifische Form-Views. **Keine** sprachabhängigen Sonderfalllisten und keine automatische Ergänzung von Wikidata-Daten.


## XPS-Qualifikation (13.10.2026)

- Basis: `e5738f14860f21256ca6480f5a953c71cda80d64` (`develop`).
- DMD 2.111.0 und LDC 1.41.0: jeweils 6 Module in isolierten Tests und 23 Module im vollständigen `dub test` **PASS**.
- Release-Build mit beiden Compilern **PASS**.
- Originaldaten-Replay: die drei türkischen Lexeme `L729698`, `L728512`, `L729694`, mit expliziter `P5548`-Formmitgliedschaft und ohne implizite Auswahl, **PASS**.
- Originalbestandsprüfung: 22/22 Lexeme und 52 Archiv-Manifesteinträge **PASS**.
- Das XPS-Ergebnisarchiv hat 28/28 SHA-256-Einträge bestanden.
- Der aktive `develop`-Checkout blieb unverändert; die lokale Änderung an `examples/lookup.d` wurde bewahrt.
- Die drei D-Dateien sind byteidentisch mit den qualifizierten Paketdateien. GitHub-PR-CI ist ein weiteres, unabhängiges Gate.
