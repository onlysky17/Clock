import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const appPath = path.join(root, "web", "clock-app", "hl24a-canvas-e5.html");
const privacyPath = path.join(root, "privacy.html");
const testPath = path.join(root, "test.html");

const app = fs.readFileSync(appPath, "utf8");
const privacy = fs.readFileSync(privacyPath, "utf8");
const testPage = fs.readFileSync(testPath, "utf8");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

assert(
  app.includes("privacyLink.dataset.einkPrivacyLink='D19B'"),
  "Product Mode must expose a stable privacy marker",
);
assert(
  app.includes('href="../../privacy.html"'),
  "Product Mode privacy link must resolve to the public policy",
);
assert(
  app.includes(">Quyền riêng tư</a>"),
  "Product Mode must show the Vietnamese privacy label",
);
assert(
  app.includes(
    "main.append(header,statusCard,presetCard,identityCard,previewCard,advanced,privacyLink)",
  ),
  "privacy link must be visible in Product Mode and outside Advanced",
);
assert(
  privacy.includes("<title>Quyền riêng tư - EINK Clock</title>"),
  "public privacy policy must remain present",
);
assert(
  privacy.includes("calendar.readonly"),
  "privacy policy must keep the read-only Calendar disclosure",
);
assert(
  app.includes(
    '<meta name="google-calendar-client-id" content="64961652220-4b2s7mnvqfut2fsu213gokbi28qs74t6.apps.googleusercontent.com">',
  ),
  "Google Calendar client ID must remain unchanged",
);
assert(
  app.includes("https://www.googleapis.com/auth/calendar.readonly"),
  "Google Calendar scope must remain read-only",
);
assert(
  testPage.includes("./web/clock-app/hl24a-canvas-e5.html"),
  "canonical test.html redirect must remain unchanged",
);

console.log("TASK D19B-FIX1 visible privacy link smoke: PASS");
