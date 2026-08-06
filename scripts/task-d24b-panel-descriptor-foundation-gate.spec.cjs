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

const proofDir = process.env.D24B_PROOF_DIR;

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

function legacyPack(blackPixels) {
  const output = new Uint8Array(4000).fill(0xff);

  for (const [x, y] of blackPixels) {
    const ramX = y;
    const ramY = 250 - 1 - x;
    const index = ramY * 16 + (ramX >> 3);

    output[index] &= ~(1 << (7 - (ramX & 7)));
  }

  return output;
}

const cases = [
  {
    name: "desktop-1280",
    viewport: { width: 1280, height: 1000 },
    screenshot: "desktop-1280.png"
  },
  {
    name: "mobile-360",
    viewport: { width: 360, height: 800 },
    screenshot: "mobile-360.png"
  }
];

for (const item of cases) {
  test(`${item.name} preserves HINK213 through descriptor`, async ({
    page
  }) => {
    await page.setViewportSize(item.viewport);
    await page.goto(runtimeUrl, { waitUntil: "load" });

    const truth = await page.evaluate(() => {
      const panel = window.EINK_ACTIVE_PANEL;
      const canvas = document.querySelector("#canvas");
      const progress = document.querySelector("#progress");

      clearWhite();

      const pixels = [
        [0, 0],
        [249, 0],
        [0, 121],
        [249, 121],
        [17, 9],
        [120, 61]
      ];

      for (const [x, y] of pixels) {
        ctx.fillStyle = "#000";
        ctx.fillRect(x, y, 1, 1);
      }

      const result = packCanvas();
      const start = [...startPacket(0x24)];

      return {
        panel,
        canvasWidth: canvas.width,
        canvasHeight: canvas.height,
        progressMax: progress.max,
        previewGeometry:
          document.querySelector("#previewGeometry").textContent,
        ramGeometry:
          document.querySelector("#ramGeometry").textContent,
        strideBytes:
          document.querySelector("#strideBytes").textContent,
        byteCount:
          document.querySelector("#byteCount").textContent,
        chunkCount:
          document.querySelector("#chunkCount").textContent,
        transferSummary:
          document.querySelector("#expectedTransferSummary").textContent,
        packingSummary:
          document.querySelector("#panelPackingSummary").textContent,
        packed: [...result.bytes],
        black: result.black,
        start,
        runtime: EINK_TEST_IDENTITY.expectedRuntime,
        sourceId: EINK_TEST_IDENTITY.expectedSourceId,
        noOverflow:
          document.documentElement.scrollWidth <= window.innerWidth
      };
    });

    expect(truth.panel).toEqual({
      id: "hink213-bw-250x122",
      logicalWidth: 250,
      logicalHeight: 122,
      ramWidth: 122,
      ramHeight: 250,
      stride: 16,
      planeCount: 1,
      payloadBytes: 4000,
      rotation: 3,
      bitOrder: "msb-first",
      whiteBit: 1
    });

    expect(truth.canvasWidth).toBe(250);
    expect(truth.canvasHeight).toBe(122);
    expect(truth.progressMax).toBe(4000);
    expect(truth.previewGeometry).toBe("250 × 122");
    expect(truth.ramGeometry).toBe("122 × 250");
    expect(truth.strideBytes).toBe("16 bytes");
    expect(truth.byteCount).toBe("4000");
    expect(truth.chunkCount).toBe("286");
    expect(truth.transferSummary).toContain("chunks=286");
    expect(truth.transferSummary).toContain("bytes=4000");
    expect(truth.packingSummary).toContain("250×122");
    expect(truth.packingSummary).toContain("122×250");
    expect(truth.packingSummary).toContain("ROTATE_3");
    expect(truth.black).toBe(6);

    const expected = legacyPack([
      [0, 0],
      [249, 0],
      [0, 121],
      [249, 121],
      [17, 9],
      [120, 61]
    ]);

    expect(truth.packed).toEqual([...expected]);

    expect(truth.start).toEqual([
      0xe5,
      0x00,
      0x24,
      0x7a,
      0x00,
      0xfa,
      0x00,
      0x01,
      0x10,
      0xa0,
      0x0f
    ]);

    expect(truth.runtime).toBe("D8A1");
    expect(truth.sourceId).toBe("D8A00001");
    expect(truth.noOverflow).toBe(true);

    await page.screenshot({
      path: path.join(proofDir, item.screenshot),
      fullPage: true
    });

    console.log(
      `[PASS] ${item.name}: descriptor preserves 250x122 / 4000-byte contract`
    );
  });
}