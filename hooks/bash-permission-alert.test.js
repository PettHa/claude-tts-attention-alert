'use strict';

// Smoke test: spoken-phrase helper.
// Run with: node bash-permission-alert.test.js
// Exits 0 on success, 1 on any failed assertion.

const { pickPhrase } = require('./bash-permission-alert');

let failed = 0;
function eq(actual, expected, label) {
  const ok = JSON.stringify(actual) === JSON.stringify(expected);
  if (!ok) {
    failed += 1;
    console.error(`FAIL ${label}: got ${JSON.stringify(actual)}, expected ${JSON.stringify(expected)}`);
  } else {
    console.log(`ok   ${label}`);
  }
}

eq(pickPhrase('rm -rf /tmp/x'), 'Bash permission needed: rm', 'verb extracted: rm');
eq(pickPhrase('git push --force'), 'Bash permission needed: git', 'verb extracted: git');
eq(pickPhrase('  npm  install  '), 'Bash permission needed: npm', 'verb extracted with whitespace');
eq(pickPhrase(''), 'Bash permission needed', 'empty command falls back to generic');
eq(pickPhrase('   '), 'Bash permission needed', 'whitespace-only falls back');
eq(pickPhrase('SUDO whoami'), 'Bash permission needed: sudo', 'verb is lowercased');

if (failed > 0) {
  console.error(`\n${failed} assertion(s) failed`);
  process.exit(1);
}
console.log('\nall tests passed');
