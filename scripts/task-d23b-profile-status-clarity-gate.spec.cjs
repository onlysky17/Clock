const { test, expect } = require("playwright/test");
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

const runtimePath = path.resolve(
  __dirname,
  "..",
  "web",
  "clock-app",
  "hl24a-canvas-e5.html"
);

const storageKey = "einkClock.productMode.layout";
const proofDir = process.env.D23B_PROOF_DIR;

let server;
let runtimeUrl;

test.beforeAll(async () => {
  server = http.createServer((_request, response) => {
    response.writeHead(200, {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store"
    });

    response.end(fs.readFileSync(runtimePath));
  });

  await new Promise((resolve, reject) => {
    server.once("error", reject);

    server.listen(0, "127.0.0.1", () => {
      server.off("error", reject);
      resolve();
    });
  });

  const address = server.address();
  runtimeUrl = `http://127.0.0.1:${address.port}/`;
});

test.afterAll(async () => {
  if (server) {
    await new Promise(resolve => server.close(resolve));
  }
});

const cases = [
  {
    name: "desktop-1280",
    viewport: { width: 1280, height: 1000 },
    layout: "dashboard",
    label: "Dashboard",
    screenshot: "desktop-1280.png"
  },
  {
    name: "mobile-360",
    viewport: { width: 360, height: 800 },
    layout: "minimal",
    label: "Minimal",
    screenshot: "mobile-360.png"
  }
];

for (const item of cases) {
  test(`${item.name} separates web and device status`, async ({ page }) => {
    await page.setViewportSize(item.viewport);
    await page.goto(runtimeUrl, { waitUntil: "load" });

    await page.evaluate(
      ({ key, layout }) => {
        localStorage.setItem(key, layout);
      },
      {
        key: storageKey,
        layout: item.layout
      }
    );

    await page.reload({ waitUntil: "load" });

    const select = page.locator("#productLayoutSelect");
    const status = page.locator("#profileStatus");

    await expect(select).toHaveValue(item.layout);

    await expect(status).toContainText(
      `Đã nhớ trên web: ${item.label}`
    );

    await expect(status).toContainText(
      "Chưa áp dụng lên thiết bị"
    );

    await expect(status).toContainText(
      "Thiết bị đang chạy: Split View"
    );

    await expect(status).toContainText(
      "Thiết bị lưu: mặc định"
    );

    await expect(
      page.locator(`[data-layout-profile="${item.layout}"]`)
    ).toHaveClass(/selected/);

    const truth = await page.evaluate(() => {
      const identity = document.querySelector(".identityCard");

      return {
        runtime: identity?.dataset.expectedRuntime || "",
        sourceId: identity?.dataset.expectedSourceId || "",
        noOverflow:
          document.documentElement.scrollWidth <= window.innerWidth
      };
    });

    expect(truth.runtime).toBe("D8A1");
    expect(truth.sourceId).toBe("D8A00001");
    expect(truth.noOverflow).toBe(true);

    await page.screenshot({
      path: path.join(proofDir, item.screenshot),
      fullPage: true
    });

    console.log(
      `[PASS] ${item.name}: remembered/device status clear`
    );
  });
}