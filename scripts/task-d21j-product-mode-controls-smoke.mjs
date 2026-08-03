import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const root = process.cwd();
const webPath = 'web/clock-app/hl24a-canvas-e5.html';
const smokePath = 'scripts/task-d21j-product-mode-controls-smoke.mjs';
const html = readFileSync(`${root}/${webPath}`, 'utf8');
const testHtml = readFileSync(`${root}/test.html`, 'utf8');
const setupStart = html.indexOf('function setupProductMode(){');
const setupEnd = html.indexOf('function markLayoutHealth(){');
const setup = html.slice(setupStart, setupEnd);

assert.ok(setupStart >= 0 && setupEnd > setupStart, 'Product Mode setup is missing');
assert.ok(
  testHtml.includes('./web/clock-app/hl24a-canvas-e5.html'),
  'canonical test.html target changed',
);

const visibleAppend =
  'main.append(header,statusCard,identityCard,presetCard,advanced,privacyLink);';
assert.ok(setup.includes(visibleAppend), 'device identity card is not visible in Product Mode');
assert.ok(
  setup.indexOf(visibleAppend) < setup.indexOf("$('identityActionRow').append(refs.d2GetIdentity);"),
  'identity controls are attached before their visible container exists',
);
assert.ok(
  setup.includes("$('productConnectRow').append(refs.connect,refs.disconnect);"),
  'connect controls are not attached to Product Mode',
);
assert.ok(
  setup.includes("$('identityActionRow').append(refs.d2GetIdentity);"),
  'device identity action is missing',
);
assert.ok(
  setup.includes("$('productPresetRow').append(refs.dailyCalendar,refs.updateClock,dailyBriefing,profileApply);"),
  'clock face controls are not attached to Product Mode',
);
assert.ok(
  setup.includes('advancedBody.append(advancedDailyProgress,preferencePanel,previewCard);'),
  'advanced controls were not preserved',
);
assert.ok(
  !setup.includes('advancedBody.append(advancedDailyProgress,preferencePanel,identityCard,previewCard);'),
  'device identity card must not be hidden inside Advanced',
);
assert.ok(!/<details[^>]*id=["']advancedPanel["'][^>]*open/.test(html), 'Advanced must remain closed');

assert.ok(html.includes("$('connect').onclick=()=>safe(connect);"), 'connect behavior is missing');
assert.ok(html.includes("return Uint8Array.of(0xD2,0x03);"), 'D2 identity command changed');
assert.ok(html.includes("return Uint8Array.of(0xD2,0x04,profile);"), 'D2 profile command changed');

const dirty = execFileSync('git', ['status', '--short', '--untracked-files=all'], {
  cwd: root,
  encoding: 'utf8',
})
  .trimEnd()
  .split(/\r?\n/)
  .filter(Boolean)
  .map((line) => line.slice(3).replaceAll('\\', '/'));
assert.deepEqual(
  dirty.sort(),
  [webPath, smokePath].sort(),
  `unexpected dirty scope: ${dirty.join(', ')}`,
);

console.log('TASK D21J Product Mode controls smoke PASS');
