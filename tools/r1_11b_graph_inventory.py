#!/usr/bin/env python3
"""Inspect the existing R1.3 Wikidata Q-item cache without network requests.

This tool proposes NO automatic semantic axis mappings. It emits original
P31/P279 target counts for human evaluation of reviewed anchor profiles.
"""
import argparse
from collections import defaultdict
import json
from pathlib import Path


def inventory(graph, research):
    if graph.get('schemaVersion') != 'r1.3-graph-audit-v1':
        raise ValueError('Expected original R1.3 graph schema')
    if research.get('schemaVersion') != 'r1.6-cross-language-evidence-v1':
        raise ValueError('Expected original R1.6 cross-language snapshot')
    nodes = graph.get('nodes', {})
    cases = research.get('cases', [])
    if not isinstance(nodes, dict) or not isinstance(cases, list):
        raise ValueError('Unexpected input structure')
    feature_cases = defaultdict(list)
    for case in cases:
        for qid in case.get('features', {}):
            feature_cases[qid].append(case['case'])
    by_relation = defaultdict(list)
    qualified = []
    deprecated = []
    unresolved = []
    for feature in sorted(feature_cases):
        item = nodes.get(feature)
        if not item:
            unresolved.append(feature)
            continue
        for edge in item.get('edges', []):
            if edge.get('source') != feature:
                raise ValueError('Mismatching original Q-edge source')
            prop = edge.get('property')
            if prop not in ('P31', 'P279'):
                continue
            if edge.get('rank') == 'deprecated':
                deprecated.append(edge.get('statementId'))
                continue
            if edge.get('hasQualifiers'):
                qualified.append(edge.get('statementId'))
                continue
            if not edge.get('statementId') or not edge.get('target'):
                continue
            by_relation[(prop, edge['target'])].append({
                'featureQId': feature,
                'statementId': edge['statementId'],
                'cases': sorted(feature_cases[feature]),
                'rank': edge['rank'],
                'hasReferences': edge.get('hasReferences', False),
            })
    targets = []
    for (prop, target), claims in by_relation.items():
        subjects = sorted({claim['featureQId'] for claim in claims})
        targets.append({
            'property': prop,
            'targetQId': target,
            'targetLabels': nodes.get(target, {}).get('labels', {}),
            'distinctSourceFeatures': len(subjects),
            'originalStatementCount': len(claims),
            'sourceQIds': subjects,
            'exampleOriginalStatements': claims[:12],
            'warning': 'Raw ontology link; NOT an approved grammatical dimension',
        })
    targets.sort(key=lambda x: (-x['distinctSourceFeatures'],
                                 x['property'], x['targetQId']))
    return {
        'schemaVersion': 'wikidata-r1.11b-unreviewed-anchors-v1',
        'graphStatus': graph.get('status'),
        'graphTruncated': graph.get('graphTruncated'),
        'graphMissingQIds': graph.get('missingQIds', []),
        'researchCases': len(cases),
        'observedFeatureQIds': len(feature_cases),
        'featuresMissingInGraph': unresolved,
        'qualifiedRelationStatementIdsDeferred': qualified,
        'deprecatedRelationStatementIdsSkipped': deprecated,
        'candidateTargets': targets,
        'policy': {
            'verifiedDimensions': False,
            'automaticAxisAcceptance': False,
            'noTransitiveP279': True,
            'noP1889Disjointness': True,
            'noLexicalSynthesis': True,
        }
    }


def self_test():
    g = {'schemaVersion': 'r1.3-graph-audit-v1', 'status': 'partial',
         'graphTruncated': True, 'missingQIds': ['Q2'], 'nodes': {
             'Q1': {'edges': [
                 {'source': 'Q1', 'property': 'P31', 'target': 'Q4',
                  'statementId': 'Q1$s1', 'rank': 'normal',
                  'hasQualifiers': False, 'hasReferences': True},
                 {'source': 'Q1', 'property': 'P1889', 'target': 'Q5',
                  'statementId': 'Q1$s2', 'rank': 'normal'}]},
             'Q4': {'edges': [], 'labels': {'en': 'synthetic type'}}}}
    r = {'schemaVersion': 'r1.6-cross-language-evidence-v1',
         'cases': [{'case': 'test', 'features': {'Q1': 2, 'Q2': 1}}]}
    result = inventory(g, r)
    assert result['observedFeatureQIds'] == 2
    assert result['featuresMissingInGraph'] == ['Q2']
    assert len(result['candidateTargets']) == 1
    assert result['candidateTargets'][0]['originalStatementCount'] == 1
    assert not result['policy']['verifiedDimensions']
    print('R1.11-B Q-GRAPH INVENTORY SELF-TEST: PASS')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--self-test', action='store_true')
    p.add_argument('--graph', type=Path)
    p.add_argument('--features', type=Path)
    p.add_argument('--output', type=Path)
    args = p.parse_args()
    if args.self_test:
        self_test()
        return
    if not all([args.graph, args.features, args.output]):
        p.error('--graph, --features and --output are all required')
    graph = json.loads(args.graph.read_text(encoding='utf-8'))
    research = json.loads(args.features.read_text(encoding='utf-8'))
    result = inventory(graph, research)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n',
                           encoding='utf-8')
    print('R1.11-B INVENTORY: PASS;', result['observedFeatureQIds'],
          'observed feature Q-IDs;', len(result['candidateTargets']),
          'unreviewed ontology target(s);', len(result['featuresMissingInGraph']),
          'feature Q-items missing from graph')
    print('Report:', args.output)


if __name__ == '__main__':
    main()
