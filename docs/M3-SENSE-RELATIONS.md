# M3 – Navigation in the Wikidata Sense graph

This increment builds a query for the **immediate neighbours of one Sense**
and parses its SPARQL result as typed, provenance-preserving relation edges.
The network remains in the existing `WikidataClient`; no GUI or SQLite code
has been added.

## Semantic boundary

| Property | Operation | What we may conclude |
| --- | --- | --- |
| P5137 | Two Senses refer to the same Q item | Shared concept; *possible* translation |
| P9970 | Two Senses refer to the same predicate Q item | Shared predicate; semantic peer |
| P5972 | Sense references another Sense | Direct recorded translation |
| P5973 | Sense references another Sense | Recorded synonym |
| P5974 | Sense references another Sense | Recorded antonym |

For P5972/P5973/P5974, query both `source → target` and `target → source`;
these represent the **stored** edge direction. The parser does not infer or
modify claims. A Q-item label is **not** upgraded to a Sense translation.

`SenseRelation` retains relation property, direction, shared Q-item if
applicable, target Lexeme ID, target Sense ID, lemma, language, category and
unmodified SPARQL binding row. Two edges with the same target but different
provenance must not be collapsed.

## Build and run on XPS

```sh
dub test --compiler=dmd
dub test --compiler=ldc2
dmd -i -I=source examples/relations.d -L-lcurl -of=relations
./relations
```

The live example queries only German matches for `L5577-S1` and `L38246-S1`.
The number of matches is **not asserted**: Wikidata changes over time and
the Query Service is eventually consistent. The output should indicate relation
type, stored direction, Sense/lexeme IDs, and any shared concept.

## Limitations and next work

- The query is deliberately limited to 100 rows per Sense. A full page **may
  be truncated**, and does not mean a complete set. Use a language constraint
  or introduce deterministic pagination for large-scale catalogue analysis.
- Graph expansion is **one hop** only, not unbounded recursive traversal.
- Not all translated Senses are linked via the covered relations.
- Full Wikidata statements (ranks, qualifiers, references) remain in the M2
  `getEntity` raw data. WDQS direct paths do not reproduce that provenance.
- Caching, HTTP 429/retry, batch requests, revisioning, catalogue mappings,
  and network tests are separate milestones.
- Query execution is synchronous and must not run on the dcanvas GUI thread.

References:
- https://www.wikidata.org/wiki/Wikidata:Lexicographical_data/Documentation/Query_Service
- https://www.wikidata.org/wiki/Property:P5972
