import fs from 'node:fs';
import { execFileSync } from 'node:child_process';

const docPath = 'docs/firmware/TASK_D12A_CLOCK_PREFERENCE_POLICY.md';
const sourcePath = 'firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c';
const doc = fs.readFileSync(docPath, 'utf8');
const source = fs.readFileSync(sourcePath, 'utf8');

function need(pattern, message) {
  if (!pattern.test(doc)) throw new Error(message);
}

need(/DESIGN COMPLETE - NO RUNTIME CHANGE/, 'design-only status missing');
need(/`00`: 24-hour display, default/, '24-hour default missing');
need(/`01`: 12-hour display/, '12-hour mode missing');
need(/`01`: every minute[\s\S]*`05`: every five minutes, default[\s\S]*`0A`: every ten minutes/, '1/5/10 cadence policy missing');
need(/SET_CLOCK_PREFERENCES[\s\S]*Exact request, 4 bytes[\s\S]*\| 1 \| `06`/, 'D2 06 exact SET contract missing');
need(/GET_CLOCK_PREFERENCES[\s\S]*Exact request: `D2 07`/, 'D2 07 GET contract missing');
need(/PREFERENCE_STATUS[\s\S]*Exact 8-byte notify[\s\S]*\| 1 \| `86`/, 'D2 86 status contract missing');
need(/New result `08` means INVALID_PREFERENCE/, 'invalid preference result missing');
need(/`16`: existing clock profile[\s\S]*`17`: hour mode[\s\S]*`18`: refresh minutes[\s\S]*`19\.\.29`: reserved `FF`/, 'persistence byte map missing');
need(/CRC over bytes `0\.\.29`[\s\S]*CRC at `30\.\.31`/, 'CRC compatibility missing');
need(/local_minute % cadence == 0/, 'scheduler formula missing');
need(/Day rollover remains a forced render/, 'day rollover policy missing');
need(/BUSY uses the same wait-and-retry-once guard/, 'web BUSY policy missing');
need(/D11C raw baseline: `48380` bytes[\s\S]*D12B target raw: at most `50000` bytes/, 'size gate missing');
need(/RAM increase: at most `8` bytes/, 'RAM gate missing');
need(/TASK D12B - IMPLEMENT CLOCK PREFERENCES/, 'next action missing');

if (!/rec\[16\] = hink_clock_profile/.test(source)) throw new Error('D11B profile persistence foundation missing');
if (!/#define HINK_D3D_CRC_OFFSET\s+30U/.test(source)) throw new Error('D3D CRC layout changed');
if (!/\(auto_minute % 5UL\) == 0UL/.test(source)) throw new Error('safe five-minute baseline missing');

const status = execFileSync('git', ['status', '--short', '--untracked-files=all'], { encoding: 'utf8' });
for (const line of status.trimEnd().split(/\r?\n/).filter(Boolean)) {
  const path = line.slice(3).trim();
  const allowed = new Set([
    'docs/agent/CURRENT_STATE.md',
    'docs/agent/NEXT_ACTION.md',
    docPath,
    'scripts/task-d12a-clock-preference-policy-smoke.mjs'
  ]);
  if (!allowed.has(path)) throw new Error(`out-of-scope dirty file: ${path}`);
}

console.log('TASK D12A clock preference policy smoke PASS');
