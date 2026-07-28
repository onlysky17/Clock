import fs from "node:fs";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const privacyPath = path.join(root, "privacy.html");
const docsPath = path.join(
  root,
  "docs",
  "web",
  "TASK_D19B_GOOGLE_CALENDAR_PRODUCTION_AUTH_SETUP.md",
);
const appPath = path.join(
  root,
  "web",
  "clock-app",
  "hl24a-canvas-e5.html",
);
const testPath = path.join(root, "test.html");

const privacy = fs.readFileSync(privacyPath, "utf8");
const docs = fs.readFileSync(docsPath, "utf8");
const app = fs.readFileSync(appPath, "utf8");
const testPage = fs.readFileSync(testPath, "utf8");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

assert(
  privacy.includes("<title>Quyền riêng tư - EINK Clock</title>"),
  "privacy page must have the EINK Clock title",
);
assert(
  privacy.includes("calendar.readonly"),
  "privacy page must disclose the read-only Calendar scope",
);
assert(
  privacy.includes("không tạo, sửa hoặc xóa"),
  "privacy page must state that Calendar events are not modified",
);
assert(
  privacy.includes("chỉ được giữ trong phiên của tab trình duyệt"),
  "privacy page must disclose session-only handling",
);
assert(
  privacy.includes("không bán, chia sẻ cho quảng cáo"),
  "privacy page must disclose that Calendar data is not sold",
);
assert(
  privacy.includes("Ngắt quyền lịch"),
  "privacy page must explain permission revocation",
);
assert(
  privacy.includes('href="./test.html"'),
  "privacy page must link back to the canonical app entry",
);

assert(
  docs.includes("https://onlysky17.github.io/Clock/test.html"),
  "setup guide must preserve the canonical app URL",
);
assert(
  docs.includes("https://onlysky17.github.io/Clock/privacy.html"),
  "setup guide must define the public privacy URL",
);
assert(
  docs.includes("PUBLIC POLICY READY / GOOGLE APPROVAL NOT YET VERIFIED"),
  "setup guide must not claim unproven Google approval",
);
assert(
  docs.includes("Google Calendar remains optional"),
  "setup guide must keep Google Calendar optional",
);
assert(
  docs.includes("No client secret"),
  "setup guide must prohibit a client secret in the static app",
);

assert(
  app.includes(
    '<meta name="google-calendar-client-id" content="64961652220-4b2s7mnvqfut2fsu213gokbi28qs74t6.apps.googleusercontent.com">',
  ),
  "existing Google Calendar client ID must remain unchanged",
);
assert(
  app.includes(
    "https://www.googleapis.com/auth/calendar.readonly",
  ),
  "existing Calendar scope must remain read-only",
);
assert(
  testPage.includes("./web/clock-app/hl24a-canvas-e5.html"),
  "canonical test.html redirect must remain unchanged",
);

console.log("TASK D19B Google Calendar production auth setup smoke: PASS");
