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
mustContain('canonical URL unchanged in source scope', 'TASK D2D');

mustMatch('product mode builder exists', /function setupProductMode\(\)\{/);
mustContain('product title', 'Đồng hồ lịch hằng ngày');
mustContain('connect label', 'Kết nối');
mustContain('disconnect label', 'Ngắt kết nối');
mustContain('simple status disconnected', 'Chưa kết nối');
mustContain('simple status running', 'Đang chạy');
mustContain('simple status needs time sync', 'Cần đồng bộ giờ');
mustContain('simple status error', 'Có lỗi');
mustContain('sync time label', 'Đồng bộ giờ');
mustContain('send to screen label', 'Gửi lên màn');
mustContain('advanced label', 'Kỹ thuật / Nâng cao');
mustMatch('advanced details closed by default', /const advanced=document\.createElement\('details'\);[\s\S]*advanced\.id='advancedPanel';/);
assert.ok(!/<details[^>]*id="advancedPanel"[^>]*open/.test(html), 'advanced panel must not be open by default');

mustMatch('connect id preserved', /id="connect"|refs=\{[\s\S]*connect:\$\(\'connect\'\)/);
mustMatch('disconnect id preserved', /id="disconnect"|disconnect:\$\(\'disconnect\'\)/);
mustMatch('syncClock id preserved', /id="syncClock"|syncClock:\$\(\'syncClock\'\)/);
mustMatch('dailyCalendar id preserved', /id="dailyCalendar"|dailyCalendar:\$\(\'dailyCalendar\'\)/);
mustMatch('send id preserved', /id="send"/);
mustMatch('refresh id preserved', /id="refresh"/);
mustMatch('d2SetTime id preserved', /id="d2SetTime"|d2SetTime:\$\(\'d2SetTime\'\)/);
mustMatch('d2GetStatus id preserved', /id="d2GetStatus"/);
mustMatch('d2RenderClock id preserved', /id="d2RenderClock"/);
mustMatch('log id preserved', /id="log"/);

mustMatch('technical sections moved into advanced', /advanced\.querySelector\('\.advancedBody'\)\.append\(section\)/);
mustMatch('service UUID unchanged', /const SERVICE='18424398-7cbc-11e9-8f9e-2a86e4085a59'/);
mustMatch('write UUID unchanged', /const WRITE='2d86686a-53dc-25b3-0c4a-f0e10c8dee20'/);
mustMatch('notify UUID unchanged', /const NOTIFY='15005991-b131-3396-014c-664c9867b917'/);
mustMatch('E5 start packet unchanged', /function startPacket\(id\)\{[\s\S]*0xE5,0x00,id[\s\S]*TOTAL&0xFF,TOTAL>>8/);
mustMatch('E5 chunk packet unchanged', /function chunkPacket\(id,seq,data\)\{[\s\S]*0xE5,0x01,id/);
mustMatch('E5 commit packet unchanged', /function commitPacket\(id,chunks,bytes,crc\)\{[\s\S]*0xE5,0x02,id/);
mustMatch('E6 request unchanged', /Uint8Array\.of\(0xE6, 0x00, transferId\)/);
mustMatch('D2 set still user initiated', /\$\('d2SetTime'\)\.onclick=\(\)=>runD2Flow\(d2SetCurrentTime\)/);
mustMatch('send still user initiated', /\$\('syncClock'\)\.onclick=\(\)=>safe\(syncClockToPanel\)/);
mustMatch('setup before event binding', /setupProductMode\(\);\s*\n\s*\$\(\'clearWhite\'\)\.onclick=clearWhite/);
mustMatch('flagship preset still exists', /M(?:ặt|áº·t) l(?:ịch|á»‹ch) h(?:ằng|áº±ng) ng(?:ày|Ã y)|Mặt lịch hằng ngày/);

console.log('TASK D6B web product mode smoke PASS');
