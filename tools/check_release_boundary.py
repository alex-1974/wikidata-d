#!/usr/bin/env python3
"""Production source gate: exact, dependency-closed 10-module wikidata-d API.

No Research code belongs in DUB's sourcePaths; the source modules are the
ONLY permitted D modules under source/.  This checker is a development gate,
not compiled into the library.  No network access.
"""
import argparse
import json
import re
import tempfile
from pathlib import Path

CORE = frozenset('batch_cache catalog catalog_matcher client coverage form_lookup lexeme lexical_categories query relations'.split())
KEEP_EXAMPLES = frozenset('catalog_category_coverage catalog_coverage catalog_form_coverage catalog_lookup inspect lookup relations'.split())
IMPORT = re.compile(r'\bimport\s+wikidata\.([A-Za-z_][A-Za-z_0-9]*)')


def inspect(root: Path) -> dict:
    src = root / 'source' / 'wikidata'
    if not src.is_dir():
        raise ValueError('source/wikidata missing')
    files = sorted((root / 'source').rglob('*.d'))
    actual = {p.stem for p in files if p.parent == src}
    if len(files) != len(actual) or actual != CORE:
        raise ValueError('Production module inventory differs: extra=%s missing=%s, files=%d' %
                         (sorted(actual - CORE), sorted(CORE - actual), len(files)))
    cfg = json.loads((root / 'dub.json').read_text('utf-8'))
    if cfg.get('sourcePaths') != ['source'] or cfg.get('targetType') != 'library':
        raise ValueError('Unexpected DUB sourcePaths/targetType')
    examples = root / 'examples'
    if not examples.is_dir():
        raise ValueError('Production examples directory missing')
    present = {x.stem for x in examples.glob('*.d')}
    if present != KEEP_EXAMPLES:
        raise ValueError('Unexpected production examples: extra=%s missing=%s' %
                         (sorted(present-KEEP_EXAMPLES), sorted(KEEP_EXAMPLES-present)))
    edges = []
    for path in files + sorted(examples.glob('*.d')):
        for target in IMPORT.findall(path.read_text('utf-8')):
            if target not in CORE:
                raise ValueError('Research import in production: %s -> wikidata.%s' % (path.relative_to(root), target))
            edges.append([path.relative_to(root).as_posix(), target])
    forbidden = [*list((root/'tools').glob('r1_*.py')),
                 *list((root/'source').rglob('*_test.d')),
                 *list((root/'source').rglob('grammar_*.d'))]
    if any((root / x).exists() for x in ('legacy', 'grammar_contracts')) or forbidden:
        raise ValueError('Research content present in core: %s' % forbidden)
    return dict(modules=sorted(actual), examples=sorted(present), edges=edges,
                sourceCount=len(files), exampleCount=len(present))


def selftest():
    with tempfile.TemporaryDirectory(prefix='wikidata-boundary-selftest-') as td:
        root = Path(td)
        (root/'source/wikidata').mkdir(parents=True)
        (root/'examples').mkdir()
        (root/'dub.json').write_text(json.dumps({'targetType':'library','sourcePaths':['source']}))
        for m in CORE:
            (root/f'source/wikidata/{m}.d').write_text('module wikidata.%s;\n' % m)
        for m in KEEP_EXAMPLES:
            (root/f'examples/{m}.d').write_text('import wikidata.client;\n')
        assert inspect(root)['sourceCount'] == 10
        bad = root / 'source/wikidata/grammar_bad.d'
        bad.write_text('module wikidata.grammar_bad;\n')
        try: inspect(root)
        except ValueError: pass
        else: raise AssertionError('Stray research module accepted')
        bad.unlink()
        c = root / 'source/wikidata/client.d'
        c.write_text('import wikidata.grammar_bad;')
        try: inspect(root)
        except ValueError: pass
        else: raise AssertionError('Research import accepted')
        c.write_text('module wikidata.client;\n')
        assert inspect(root)['sourceCount'] == 10
        print('PASS: 3/3 core-boundary synthetic tests')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repo', type=Path, default=Path.cwd())
    p.add_argument('--self-test', action='store_true')
    p.add_argument('--json-out', type=Path)
    args = p.parse_args()
    if args.self_test:
        selftest()
        return
    value = inspect(args.repo.resolve())
    if args.json_out:
        args.json_out.write_text(json.dumps(value, indent=2)+'\n')
    print('PASS: 10 D core modules, 7 production examples, %d imports; no research modules' % len(value['edges']))

if __name__ == '__main__':
    main()
