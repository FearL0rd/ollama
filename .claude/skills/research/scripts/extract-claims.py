#!/usr/bin/env python3
"""
extract-claims.py — pull atomic claims with citations out of a rendered
/docs/research/<slug>.md into JSONL.

Usage:
  python3 extract-claims.py <doc.md>             # writes to stdout
  python3 extract-claims.py <doc.md> -o out.jsonl

Heuristic parser. Looks for `### Finding ...` blocks and extracts:
  - assertion (first sentence under the heading)
  - confidence (line `Confidence: high|medium|low|conjecture`)
  - source IDs (e.g. `[S-0007]` markers in evidence list)
  - quote (text inside `> "..."` blockquotes following the assertion)

Round-trip rule: anything this script cannot parse is malformed. The
synthesize agent must keep its output parseable by this script.
"""
from __future__ import annotations
import argparse, json, re, sys
from pathlib import Path

FINDING_RE = re.compile(r"^###\s+Finding\s+(?P<id>F-\d{4})\s*[-:]\s*(?P<title>.+)$")
CONF_RE    = re.compile(r"^\*?\*?Confidence\*?\*?\s*[:：]\s*(?P<c>high|medium|low|conjecture)", re.I)
SOURCE_RE  = re.compile(r"\[(S-\d{4})\]")
QUOTE_RE   = re.compile(r'^>\s*"(?P<q>[^"]+)"\s*\[(?P<s>S-\d{4})\]')

def parse(doc: Path):
    lines = doc.read_text(encoding="utf-8").splitlines()
    claims = []
    i = 0
    while i < len(lines):
        m = FINDING_RE.match(lines[i].strip())
        if not m:
            i += 1; continue
        fid, title = m.group("id"), m.group("title").strip()
        # body until next ### or ## or end
        body, j = [], i + 1
        while j < len(lines) and not lines[j].startswith("## ") and not lines[j].startswith("### Finding "):
            body.append(lines[j]); j += 1
        body_text = "\n".join(body).strip()
        # assertion = first non-empty paragraph
        assertion = ""
        for chunk in body_text.split("\n\n"):
            chunk = chunk.strip()
            if chunk and not chunk.startswith(">") and not chunk.startswith("*"):
                assertion = chunk.split("\n")[0].strip(); break
        # confidence
        conf = "unknown"
        for ln in body:
            cm = CONF_RE.match(ln.strip())
            if cm: conf = cm.group("c").lower(); break
        # quotes + source ids
        evidence = []
        for ln in body:
            qm = QUOTE_RE.match(ln.strip())
            if qm:
                evidence.append({"quote": qm.group("q"), "source_id": qm.group("s")})
        sources = sorted({s for s in SOURCE_RE.findall(body_text)})
        claims.append({
            "id": fid,
            "title": title,
            "assertion": assertion,
            "confidence": conf,
            "evidence": evidence,
            "sources": sources,
        })
        i = j
    return claims

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("doc")
    ap.add_argument("-o", "--out", default=None)
    args = ap.parse_args()
    claims = parse(Path(args.doc))
    out = sys.stdout if not args.out else open(args.out, "w", encoding="utf-8")
    for c in claims:
        out.write(json.dumps(c, ensure_ascii=False) + "\n")
    if args.out: out.close()

if __name__ == "__main__":
    main()
