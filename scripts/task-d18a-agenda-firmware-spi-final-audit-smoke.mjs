import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const docPath = path.join(
  repo,
  "docs",
  "firmware",
  "TASK_D18A_AGENDA_FIRMWARE_SPI_FINAL_AUDIT.md",
);
const sourcePath = path.join(
  repo,
  "firmware",
  "active",
  "HINK213_CLOCK_22_BASE",
  "src",
  "user_custs1_impl.c",
);
const packerPath = path.join(repo, "tools", "pack-hink.ps1");
const goldenPath = path.join(
  repo,
  "tools",
  "packages",
  "HINK213_CLOCK_CONNECT_GOOD_FULL_256KB.bin",
);

const doc = fs.readFileSync(docPath, "utf8");
const source = fs.readFileSync(sourcePath, "utf8");
const packer = fs.readFileSync(packerPath, "utf8");
const golden = fs.readFileSync(goldenPath);
const sha256 = (value) =>
  crypto.createHash("sha256").update(value).digest("hex").toUpperCase();

assert.match(doc, /AUDIT PASS \/ READY FOR D18B FRESH BUILD/);
assert.match(doc, /af6568912d5e4b3e1755bd11b441bae60eec2bee/);
assert.match(doc, /Agenda-on-device implementation: `91e86be`/);
assert.match(doc, /Raw BIN size: `50552` bytes/);
assert.match(doc, /Measured headroom: `14976` bytes/);
assert.match(doc, /D3678620B265DA7246964B2AB528609D9EE161CD3FE1146E36FC54DD96FF53B0/);
assert.match(doc, /808B5CFA92A0CDF2F4D0B3C72FDF65FFCE4841CED14A03E66CF6EFDC30EEDE01/);
assert.match(doc, /012B4A465ECCE86CA80F5E575BE30492AC50FB455AEC2F8A0318083CE50A9197/);
assert.match(doc, /Semantic diff: empty/);
assert.match(doc, /must not be promoted to the final SPI package/);
assert.match(doc, /TASK D18B - BUILD AND PACKAGE AGENDA FIRMWARE SPI FINAL/);
assert.match(doc, /No packed D18 image exists yet/);

assert.match(source, /#define HINK_EPD_PRIME_RECOVERY_TICKS 100UL/);
assert.match(source, /#define HINK_D13D_WEATHER_X 6U/);
assert.match(source, /hink_daily_agenda_minute\[2\]/);
assert.match(source, /hink_daily_agenda_label\[2\]\[3\]/);
assert.match(source, /hink_d13b_draw_daily_briefing/);
assert.match(source, /hink_d2_daily_handle/);

assert.match(packer, /\$FlashSize = 0x40000/);
assert.match(packer, /\$ImageHeaderOffset = 0x04000/);
assert.match(packer, /\$ImagePayloadOffset = 0x04040/);
assert.match(packer, /\$ProductHeaderOffset = 0x38000/);
assert.match(packer, /\$MaxRawSize = 0x10000/);

assert.equal(golden.length, 262144, "canonical golden must be 256 KB");
assert.equal(
  sha256(golden),
  "C52E3E96CA76B45245FE5457721FFE6163C25C1840D120EB45F398817DA49452",
  "canonical golden hash changed",
);

const allowed = new Set([
  "docs/firmware/TASK_D18A_AGENDA_FIRMWARE_SPI_FINAL_AUDIT.md",
  "scripts/task-d18a-agenda-firmware-spi-final-audit-smoke.mjs",
]);
const status = execFileSync(
  "git",
  ["status", "--porcelain=v1", "--untracked-files=all"],
  { cwd: repo, encoding: "utf8" },
);
for (const line of status.split(/\r?\n/).filter(Boolean)) {
  const changedPath = line.slice(3).replaceAll("\\", "/");
  assert.ok(allowed.has(changedPath), `unexpected dirty path: ${changedPath}`);
  assert.ok(!/\.(?:bin|axf|map|hex|htm)$/i.test(changedPath));
  assert.ok(!changedPath.startsWith("_incoming/"));
}

console.log("TASK D18A agenda firmware SPI final audit smoke PASS");
