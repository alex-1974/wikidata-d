#!/usr/bin/env python3
"""Offline, pinned-scope DMD Ddoc render with explicit inline-code macro."""
import argparse
import html
import json
import re
import subprocess
from pathlib import Path

MODULES = ("batch_cache", "catalog", "catalog_matcher", "client", "coverage",
           "form_lookup", "lexeme", "lexical_categories", "query", "relations")
REQUIRED = {
    "catalog": ("Exception",),
    "client": ("wbgetentities", "entities"),
    "lexical_categories": ("Exception", "?category", "?ancestor"),
    "relations": ("results.bindings",),
}
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--compiler", default="dmd")
    args = parser.parse_args()
    repo = args.repo.resolve()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    macro = repo / "docs/ddoc/macros.ddoc"
    if not macro.is_file():
        parser.error("missing docs/ddoc/macros.ddoc")
    rows = []
    for module in MODULES:
        src = repo / "source/wikidata" / (module + ".d")
        if not src.is_file():
            parser.error("missing module: " + module)
        dest = out / (module + ".html")
        subprocess.run([args.compiler, "-D", "-o-", "-I=" + str(repo / "source"),
                        "-Df=" + str(dest), str(src), str(macro)],
                       cwd=repo, check=True)
        rendered = dest.read_text(encoding="utf-8")
        # Exact code snippets, avoiding false positives from a plain text search.
        codes = re.findall(r"<code(?:\s[^>]*)?>(.*?)</code>", rendered, re.S)
        decoded = [html.unescape(re.sub(r"<[^>]*>", "", code)) for code in codes]
        absent = [term for term in REQUIRED.get(module, ()) if term not in decoded]
        rows.append({"module":module,"bytes":dest.stat().st_size,
                     "required_inline_code":list(REQUIRED.get(module, ())),
                     "missing_required_inline_code":absent})
        print(("PASS" if not absent else "FAIL") + ": " + module +
              ((" missing " + repr(absent)) if absent else ""))
    report = {"kind":"DMD Ddoc rendering only; DDOX is a separate gate",
              "modules":rows}
    (out / "report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf8")
    if any(r["missing_required_inline_code"] for r in rows):
        raise SystemExit("FAIL: missing macro-rendered code terms")
    print("PASS: 10 HTML documents; sampled inline-code terms preserved")
if __name__=="__main__":
    main()
