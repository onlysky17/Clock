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
const proofDir = process.env.D23A_PROOF_DIR;

let server;
let runtimeUrl;

test.beforeAll(async () => {
  server = http.createServer((request, response) => {
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
  if (!server) {
    return;
  }

  await new Promise(resolve => server.close(resolve));
});

const cases = [
  {
    name: "desktop-1280",
    viewport: { width: 1280, height: 1000 },
    finalLayout: "dashboard",
    screenshot: "desktop-1280.png"
  },
  {
    name: "mobile-360",
    viewport: { width: 360, height: 800 },
    finalLayout: "minimal",
    screenshot: "mobile-360.png"
  }
];

for (const item of cases) {
  test(`${item.name} remembers profile after reload`, async ({ page }) => {
    await page.setViewportSize(item.viewport);
    await page.goto(runtimeUrl, { waitUntil: "load" });

    await page.evaluate(key => {
      localStorage.removeItem(key);
    }, storageKey);

    await page.reload({ waitUntil: "load" });

    const select = page.locator("#productLayoutSelect");

    await expect(select).toHaveValue("split");

    await expect(
      page.locator('[data-layout-profile="split"]')
    ).toHaveClass(/selected/);

    await select.selectOption("dashboard");

    expect(
      await page.evaluate(key => localStorage.getItem(key), storageKey)
    ).toBe("dashboard");

    await page.reload({ waitUntil: "load" });

    await expect(select).toHaveValue("dashboard");

    await expect(
      page.locator('[data-layout-profile="dashboard"]')
    ).toHaveClass(/selected/);

    await select.selectOption("minimal");
    await page.reload({ waitUntil: "load" });

    await expect(select).toHaveValue("minimal");

    await expect(
      page.locator('[data-layout-profile="minimal"]')
    ).toHaveClass(/selected/);

    await page.evaluate(key => {
      localStorage.setItem(key, "invalid-layout");
    }, storageKey);

    await page.reload({ waitUntil: "load" });

    await expect(select).toHaveValue("split");

    expect(
      await page.evaluate(key => localStorage.getItem(key), storageKey)
    ).toBe("split");

    await select.selectOption(item.finalLayout);
    await page.reload({ waitUntil: "load" });

    await expect(select).toHaveValue(item.finalLayout);

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
      `[PASS] ${item.name}: ${item.finalLayout} survives reload`
    );
  });
}