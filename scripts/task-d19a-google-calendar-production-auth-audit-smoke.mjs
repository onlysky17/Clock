import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const docPath = path.join(
  repo,
  "docs",
  "web",
  "TASK_D19A_GOOGLE_CALENDAR_PRODUCTION_AUTH_READINESS.md",
);
const webPath = path.join(
  repo,
  "web",
  "clock-app",
  "hl24a-canvas-e5.html",
);

const doc = fs.readFileSync(docPath, "utf8");
const web = fs.readFileSync(webPath, "utf8");

assert.match(doc, /AUDIT PASS \/ GOOGLE CLOUD ACTION REQUIRED/);
assert.match(doc, /https:\/\/onlysky17\.github\.io\/Clock\/test\.html/);
assert.match(doc, /eink-clock-onlysky17/);
assert.match(
  doc,
  /64961652220-4b2s7mnvqfut2fsu213gokbi28qs74t6\.apps\.googleusercontent\.com/,
);
assert.match(doc, /https:\/\/www\.googleapis\.com\/auth\/calendar\.readonly/);
assert.match(doc, /publishing and verification are separate/i);
assert.match(doc, /Testing authorizations expire after seven days/);
assert.match(doc, /short-lived access token, not a refresh token/);
assert.match(doc, /No OAuth client secret belongs/);
assert.match(doc, /Google Calendar remains optional/);
assert.match(
  doc,
  /TASK D19B - GOOGLE CALENDAR PRODUCTION AUTH SETUP AND OWNER VERIFICATION/,
);
assert.match(doc, /must not claim Google verification/);

assert.match(
  web,
  /name="google-calendar-client-id" content="64961652220-4b2s7mnvqfut2fsu213gokbi28qs74t6\.apps\.googleusercontent\.com"/,
);
assert.match(
  web,
  /GOOGLE_CALENDAR_SCOPE='https:\/\/www\.googleapis\.com\/auth\/calendar\.readonly'/,
);
assert.match(web, /oauth2\.initTokenClient\(\{/);
assert.match(web, /sessionStorage\.setItem\(GOOGLE_CALENDAR_SESSION_KEY/);
assert.match(web, /sessionStorage\.removeItem\(GOOGLE_CALENDAR_SESSION_KEY/);
assert.match(web, /prompt:googleCalendarToken\?'':'consent'/);
assert.doesNotMatch(web, /client_secret/i);
assert.doesNotMatch(web, /refresh_token/i);

const allowed = new Set([
  "docs/web/TASK_D19A_GOOGLE_CALENDAR_PRODUCTION_AUTH_READINESS.md",
  "scripts/task-d19a-google-calendar-production-auth-audit-smoke.mjs",
]);
const status = execFileSync(
  "git",
  ["status", "--porcelain=v1", "--untracked-files=all"],
  { cwd: repo, encoding: "utf8" },
);
for (const line of status.split(/\r?\n/).filter(Boolean)) {
  const changedPath = line.slice(3).replaceAll("\\", "/");
  assert.ok(allowed.has(changedPath), `unexpected dirty path: ${changedPath}`);
  assert.ok(!/\.(?:bin|axf|map|hex)$/i.test(changedPath));
  assert.ok(!changedPath.startsWith("_incoming/"));
}

console.log("TASK D19A Google Calendar production auth audit smoke PASS");
