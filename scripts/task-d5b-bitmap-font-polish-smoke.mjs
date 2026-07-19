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
mustMatch('bitmap glyph table exists', /const PIXEL_FONT_5X7=\{/);
mustMatch('block digit table exists', /const BLOCK_DIGITS_3X5=\{/);
mustMatch('Vietnamese Á glyph exists', /'Á':\[/);
mustMatch('Vietnamese Â glyph exists', /'Â':\[/);
mustMatch('unknown glyph fallback exists', /'\?':\[/);
mustMatch('pixel glyph renderer exists', /function drawPixelGlyph\(pattern,x,y,scale=1,color='#000'\)/);
mustMatch('bitmap text renderer exists', /function drawBitmapText\(text,x,y,\{scale=1,color='#000',spacing=1,align='left'\}=\{\}\)/);
mustMatch('bitmap text falls back to question glyph', /PIXEL_FONT_5X7\[char\]\|\|PIXEL_FONT_5X7\['\?'\]/);
mustMatch('HH:mm uses block digits', /drawBlockTime\(time,72,35,6\)/);
mustMatch('image smoothing disabled', /ctx\.imageSmoothingEnabled=false/);

const flagshipStart = html.indexOf('function drawDailyCalendar(sourceDate=new Date()){');
const flagshipEnd = html.indexOf('function drawCurrentClock(){', flagshipStart);
assert.ok(flagshipStart >= 0 && flagshipEnd > flagshipStart, 'flagship renderer boundaries missing');
const flagship = html.slice(flagshipStart, flagshipEnd);

assert.ok(!/ctx\.font|fillText\(/.test(flagship), 'flagship layout must not use canvas text fonts');
assert.ok(!/Arial|system-ui/.test(flagship), 'flagship layout must not use Arial/system-ui');
mustMatch('solar text uses compact bitmap', /const solarBox=drawBitmapText\(solar,5,10,\{scale:1\}\)/);
mustMatch('ÂM text uses bitmap', /const lunarText=`ÂM \$\{pad2\(lunar\.day\)\}\/\$\{pad2\(lunar\.month\)\}/);
mustMatch('THÁNG title uses bitmap', /drawBitmapText\(`THÁNG \$\{now\.getMonth\(\)\+1\}\/\$\{now\.getFullYear\(\)\}`/);
mustMatch('layout bounds debug exists', /window\.__D5B_DAILY_LAYOUT_DEBUG=\{/);
mustMatch('divider guard constants present', /dividerX:leftW[\s\S]*leftPaneRight:leftW-1/);
mustMatch('calendar 7 columns', /weekdaysShort\.forEach[\s\S]*const col=pos%7/);
mustMatch('current day invert has padding', /if\(day===now\.getDate\(\)\)\{[\s\S]*ctx\.fillRect\(x,y-1,cellW,cellH\)[\s\S]*color:'#fff'/);

mustMatch('logical width', /const WIDTH=250/);
mustMatch('logical height', /const HEIGHT=122/);
mustMatch('controller RAM width', /const RAM_WIDTH=122/);
mustMatch('controller RAM height', /const RAM_HEIGHT=250/);
mustMatch('stride', /const STRIDE=16/);
mustMatch('payload total', /const TOTAL=4000/);
mustMatch('canvas element geometry', /<canvas id="canvas" width="250" height="122"><\/canvas>/);

mustMatch('E5 start packet unchanged', /function startPacket\(id\)\{[\s\S]*0xE5,0x00,id[\s\S]*TOTAL&0xFF,TOTAL>>8/);
mustMatch('E5 chunk packet unchanged', /function chunkPacket\(id,seq,data\)\{[\s\S]*0xE5,0x01,id/);
mustMatch('E5 commit packet unchanged', /function commitPacket\(id,chunks,bytes,crc\)\{[\s\S]*0xE5,0x02,id/);
mustMatch('E6 refresh flow still present', /async function refreshPanel\(\) \{[\s\S]*Uint8Array\.of\(0xE6, 0x00, transferId\)/);

console.log('TASK D5B bitmap font polish smoke PASS');
