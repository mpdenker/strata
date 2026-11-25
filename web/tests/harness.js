// A tiny test runner with no dependencies. Runs in Safari's JavaScriptCore from the command line
// (scripts/test-web.sh) and in any browser (web/tests/index.html).

const tests = [];
export function test(name, fn) { tests.push({ name, fn }); }

export function eq(actual, expected, msg = '') {
  const a = JSON.stringify(actual), e = JSON.stringify(expected);
  if (a !== e) throw new Error(`${msg ? msg + ': ' : ''}expected ${e}, got ${a}`);
}
export function ok(cond, msg = 'expected true') { if (!cond) throw new Error(msg); }

export async function run(log) {
  let passed = 0, failed = 0;
  for (const t of tests) {
    try { await t.fn(); passed += 1; log(`  ✓ ${t.name}`); }
    catch (e) { failed += 1; log(`  ✗ ${t.name}\n      ${e.message}`); }
  }
  log(failed ? `FAILED: ${failed} of ${passed + failed} tests` : `All ${passed} tests passed`);
  return { passed, failed };
}
