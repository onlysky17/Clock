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
mustMatch('fixed bitmap cell width', /const BITMAP_FONT_CELL_WIDTH=5/);
mustMatch('fixed bitmap cell height', /const BITMAP_FONT_CELL_HEIGHT=9/);
mustMatch('fixed bitmap advance', /const BITMAP_FONT_ADVANCE=6/);
mustMatch('fixed bitmap baseline', /const BITMAP_FONT_BASELINE=8/);
mustMatch('bitmap glyph table exists', /const PIXEL_FONT_5X9=\{/);
mustMatch('legacy alias remains for D5B checks', /const PIXEL_FONT_5X7=PIXEL_FONT_5X9/);
mustMatch('block digit table exists', /const BLOCK_DIGITS_3X5=\{/);
mustMatch('Vietnamese Á glyph exists as escape', /'\\u00c1':\[/);
mustMatch('Vietnamese Â glyph exists as escape', /'\\u00c2':\[/);
mustMatch('unknown glyph fallback exists', /'\?':\[/);
mustMatch('pixel glyph renderer exists', /function drawPixelGlyph\(pattern,x,y,scale=1,color='#000'\)/);
mustMatch('baseline text renderer exists', /function drawBitmapText\(text,x,baselineY,\{scale=1,color='#000',align='left'\}=\{\}\)/);
mustMatch('baseline top calculation exists', /const top=Math\.round\(baselineY-BITMAP_FONT_BASELINE\*scale\)/);
mustMatch('same advance used for all glyphs', /cursor\+=advance/);
mustMatch('bbox returns baseline metrics', /return \{x:startX,y:top,width:total,height:cellHeight,baselineY,advance,cellWidth,cellHeight\}/);
mustMatch('HH:mm uses block digits', /drawBlockTime\(time,72,35,6\)/);
mustMatch('image smoothing disabled', /ctx\.imageSmoothingEnabled=false/);

const flagshipStart = html.indexOf('function drawDailyCalendar(sourceDate=new Date()){');
const flagshipEnd = html.indexOf('function drawCurrentClock(){', flagshipStart);
assert.ok(flagshipStart >= 0 && flagshipEnd > flagshipStart, 'flagship renderer boundaries missing');
const flagship = html.slice(flagshipStart, flagshipEnd);

assert.ok(!/ctx\.font|fillText\(/.test(flagship), 'flagship layout must not use canvas text fonts');
assert.ok(!/Arial|system-ui/.test(flagship), 'flagship layout must not use Arial/system-ui');
mustMatch('solar text uses one baseline', /const solarBox=drawBitmapText\(solar,5,18,\{scale:1\}\)/);
mustMatch('ÂM text uses one baseline', /const lunarText=`\\u00c2M \$\{pad2\(lunar\.day\)\}\/\$\{pad2\(lunar\.month\)\}/);
mustMatch('ÂM text baseline', /const lunarBox=drawBitmapText\(lunarText,6,110,\{scale:2\}\)/);
mustMatch('THÁNG title uses one baseline', /drawBitmapText\(`TH\\u00c1NG \$\{now\.getMonth\(\)\+1\}\/\$\{now\.getFullYear\(\)\}`,rightX\+rightW\/2,17,\{scale:1,align:'center'\}\)/);
mustMatch('weekday row uses one baseline', /const headerBaseline=32[\s\S]*weekdayBoxes=weekdaysShort\.map/);
mustMatch('weekday rule below row', /const weekdayRuleY=35/);
mustMatch('layout bounds debug exists', /window\.__D5B_DAILY_LAYOUT_DEBUG=\{/);
mustMatch('divider guard constants present', /dividerX:leftW[\s\S]*leftPaneRight:leftW-1/);
mustMatch('calendar 7 columns', /weekdaysShort\.map[\s\S]*const col=pos%7/);
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
