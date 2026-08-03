const { test, expect } = require("playwright/test");
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const productPage = "/web/clock-app/hl24a-canvas-e5.html";
const proofDir = path.join(repoRoot, "_incoming", "D22A_BROWSER_PROOF");

let server;
let baseUrl;

function contentType(filePath) {
  const extension = path.extname(filePath).toLowerCase();

  if (extension === ".html") return "text/html; charset=utf-8";
  if (extension === ".js" || extension === ".mjs") {
    return "text/javascript; charset=utf-8";
  }
  if (extension === ".css") return "text/css; charset=utf-8";
  if (extension === ".json") return "application/json; charset=utf-8";
  if (extension === ".png") return "image/png";
  if (extension === ".svg") return "image/svg+xml";
  if (extension === ".woff2") return "font/woff2";

  return "application/octet-stream";
}

function startServer() {
  return new Promise((resolve, reject) => {
    server = http.createServer((request, response) => {
      try {
        const requestUrl = new URL(
          request.url || "/",
          "http://127.0.0.1"
        );

        const relativePath = decodeURIComponent(
          requestUrl.pathname
        ).replace(/^\/+/, "");

        const filePath = path.resolve(repoRoot, relativePath);
        const allowedRoot = repoRoot + path.sep;

        if (
          filePath !== repoRoot &&
          !filePath.startsWith(allowedRoot)
        ) {
          response.writeHead(403);
          response.end("Forbidden");
          return;
        }

        if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
          response.writeHead(404);
          response.end("Not found");
          return;
        }

        response.writeHead(200, {
          "Content-Type": contentType(filePath),
          "Cache-Control": "no-store"
        });

        fs.createReadStream(filePath).pipe(response);
      } catch (error) {
        response.writeHead(500);
        response.end(String(error));
      }
    });

    server.once("error", reject);

    server.listen(0, "127.0.0.1", () => {
      const address = server.address();

      if (!address || typeof address === "string") {
        reject(new Error("Cannot determine local server address"));
        return;
      }

      baseUrl = `http://127.0.0.1:${address.port}`;
      resolve();
    });
  });
}

function stopServer() {
  return new Promise((resolve, reject) => {
    if (!server) {
      resolve();
      return;
    }

    server.close(error => {
      if (error) reject(error);
      else resolve();
    });
  });
}

async function installBluetoothMock(page) {
  await page.addInitScript(() => {
    window.__d22aBluetoothCalls = [];

    const bluetoothMock = {
      requestDevice: async options => {
        window.__d22aBluetoothCalls.push({
          options: options || null,
          userActivation: Boolean(
            navigator.userActivation &&
            navigator.userActivation.isActive
          ),
          timestamp: performance.now()
        });

        throw new DOMException(
          "D22A deterministic chooser stop",
          "NotFoundError"
        );
      }
    };

    try {
      Object.defineProperty(navigator, "bluetooth", {
        configurable: true,
        enumerable: true,
        value: bluetoothMock
      });
    } catch {
      Object.defineProperty(Navigator.prototype, "bluetooth", {
        configurable: true,
        enumerable: true,
        get() {
          return bluetoothMock;
        }
      });
    }
  });
}

async function resolveAdvancedControls(page) {
  return page.evaluate(() => {
    const normalizedText = element =>
      String(element.textContent || "")
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLowerCase()
        .trim();

    const candidates = Array.from(
      document.querySelectorAll(
        "button, summary, [role='button'], [aria-expanded]"
      )
    );

    const toggle = candidates.find(element => {
      const id = String(element.id || "").toLowerCase();
      const controls = String(
        element.getAttribute("aria-controls") || ""
      ).toLowerCase();
      const text = normalizedText(element);

      return (
        id.includes("advanced") ||
        controls.includes("advanced") ||
        text.includes("nang cao") ||
        text.includes("advanced")
      );
    });

    if (!toggle) {
      throw new Error("Cannot find independent Advanced toggle");
    }

    const controlledId = toggle.getAttribute("aria-controls");
    let panel = controlledId
      ? document.getElementById(controlledId)
      : null;

    if (!panel) {
      panel =
        document.querySelector(
          "#advancedPanel, #productAdvancedPanel, " +
          ".advancedPanel, .advanced-section, [data-advanced]"
        ) ||
        toggle.closest("details") ||
        toggle.nextElementSibling;
    }

    if (!panel) {
      throw new Error("Cannot find Advanced panel");
    }

    toggle.setAttribute("data-d22a-advanced-toggle", "true");
    panel.setAttribute("data-d22a-advanced-panel", "true");

    const panelVisible = (() => {
      if (panel.tagName === "DETAILS") {
        return panel.open;
      }

      const style = getComputedStyle(panel);

      return (
        !panel.hidden &&
        panel.getAttribute("aria-hidden") !== "true" &&
        style.display !== "none" &&
        style.visibility !== "hidden"
      );
    })();

    const expanded = toggle.getAttribute("aria-expanded");

    return {
      open:
        panel.tagName === "DETAILS"
          ? panel.open
          : expanded === "true" || panelVisible,
      toggleTag: toggle.tagName,
      panelTag: panel.tagName
    };
  });
}

async function setMockConnectedState(page) {
  const result = await page.evaluate(() => {
    const runtime = window.eval(`
      (() => {
        const assignments = [
          ["server", "({ connected: true, disconnect() { this.connected = false; } })"],
          ["identityCompatibility", "'compatible'"],
          ["productD2State", "1"],
          ["productD2RenderState", "null"],
          ["productD2Result", "null"],
          ["productD2RenderResult", "null"],
          ["d2StalePresent", "false"],
          ["productErrorReason", "''"],
          ["unifiedDailyUpdateRunning", "false"]
        ];

        const applied = [];
        const errors = {};

        for (const [name, expression] of assignments) {
          try {
            eval(name + "=" + expression);
            applied.push(name);
          } catch (error) {
            errors[name] = String(error);
          }
        }

        if (typeof controls === "function") {
          controls();
        }

        return {
          applied,
          errors,
          serverConnected: Boolean(server?.connected),
          identityCompatibility
        };
      })()
    `);

    const setText = (id, text) => {
      const element = document.getElementById(id);
      if (element) element.textContent = text;
    };

    setText("identityCompatibility", "Tương thích");
    setText(
      "identityCompatibilityDetail",
      "D22A mocked connected browser state."
    );
    setText("actualFirmware", "D18B");
    setText("actualSourceId", "D22A-MOCK");
    setText("actualHealth", "OK");
    setText("batteryVoltage", "3.01 V");
    setText("batteryLevel", "Ước tính 80%");

    return {
      ...runtime,
      connectDisabled:
        document.getElementById("connect")?.disabled === true,
      disconnectEnabled:
        document.getElementById("disconnect")?.disabled === false,
      profileApplyEnabled:
        document.getElementById("profileApply")?.disabled === false,
      unifiedDailyEnabled:
        document.getElementById("unifiedDailyUpdate")?.disabled === false
    };
  });

  expect(result.errors).toEqual({});

  expect(result.applied).toEqual(
    expect.arrayContaining([
      "server",
      "identityCompatibility",
      "productD2State"
    ])
  );

  expect(result.serverConnected).toBe(true);
  expect(result.identityCompatibility).toBe("compatible");
  expect(result.connectDisabled).toBe(true);
  expect(result.disconnectEnabled).toBe(true);
  expect(result.profileApplyEnabled).toBe(true);
  expect(result.unifiedDailyEnabled).toBe(true);
}
async function assertNoHorizontalOverflow(page) {
  const dimensions = await page.evaluate(() => ({
    innerWidth: window.innerWidth,
    documentWidth: document.documentElement.scrollWidth,
    bodyWidth: document.body.scrollWidth
  }));

  expect(
    dimensions.documentWidth,
    JSON.stringify(dimensions)
  ).toBeLessThanOrEqual(dimensions.innerWidth + 1);

  expect(
    dimensions.bodyWidth,
    JSON.stringify(dimensions)
  ).toBeLessThanOrEqual(dimensions.innerWidth + 1);
}

async function assertInitialProductMode(page) {
  const requiredIds = [
    "connect",
    "disconnect",
    "productConnectRow",
    "identityCompatibility",
    "batteryVoltage",
    "productPresetRow",
    "profileApply",
    "unifiedDailyUpdate"
  ];

  for (const id of requiredIds) {
    await expect(
      page.locator(`#${id}`),
      `Initial Product Mode control #${id}`
    ).toBeVisible();
  }

  await expect(page.locator("#connect")).toBeEnabled();

  const advanced = await resolveAdvancedControls(page);

  expect(
    advanced.open,
    `Advanced must start closed: ${JSON.stringify(advanced)}`
  ).toBe(false);
}

async function verifyDirectOwnerGesture(page) {
  await page.locator("#connect").click();

  await expect
    .poll(
      () =>
        page.evaluate(
          () => window.__d22aBluetoothCalls.length
        ),
      {
        message:
          "Owner click must call navigator.bluetooth.requestDevice"
      }
    )
    .toBe(1);

  const call = await page.evaluate(
    () => window.__d22aBluetoothCalls[0]
  );

  expect(call.userActivation).toBe(true);
  expect(call.options).toBeTruthy();
}

async function openAdvancedIndependently(page) {
  const toggle = page.locator(
    "[data-d22a-advanced-toggle='true']"
  );

  await expect(toggle).toBeVisible();
  await toggle.click();

  await expect
    .poll(async () => {
      const state = await resolveAdvancedControls(page);
      return state.open;
    })
    .toBe(true);

  await expect(page.locator("#connect")).toBeVisible();
  await expect(page.locator("#disconnect")).toBeVisible();
  await expect(page.locator("#profileApply")).toBeVisible();
  await expect(page.locator("#unifiedDailyUpdate")).toBeVisible();
  await expect(page.locator("#batteryVoltage")).toBeVisible();
  await expect(
    page.locator("[data-d22a-advanced-panel='true']")
  ).toBeVisible();
}

test.beforeAll(async () => {
  fs.mkdirSync(proofDir, { recursive: true });
  await startServer();
});

test.afterAll(async () => {
  await stopServer();
});

test.describe.configure({ mode: "serial" });

const scenarios = [
  {
    name: "desktop",
    viewport: { width: 1280, height: 900 }
  },
  {
    name: "mobile-360",
    viewport: { width: 360, height: 800 }
  }
];

for (const scenario of scenarios) {
  test(
    `${scenario.name} Product Mode runtime regression gate`,
    async ({ browser }) => {
      const context = await browser.newContext({
        viewport: scenario.viewport,
        deviceScaleFactor: 1
      });

      const page = await context.newPage();

      await page.route("**/*", async route => {
        const requestUrl = new URL(route.request().url());

        if (requestUrl.hostname === "127.0.0.1") {
          await route.continue();
          return;
        }

        await route.fulfill({
          status: 204,
          body: "",
          contentType: "text/plain"
        });
      });

      await installBluetoothMock(page);

      await page.goto(baseUrl + productPage, {
        waitUntil: "domcontentloaded"
      });

      await assertInitialProductMode(page);
      await assertNoHorizontalOverflow(page);

      await page.screenshot({
        path: path.join(
          proofDir,
          `${scenario.name}-initial.png`
        ),
        fullPage: true
      });

      await verifyDirectOwnerGesture(page);
      await setMockConnectedState(page);

      await expect(page.locator("#disconnect")).toBeEnabled();
      await expect(
        page.locator("#identityCompatibility")
      ).toBeVisible();
      await expect(page.locator("#batteryVoltage")).toHaveText(
        "3.01 V"
      );
      await expect(page.locator("#productPresetRow")).toBeVisible();
      await expect(page.locator("#profileApply")).toBeVisible();
      await expect(
        page.locator("#unifiedDailyUpdate")
      ).toBeVisible();

      await openAdvancedIndependently(page);
      await assertNoHorizontalOverflow(page);

      await page.screenshot({
        path: path.join(
          proofDir,
          `${scenario.name}-connected-advanced.png`
        ),
        fullPage: true
      });

      await context.close();
    }
  );
}