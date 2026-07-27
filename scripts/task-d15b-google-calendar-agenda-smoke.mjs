import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync, spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const ROOT = 'D:/EINK/Clock';
const WEB = 'web/clock-app/hl24a-canvas-e5.html';
const DOC = 'docs/web/TASK_D15B_GOOGLE_CALENDAR_AGENDA.md';
const POLICY = 'docs/web/TASK_D15A_PHONE_CALENDAR_AGENDA_POLICY.md';
const SMOKE = 'scripts/task-d15b-google-calendar-agenda-smoke.mjs';
const PROOF = `${ROOT}/_incoming/D15B_GOOGLE_CALENDAR_PROOF`;
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const web = fs.readFileSync(`${ROOT}/${WEB}`, 'utf8');
const doc = fs.readFileSync(`${ROOT}/${DOC}`, 'utf8');
const policy = fs.readFileSync(`${ROOT}/${POLICY}`, 'utf8');
const script = web.match(/<script>([\s\S]*?)<\/script>/)?.[1] ?? '';

assert.ok(script, 'web script missing');
assert.doesNotThrow(() => new Function(script), 'web JavaScript must parse');
assert.match(web, /D15B-GOOGLE-CALENDAR-20260727/, 'D15B web marker missing');
assert.match(
  web,
  /64961652220-4b2s7mnvqfut2fsu213gokbi28qs74t6\.apps\.googleusercontent\.com/,
  'production Google OAuth Client ID missing',
);
assert.match(web, /accounts\.google\.com\/gsi\/client/, 'Google Identity Services missing');
assert.match(script, /https:\/\/www\.googleapis\.com\/auth\/calendar\.readonly/);
assert.match(script, /calendar\/v3\/calendars\/primary\/events/);
assert.match(script, /timeMin:start\.toISOString\(\)/);
assert.match(script, /timeMax:end\.toISOString\(\)/);
assert.match(script, /singleEvents:'true'/);
assert.match(script, /orderBy:'startTime'/);
assert.match(script, /selected\.length===2/, 'two-row bound missing');
assert.match(script, /event\?\.status!=='cancelled'/);
assert.match(script, /event\?\.start\?\.dateTime/, 'all-day events must be excluded');
assert.match(script, /normalize\('NFD'\)/);
assert.match(script, /replace\(\/\[\^A-Z0-9\]\/g,''\)/);
assert.match(script, /slice\(0,3\)/);
assert.match(script, /window\.EINK_GOOGLE_CALENDAR_TEST/);
assert.doesNotMatch(script, /localStorage|sessionStorage|indexedDB/);
assert.match(script, /new Uint8Array\(20\)[\s\S]*packet\[1\]=0x08/);
assert.match(script, /Uint8Array\.of\(0xD2,0x09\)/);
assert.match(web, /https:\/\/onlysky17\.github\.io\/Clock\/test\.html|TASK D15B/);
assert.match(doc, /Google Calendar API/);
assert.match(doc, /page-session RAM/);
assert.match(doc, /không đổi BLE protocol/i);
assert.match(policy, /D15B therefore promotes explicit read-only[\s\S]*Google Calendar OAuth/);

const changed = execFileSync(
  'git',
  ['status', '--porcelain', '--untracked-files=all'],
  { cwd: ROOT, encoding: 'utf8' },
).trimEnd().split(/\r?\n/).filter(Boolean)
  .map(line => line.slice(3).replace(/\\/g, '/'));
const allowed = new Set([WEB, DOC, POLICY, SMOKE]);
assert.ok(changed.every(file => allowed.has(file)), `out-of-scope file changed: ${changed.join(', ')}`);
assert.ok(!changed.some(file => file.startsWith('firmware/')), 'firmware changed');
assert.ok(!changed.includes('test.html'), 'test.html changed');

fs.mkdirSync(PROOF, { recursive: true });
assert.ok(fs.existsSync(CHROME), 'Chrome not found');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const pageUrl = pathToFileURL(`${ROOT}/${WEB}`).href;

async function capture(name, width, height) {
  const port = 10200 + Math.floor(Math.random() * 30);
  const profile = `${PROOF}/chrome-${name}-${Date.now()}`;
  fs.mkdirSync(profile, { recursive: true });
  const chrome = spawn(CHROME, [
    '--headless=new',
    '--disable-gpu',
    '--no-sandbox',
    '--hide-scrollbars',
    '--disable-background-networking',
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${profile}`,
    'about:blank',
  ], { stdio: 'ignore' });

  try {
    let targets;
    for (let attempt = 0; attempt < 50; attempt++) {
      try {
        targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
        if (targets.some(target => target.type === 'page')) break;
      } catch {}
      await delay(100);
    }
    const target = targets?.find(item => item.type === 'page');
    assert.ok(target?.webSocketDebuggerUrl, `${name} target missing`);
    const socket = new WebSocket(target.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
      socket.onopen = resolve;
      socket.onerror = reject;
    });
    let id = 0;
    const pendingCalls = new Map();
    socket.onmessage = event => {
      const message = JSON.parse(event.data);
      if (!message.id || !pendingCalls.has(message.id)) return;
      const call = pendingCalls.get(message.id);
      pendingCalls.delete(message.id);
      message.error ? call.reject(new Error(message.error.message)) : call.resolve(message.result);
    };
    const send = (method, params = {}) => new Promise((resolve, reject) => {
      const requestId = ++id;
      pendingCalls.set(requestId, { resolve, reject });
      socket.send(JSON.stringify({ id: requestId, method, params }));
    });

    await send('Page.enable');
    await send('Runtime.enable');
    await send('Page.addScriptToEvaluateOnNewDocument', {
      source: `
        window.EINK_GOOGLE_CALENDAR_CLIENT_ID='fixture.apps.googleusercontent.com';
        window.google={accounts:{oauth2:{
          initTokenClient(options){
            return{
              callback:options.callback,
              requestAccessToken(){this.callback({access_token:'fixture-token'})}
            };
          },
          revoke(token,callback){callback()}
        }}};
        const nativeFetch=window.fetch.bind(window);
        window.fetch=(url,options)=>{
          if(String(url).includes('/calendar/v3/calendars/primary/events')){
            return Promise.resolve(new Response(JSON.stringify({items:[
              {status:'confirmed',summary:'Họp nhóm',start:{dateTime:'2026-07-27T09:00:00+07:00'},end:{dateTime:'2026-07-27T10:00:00+07:00'}},
              {status:'confirmed',summary:'Gym tối',start:{dateTime:'2026-07-27T18:00:00+07:00'},end:{dateTime:'2026-07-27T19:00:00+07:00'}},
              {status:'confirmed',summary:'Cả ngày',start:{date:'2026-07-27'},end:{date:'2026-07-28'}}
            ]}),{status:200,headers:{'Content-Type':'application/json'}}));
          }
          return nativeFetch(url,options);
        };
      `,
    });
    await send('Emulation.setDeviceMetricsOverride', {
      width,
      height,
      deviceScaleFactor: 1,
      mobile: width <= 420,
    });
    await send('Page.navigate', { url: pageUrl });
    for (let attempt = 0; attempt < 50; attempt++) {
      const ready = await send('Runtime.evaluate', {
        expression: `document.readyState==='complete'&&typeof fetchGoogleCalendarToday==='function'`,
        returnByValue: true,
      });
      if (ready.result.value === true) break;
      await delay(100);
    }

    const evaluated = await send('Runtime.evaluate', {
      expression: `(async()=>{selectClockProfile(2);await connectGoogleCalendar();await fetchGoogleCalendarToday();const packet=buildD2SetDailyPacket(new Date(2026,6,27,12,0));dailyContextPanel.scrollIntoView({block:'start'});return JSON.stringify({width:innerWidth,scroll:document.documentElement.scrollWidth,advanced:advancedPanel.open,status:googleCalendarStatus.textContent,times:[dailyAgendaTime0.value,dailyAgendaTime1.value],labels:[dailyAgendaLabel0.value,dailyAgendaLabel1.value],titles:[dailyAgendaTitle0.textContent,dailyAgendaTitle1.textContent],packet:[...packet],token:googleCalendarToken})})()`,
      awaitPromise: true,
      returnByValue: true,
    });
    assert.ok(!evaluated.exceptionDetails, `${name} fixture failed`);
    const page = JSON.parse(evaluated.result.value);
    assert.ok(page.scroll <= page.width, `${name} horizontal overflow`);
    assert.equal(page.advanced, false, `${name} advanced panel`);
    assert.deepEqual(page.times, ['09:00', '18:00'], `${name} event times`);
    assert.deepEqual(page.labels, ['HOP', 'GYM'], `${name} normalized labels`);
    assert.deepEqual(page.titles, ['Họp nhóm', 'Gym tối'], `${name} event titles`);
    assert.match(page.status, /Đã lấy 2 lịch/, `${name} status`);
    assert.equal(page.packet.length, 20, `${name} D2 packet length`);
    assert.deepEqual(page.packet.slice(0, 2), [0xD2, 0x08], `${name} D2 command`);
    assert.equal(page.packet[9], 2, `${name} agenda count`);
    assert.equal(page.token, 'fixture-token', `${name} page-session token`);

    const shot = await send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: false,
    });
    fs.writeFileSync(`${PROOF}/${name}.png`, Buffer.from(shot.data, 'base64'));
    socket.close();
  } finally {
    chrome.kill();
  }
}

await capture('desktop', 1365, 820);
await capture('mobile', 360, 800);
fs.writeFileSync(
  `${PROOF}/browser-check.txt`,
  'TASK D15B Google Calendar agenda browser proof PASS\nCanonical URL: https://onlysky17.github.io/Clock/test.html\n',
);
console.log('TASK D15B Google Calendar agenda smoke PASS');
