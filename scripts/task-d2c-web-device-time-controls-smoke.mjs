import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const htmlPath = join(root, 'web', 'clock-app', 'hl24a-canvas-e5.html');
const html = readFileSync(htmlPath, 'utf8');

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function functionBody(name) {
  const start = html.indexOf(`function ${name}(`);
  assert(start >= 0, `Missing function ${name}`);
  const open = html.indexOf('{', start);
  let depth = 0;
  for (let i = open; i < html.length; i += 1) {
    if (html[i] === '{') depth += 1;
    if (html[i] === '}') depth -= 1;
    if (depth === 0) return html.slice(open + 1, i);
  }
  throw new Error(`Unclosed function ${name}`);
}

assert(html.includes('<title>TASK D2C - Device Time Sync Controls</title>'), 'Document title must be D2C');
assert(html.includes('TASK D2C • DEVICE TIME SYNC • HINK213 BW'), 'Badge must be D2C');
assert(html.includes('250×122 Clock Preview → D2 Device Time + E5/E6 Panel Sync'), 'Heading must be D2C');
assert(!html.includes('<title>TASK D1C'), 'Title must not remain D1C');
assert(!html.includes('TASK D1C •'), 'Badge must not remain D1C');
assert(html.includes('DEVICE TIME SYNC — D2'), 'Missing D2 section');
assert(html.includes('Gửi giờ xuống thiết bị'), 'Missing D2 SET button');
assert(html.includes('Đọc trạng thái giờ'), 'Missing D2 GET button');
assert(html.includes('aria-live="polite"'), 'D2 status should be screen-reader visible');

const setPacket = functionBody('buildD2SetTimePacket');
assert(setPacket.includes('const packet=new Uint8Array(9);'), 'D2 SET must be exactly 9 bytes');
assert(setPacket.includes('packet[0]=0xD2;'), 'D2 SET opcode missing');
assert(setPacket.includes('packet[1]=0x00;'), 'D2 SET subcommand missing');
assert(setPacket.includes('Math.floor(date.getTime()/1000)'), 'D2 SET must use current epoch seconds');
assert(setPacket.includes('putU32LE(packet,2'), 'D2 SET epoch must be uint32 LE at byte 2');
assert(setPacket.includes('putI16LE(packet,6,-date.getTimezoneOffset())'), 'D2 SET timezone must be -getTimezoneOffset int16 LE');
assert(setPacket.includes('packet[8]=0x02;'), 'D2 SET flags must request immediate notify');

const getPacket = functionBody('buildD2GetStatusPacket');
assert(getPacket.includes('Uint8Array.of(0xD2,0x01)'), 'D2 GET must be exactly D2 01');

const parseStatus = functionBody('parseD2Status');
assert(parseStatus.includes('bytes.length!==15'), 'D2 status must require exact 15 bytes');
assert(parseStatus.includes('bytes[0]!==0xD2'), 'D2 status opcode guard missing');
assert(parseStatus.includes('bytes[1]!==0x81'), 'D2 status response guard missing');
assert(parseStatus.includes('u32(bytes[4],bytes[5],bytes[6],bytes[7])'), 'D2 epoch parse must be uint32 LE');
assert(parseStatus.includes('i16(bytes[8],bytes[9])'), 'D2 timezone parse must be int16 LE');
assert(parseStatus.includes('u32(bytes[11],bytes[12],bytes[13],bytes[14])'), 'D2 uptime parse must be uint32 LE');

const renderLocal = functionBody('renderDeviceLocalTime');
assert(renderLocal.includes('(epoch+(timezone*60))*1000'), 'D2 local render must apply returned timezone exactly once');
assert(renderLocal.includes('getUTCFullYear()'), 'D2 local render must avoid browser timezone double-add');

assert(html.includes('0x00:\'OK\''), 'D2 result OK label missing');
assert(html.includes('0x01:\'INVALID_LENGTH\''), 'D2 INVALID_LENGTH label missing');
assert(html.includes('0x02:\'INVALID_FLAGS\''), 'D2 INVALID_FLAGS label missing');
assert(html.includes('0x03:\'INVALID_TIME_RANGE\''), 'D2 INVALID_TIME_RANGE label missing');
assert(html.includes('0x04:\'NOT_INITIALIZED\''), 'D2 NOT_INITIALIZED label missing');
assert(html.includes('0x05:\'INTERNAL_ERROR\''), 'D2 INTERNAL_ERROR label missing');
assert(html.includes('0x00:\'UNSET\''), 'D2 UNSET label missing');
assert(html.includes('0x01:\'SYNCED\''), 'D2 SYNCED label missing');
assert(html.includes('0x02:\'RUNNING\''), 'D2 RUNNING label missing');
assert(html.includes('0x03:\'STALE\''), 'D2 STALE label missing');

const notify = functionBody('onNotify');
assert(notify.indexOf('handleD2Notify(bytes);') >= 0, 'D2 notify fan-out missing');
assert(notify.indexOf('handleD2Notify(bytes);') < notify.indexOf('if(pending&&pending.predicate(bytes))'), 'D2 notify must fan out before pending ACK handling');

const handleNotify = functionBody('handleD2Notify');
assert(handleNotify.includes('if(bytes[0]!==0xD2)return;'), 'D2 notify must ignore non-D2 packets');
assert(handleNotify.includes('log(error.message,\'D2\');'), 'Unknown D2 response must log without crashing');

const d2Set = functionBody('d2SetCurrentTime');
assert(d2Set.includes('buildD2SetTimePacket(new Date())'), 'D2 SET must use current browser time');
assert(d2Set.includes('a=>a[0]===0xD2&&a[1]===0x81'), 'D2 SET must wait for D2 status notify');
assert(!d2Set.includes('sendFramebuffer'), 'D2 SET must not send E5');
assert(!d2Set.includes('refreshPanel'), 'D2 SET must not send E6');
assert(!d2Set.includes('drawCurrentClock'), 'D2 SET must not redraw preview');

const d2Get = functionBody('d2GetTimeStatus');
assert(d2Get.includes('buildD2GetStatusPacket()'), 'D2 GET must send exact GET packet');
assert(d2Get.includes('a=>a[0]===0xD2&&a[1]===0x81'), 'D2 GET must wait for D2 status notify');
assert(!d2Get.includes('sendFramebuffer'), 'D2 GET must not send E5');
assert(!d2Get.includes('refreshPanel'), 'D2 GET must not send E6');

const d2Run = functionBody('runD2Flow');
assert(d2Run.includes('if(d2Running||busy||e6Running||oneTapRunning)'), 'D2 flow must guard re-entry/busy');
assert(d2Run.includes('if(!server?.connected)'), 'D2 flow must require BLE connected');
assert(d2Run.includes('d2Running=true;'), 'D2 flow must set running guard');
assert(d2Run.includes('d2Running=false;'), 'D2 flow must clear running guard');

const controls = functionBody('controls');
assert(controls.includes('busy||e6Running||oneTapRunning||d2Running'), 'Controls must include D2 running guard');
assert(controls.includes('$(\'d2SetTime\').disabled=!connected||locked;'), 'D2 SET button guard missing');
assert(controls.includes('$(\'d2GetStatus\').disabled=!connected||locked;'), 'D2 GET button guard missing');

assert(html.includes("resetD2UiDisconnected();"), 'Disconnect must reset D2 UI');
assert(html.includes("$('d2SetTime').onclick=()=>runD2Flow(d2SetCurrentTime);"), 'D2 SET click handler missing');
assert(html.includes("$('d2GetStatus').onclick=()=>runD2Flow(d2GetTimeStatus);"), 'D2 GET click handler missing');
assert(html.includes('TASK D2C ready.'), 'Boot log should be D2C');

const script = html.match(/<script>([\s\S]*)<\/script>/);
assert(script, 'Missing inline script');
new Function(script[1]);

for (const path of ['test.html', 'firmware', 'docs']) {
  const diff = execFileSync('git', ['diff', '--name-only', '--', path], {
    cwd: root,
    encoding: 'utf8'
  }).trim();
  assert(diff === '', `${path} must not be modified`);
}

console.log('TASK D2C web device time controls smoke PASS');
