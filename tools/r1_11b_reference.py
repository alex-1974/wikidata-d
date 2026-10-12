#!/usr/bin/env python3
"""Independent offline reference for R1.11-B's 11 synthetic graph tests."""
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent / 'research'


def classify(nodes, anchors, feature):
    dimensions = {}
    for anchor in anchors:
        witnesses = []
        for path in anchor['allowedPaths']:
            def visit(q, pos, visited, statements):
                if pos == len(path):
                    if q == anchor['rootQId']:
                        witnesses.append(statements)
                    return
                for edge in nodes.get(q, {}).get('edges', []):
                    if edge['property'] != path[pos] or edge['rank'] == 'deprecated':
                        continue
                    if edge.get('hasQualifiers') or edge['target'] in visited:
                        continue
                    visit(edge['target'], pos + 1,
                          visited + [edge['target']], statements + [edge['statementId']])
            visit(feature, 0, [feature], [])
        if witnesses:
            key = (anchor['dimensionId'], anchor['facet'])
            dimensions.setdefault(key, []).extend(witnesses)
    return ('unclassified' if not dimensions else
            'candidate' if len(dimensions) == 1 else 'multiple_candidates',
            len(dimensions), sum(map(len, dimensions.values())))


def main():
    graph = json.loads((BASE/'r1-11b-synthetic-graph.json').read_text())
    profile = json.loads((BASE/'r1-11b-synthetic-profile.json').read_text())
    checks = json.loads((BASE/'r1-11b-synthetic-checks.json').read_text())
    for check in checks['checks']:
        status, count, witnesses = classify(graph['nodes'], profile['anchors'],
                                             check['featureQId'])
        assert status == check['expectedStatus'], check
        assert count == check['expectedCandidates'], check
        assert witnesses == check['expectedWitnesses'], check
        print(f"{check['id']}: {status} ({count} dimension(s), {witnesses} witness(es))")
    print(f"R1.11-B SYNTHETIC REFERENCE: PASS ({len(checks['checks'])} checks)")


if __name__ == '__main__':
    main()
