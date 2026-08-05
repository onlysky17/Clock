import fs from "node:fs";
import assert from "node:assert/strict";

const runtimeUrl = new URL(
  "../web/clock-app/hl24a-canvas-e5.html",
  import.meta.url
);

const html = fs.readFileSync(runtimeUrl, "utf8");

const required = [
  "webBuild:'D22F-PRODUCT-MODE-20260804'",
  "label:'EINK CLOCK PRODUCT MODE'",
  "expectedRuntime:'D8A1'",
  "expectedSourceId:'D8A00001'",
  "identityCard.dataset.einkWebBuild=EINK_TEST_IDENTITY.webBuild",
  "identityCard.dataset.expectedRuntime=EINK_TEST_IDENTITY.expectedRuntime",
  "identityCard.dataset.expectedSourceId=EINK_TEST_IDENTITY.expectedSourceId"
];

for (const marker of required) {
  assert.ok(
    html.includes(marker),
    `Missing D22F identity marker: ${marker}`
  );
}

assert.ok(
  !html.includes("D20B-SIMPLE-PRODUCT-20260730"),
  "Stale D20B web build remains"
);

assert.ok(
  !html.includes("D20B PRODUCT MODE GỌN"),
  "Stale D20B Product Mode label remains"
);

console.log("TASK D22F Product Mode identity truth smoke PASS");