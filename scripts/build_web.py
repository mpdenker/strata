#!/usr/bin/env python3
"""Build a static copy of the website into dist/ (web/ + Content/ + the generated files).

    python3 scripts/build_web.py

dist/ can be opened with any static file server, e.g. `python3 -m http.server -d dist`.
"""
import json, pathlib, shutil, sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from serve import ROOT, WEB, CONTENT, generated  # noqa: E402

DIST = ROOT / "dist"
if DIST.exists():
    shutil.rmtree(DIST)
shutil.copytree(WEB, DIST, ignore=shutil.ignore_patterns("tests", ".DS_Store"))
shutil.copytree(CONTENT, DIST / "content", ignore=shutil.ignore_patterns(".DS_Store"))
for path, data in generated().items():
    (DIST / path.lstrip("/")).write_text(json.dumps(data, indent=1))
count = len(generated()["/content/index.json"]["lessons"])
print(f"Built dist/ with {count} lessons.")
