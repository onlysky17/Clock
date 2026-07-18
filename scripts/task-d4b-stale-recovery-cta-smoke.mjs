import { readFileSync } from 'node:fs';
import { strict as assert } from 'node:assert';

const WEB_PATH = 'web/clock-app/hl24a-canvas-e5.html';
const html = readFileSync(WEB_PATH, 'utf8');

const expectedWarning = 'Thiết bị đang giữ giờ cũ. Hãy đồng bộ giờ hiện tại để tiếp tục chạy đồng hồ.';
const expectedCta = 'Đồng bộ giờ hiện tại';

function mustContain(label, needle) {
  assert.ok(html.includes(needle), `${label} missing`);
}

function mustMatch(label, pattern) {
  assert.ok(pattern.test(html), `${label} missing`);
}

mustContain('canonical implementation', '<title>TASK D2D - Device Clock Renderer</title>');
mustContain('exact stale warning text', expectedWarning);
mustContain('exact stale CTA text', expectedCta);

mustMatch('stale mask constant', /D2_STALE_PRESENT_FLAG\s*=\s*0x80/);
mustMatch('stale mask check', /status\.flags\s*&\s*D2_STALE_PRESENT_FLAG/);
mustMatch('stale disables render', /\$\('d2RenderClock'\)\.disabled\s*=\s*!connected\|\|locked\|\|d2StalePresent/);
mustMatch('CTA button exists', /id="d2StaleRecover"[\s\S]*?>Đồng bộ giờ hiện tại<\/button>/);

mustMatch('recovery-pending state exists', /let d2StaleRecoveryPending=false/);
mustMatch('disconnect clears recovery-pending state', /function resetD2UiDisconnected\(\)[\s\S]*d2StaleRecoveryPending=false/);
mustMatch(
  'pending guard keeps stale UI during non-confirm status',
  /if\(d2StaleRecoveryPending && !recoveryConfirm\)\{[\s\S]*d2StalePresent=true;[\s\S]*\}else\{[\s\S]*d2StalePresent=hasD2StalePresent\(status\)/
);
mustMatch(
  'handleD2Notify routes SET_TIME/status notify through guarded renderer',
  /function handleD2Notify\(bytes\)[\s\S]*if\(bytes\[1\]===0x81\)\{[\s\S]*const status=parseD2Status\(bytes\);[\s\S]*renderD2Status\(status\);/
);
mustMatch(
  'CTA marks recovery pending before SET_TIME',
  /async function d2RecoverStaleTime\(\)[\s\S]*d2StalePresent=true;[\s\S]*d2StaleRecoveryPending=true;[\s\S]*renderD2StaleRecovery\(\);[\s\S]*await d2SetCurrentTime\(\)/
);
mustMatch(
  'SET_TIME notify is not enough to complete recovery',
  /await d2SetCurrentTime\(\);[\s\S]*const status=await d2GetTimeStatus\(\{recoveryConfirm:true\}\)/
);
mustMatch(
  'follow-up GET_STATUS passes explicit recovery confirmation',
  /async function d2GetTimeStatus\(options=\{\}\)[\s\S]*renderD2Status\(status,options\)/
);
mustMatch(
  'only follow-up flags clear can clear stale UI',
  /const status=await d2GetTimeStatus\(\{recoveryConfirm:true\}\);[\s\S]*if\(hasD2StalePresent\(status\)\)\{[\s\S]*throw Error\('[^']+'\);[\s\S]*d2StaleRecoveryPending=false;[\s\S]*d2StalePresent=false;[\s\S]*renderD2StaleRecovery\(\);[\s\S]*setD2Status\('STALE CLEARED','ok'\)/
);
mustMatch(
  'SET_TIME or status error keeps stale UI',
  /catch\(error\)\{[\s\S]*d2StaleRecoveryPending=false;[\s\S]*d2StalePresent=true;[\s\S]*renderD2StaleRecovery\(\);[\s\S]*throw error;[\s\S]*\}/
);
mustMatch(
  'runD2Flow reports recovery errors clearly',
  /catch\(error\)\{[\s\S]*setD2Status\(`ERROR: \$\{error\.message\}`,'bad'\)[\s\S]*alert\(error\.message\);[\s\S]*\}finally\{/
);

const recoverCalls = [...html.matchAll(/d2RecoverStaleTime/g)].length;
assert.equal(recoverCalls, 2, 'recovery must only be function declaration plus explicit CTA handler');

const setPacketBuilders = [...html.matchAll(/function buildD2SetTimePacket/g)].length;
assert.equal(setPacketBuilders, 1, 'must not duplicate D2 SET_TIME protocol builder');

console.log('TASK D4B stale recovery CTA smoke PASS');
