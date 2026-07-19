import { readFileSync } from 'node:fs';
import { strict as assert } from 'node:assert';

const WEB_PATH = 'web/clock-app/hl24a-canvas-e5.html';
const html = readFileSync(WEB_PATH, 'utf8');

function mustContain(label, needle) {
  assert.ok(html.includes(needle), `${label} missing`);
}

function mustMatch(label, pattern) {
  assert.ok(pattern.test(html), `${label} missing`);
}

mustContain('canonical implementation', '<title>TASK D2D - Device Clock Renderer</title>');
mustContain('daily calendar preset button', 'Mặt lịch hằng ngày');
mustMatch('logical width', /const WIDTH=250/);
mustMatch('logical height', /const HEIGHT=122/);
mustMatch('controller RAM width', /const RAM_WIDTH=122/);
mustMatch('controller RAM height', /const RAM_HEIGHT=250/);
mustMatch('stride', /const STRIDE=16/);
mustMatch('payload total', /const TOTAL=4000/);
mustMatch('canvas element geometry', /<canvas id="canvas" width="250" height="122"><\/canvas>/);
mustMatch('HH:mm render exists', /const time=`\$\{pad2\(now\.getHours\(\)\)\}:\$\{pad2\(now\.getMinutes\(\)\)\}`/);
mustMatch('solar date render exists', /const solar=`\$\{weekdaysLong\[now\.getDay\(\)\]\} \$\{pad2\(now\.getDate\(\)\)\}\/\$\{pad2\(now\.getMonth\(\)\+1\)\}\/\$\{now\.getFullYear\(\)\}`/);
mustMatch('lunar text render exists', /const lunarText=`Âm \$\{pad2\(lunar\.day\)\}\/\$\{pad2\(lunar\.month\)\}/);
mustMatch('7-column month grid', /weekdaysShort\.forEach[\s\S]*for\(let day=1;day<=lastDay;day\+\+\)[\s\S]*const col=pos%7/);
mustMatch('current-day invert highlight', /if\(day===now\.getDate\(\)\)\{[\s\S]*ctx\.fillRect[\s\S]*ctx\.fillStyle='#fff'/);
mustMatch('daily preset handler', /\$\('dailyCalendar'\)\.onclick=\(\)=>drawDailyCalendar\(\)/);
mustMatch('one-tap uses daily calendar', /async function syncClockToPanel\(\)[\s\S]*drawDailyCalendar\(\);[\s\S]*await sendFramebuffer\(\)/);

mustMatch('E5 start packet unchanged', /function startPacket\(id\)\{[\s\S]*0xE5,0x00,id[\s\S]*TOTAL&0xFF,TOTAL>>8/);
mustMatch('E5 chunk packet unchanged', /function chunkPacket\(id,seq,data\)\{[\s\S]*0xE5,0x01,id/);
mustMatch('E5 commit packet unchanged', /function commitPacket\(id,chunks,bytes,crc\)\{[\s\S]*0xE5,0x02,id/);
mustMatch('E6 refresh flow still present', /async function refreshPanel\(\) \{[\s\S]*Uint8Array\.of\(0xE6, 0x00, transferId\)/);

const lunarSource = html.slice(html.indexOf('function jdFromDate'), html.indexOf('function pad2'));
assert.ok(lunarSource.includes('function solarToLunar'), 'solarToLunar source missing');
const getLunar = new Function(`${lunarSource}; return solarToLunar(new Date(2026,6,18));`);
const fixture = getLunar();
assert.equal(fixture.day, 5, 'lunar fixture day must be 05');
assert.equal(fixture.month, 6, 'lunar fixture month must be 06');

console.log('TASK D5A flagship daily layout smoke PASS');
