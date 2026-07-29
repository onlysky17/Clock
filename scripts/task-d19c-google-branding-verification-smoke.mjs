import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const home = readFileSync(new URL("../index.html", import.meta.url), "utf8");

assert.match(home, /<title>Eink Clock<\/title>/);
assert.match(home, /name="google-site-verification"\s+content="fOdDONezWAXAhJ6nh9uycBKjko_NOm1bcfpLhsdrTn0"/);
assert.match(home, /đồng hồ e-ink HINK213/i);
assert.match(home, /Google Calendar là tùy chọn/i);
assert.match(home, /href="\.\/test\.html"/);
assert.match(home, /href="\.\/privacy\.html"/);
assert.doesNotMatch(home, /http-equiv="refresh"/i);
assert.doesNotMatch(home, /location\.replace/i);

console.log("TASK D19C branding verification smoke: PASS");
