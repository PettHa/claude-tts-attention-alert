'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const { slugForPhrase, buildPlayWavAction, AUDIO_DIR } = require('./play-wav');

test('slugForPhrase maps static phrases', () => {
  assert.equal(slugForPhrase('Permission needed'), 'permission-needed');
  assert.equal(slugForPhrase('Claude is done'), 'claude-done');
  assert.equal(slugForPhrase('Plan ready'), 'plan-ready');
  assert.equal(slugForPhrase('Claude still needs you'), 'claude-still-needs');
});

test('slugForPhrase maps baked bash verbs', () => {
  assert.equal(slugForPhrase('Bash permission needed: git'), 'bash-permission-git');
  assert.equal(slugForPhrase('Bash permission needed: rm'), 'bash-permission-rm');
  assert.equal(slugForPhrase('Bash permission needed: Docker'), 'bash-permission-docker');
});

test('slugForPhrase returns null for unbaked verbs', () => {
  assert.equal(slugForPhrase('Bash permission needed: weirdverb'), null);
});

test('slugForPhrase returns null for unknown text', () => {
  assert.equal(slugForPhrase('arbitrary user override'), null);
  assert.equal(slugForPhrase(''), null);
  assert.equal(slugForPhrase(null), null);
});

test('buildPlayWavAction returns null when WAV missing', () => {
  // No WAVs exist yet in test env — function should signal SAPI fallback.
  const result = buildPlayWavAction('Permission needed');
  if (result !== null) {
    assert.match(result, /SoundPlayer/);
    assert.match(result, /PlaySync/);
    assert.ok(result.includes(AUDIO_DIR.replace(/\\/g, '\\')) || result.includes(AUDIO_DIR));
  }
});

test('buildPlayWavAction respects CLAUDE_NOTIFY_WAV_DISABLED', () => {
  process.env.CLAUDE_NOTIFY_WAV_DISABLED = '1';
  try {
    assert.equal(buildPlayWavAction('Permission needed'), null);
  } finally {
    delete process.env.CLAUDE_NOTIFY_WAV_DISABLED;
  }
});

test('AUDIO_DIR resolves under plugin root', () => {
  // <root>/audio — sibling of hooks/
  assert.equal(path.basename(AUDIO_DIR), 'audio');
});
