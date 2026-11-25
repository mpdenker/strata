#!/bin/sh
# Runs the website's logic and content tests with macOS's built-in JavaScript engine (no Node needed).
cd "$(dirname "$0")/.." || exit 1
JSC=/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc
LESSONS=$(python3 -c "import json,pathlib; c=pathlib.Path('Content'); print(json.dumps(sorted(str(p.relative_to(c)) for p in (c/'Lessons').rglob('*.json'))))") || exit 1
OUT=$("$JSC" -m web/tests/run-jsc.js -- "$(pwd)" "$LESSONS" 2>&1)
STATUS=$?
echo "$OUT"
[ $STATUS -eq 0 ] || exit $STATUS
echo "$OUT" | grep -q '^All [0-9]* tests passed' || exit 1
