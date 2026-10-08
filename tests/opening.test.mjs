import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const script = readFileSync(new URL('../dist/invitation.js', import.meta.url), 'utf8');
const opening = script.slice(script.indexOf("const video = $('opening')"), script.indexOf('const observer ='));
function setup({ play = () => Promise.resolve(), reduced = false, error = null } = {}) {
  const elements = Object.fromEntries(['opening', 'open', 'couple', 'scroll'].map(id => [id, {
    classList: { add(name) { this[name] = true; }, remove(name) { delete this[name]; } },
    handlers: {}, hidden: true, currentTime: 0, readyState: 0, error: null,
    addEventListener(name, handler) { this.handlers[name] = handler; },
    setAttribute(name, value) { this[name] = value; },
    play, pause() { this.paused = true; },
  }]));
  elements.opening.error = error;
  let timer;
  runInNewContext(opening, {
    $: id => elements[id], matchMedia: () => ({ matches: reduced }),
    setTimeout: callback => { timer = callback; return 1; }, clearTimeout: () => { timer = null; },
  });
  return { ...elements, timeout: () => timer?.() };
}
function assertFallback(page) {
  assert.equal(page.couple['aria-hidden'], 'false');
  assert.equal(page.scroll.hidden, false);
  assert.equal(page.opening.paused, true);
  assert.ok(!page.opening.classList['has-frame']);
}
test('blocked playback opens the invitation over its still background', async () => {
  const page = setup({ play: () => Promise.reject(new Error('NotAllowedError')) });
  page.open.handlers.click();
  await Promise.resolve();
  assertFallback(page);
});
test('a play promise that never settles cannot trap the opening', () => {
  const page = setup({ play: () => new Promise(() => {}) });
  page.open.handlers.click();
  page.timeout();
  assertFallback(page);
  page.opening.currentTime = 1;
  page.opening.handlers.timeupdate();
  assert.ok(!page.opening.classList['has-frame'], 'late playback must not replace the fallback');
});
test('decode failure removes a previously visible video', () => {
  const page = setup();
  page.open.handlers.click();
  page.opening.currentTime = 1;
  page.opening.handlers.timeupdate();
  page.opening.handlers.error();
  assertFallback(page);
});
test('reduced motion and an early media error both use the still invitation', () => {
  for (const options of [{ reduced: true }, { error: { code: 4 } }]) {
    const page = setup(options);
    page.open.handlers.click();
    assertFallback(page);
  }
});
test('successful playback reveals the video and then the names', () => {
  const page = setup();
  page.open.handlers.click();
  assert.ok(!page.opening.classList['has-frame']);
  page.opening.currentTime = 1;
  page.opening.readyState = 4;
  page.opening.handlers.timeupdate();
  assert.equal(page.opening.classList['has-frame'], true);
  page.opening.handlers.ended();
  assert.equal(page.couple['aria-hidden'], 'false');
  assert.equal(page.scroll.hidden, false);
});
