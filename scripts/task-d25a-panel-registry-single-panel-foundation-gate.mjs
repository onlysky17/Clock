import fs from "node:fs";
import path from "node:path";

const repoRoot = path.resolve(
  path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")),
  ".."
);

const sourcePath = path.join(
  repoRoot,
  "web",
  "clock-app",
  "hl24a-canvas-e5.html"
);

const source = fs.readFileSync(sourcePath, "utf8");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function count(fragment) {
  return source.split(fragment).length - 1;
}

assert(
  source.includes("const DEFAULT_PANEL_ID='hink213-bw-250x122';"),
  "Missing explicit default panel ID"
);

assert(
  source.includes("const PANEL_REGISTRY=Object.freeze({"),
  "Missing immutable panel registry"
);

assert(
  source.includes("[DEFAULT_PANEL_ID]:Object.freeze({"),
  "Registry descriptor is not immutable"
);

assert(
  source.includes(
    "const ACTIVE_PANEL=PANEL_REGISTRY[DEFAULT_PANEL_ID];"
  ),
  "ACTIVE_PANEL is not resolved from the registry"
);

assert(
  source.includes("window.EINK_PANEL_REGISTRY=PANEL_REGISTRY;"),
  "Panel registry is not exposed for deterministic runtime inspection"
);

assert(
  source.includes("window.EINK_DEFAULT_PANEL_ID=DEFAULT_PANEL_ID;"),
  "Default panel ID is not exposed"
);

assert(
  source.includes("window.EINK_ACTIVE_PANEL=ACTIVE_PANEL;"),
  "Existing active panel runtime export was not preserved"
);

assert(
  !source.includes("const ACTIVE_PANEL=Object.freeze({"),
  "Legacy singleton descriptor declaration remains"
);

const invariants = [
  "id:'hink213-bw-250x122'",
  "logicalWidth:250",
  "logicalHeight:122",
  "ramWidth:122",
  "ramHeight:250",
  "stride:16",
  "planeCount:1",
  "payloadBytes:4000",
  "rotation:3",
  "bitOrder:'msb-first'",
  "whiteBit:1"
];

for (const invariant of invariants) {
  assert(
    source.includes(invariant),
    `Missing HINK213 invariant: ${invariant}`
  );
}

assert(
  count("id:'hink213-bw-250x122'") === 1,
  "Expected exactly one HINK213 descriptor"
);

assert(
  source.includes("const WIDTH=ACTIVE_PANEL.logicalWidth;"),
  "WIDTH no longer derives from ACTIVE_PANEL"
);

assert(
  source.includes("const HEIGHT=ACTIVE_PANEL.logicalHeight;"),
  "HEIGHT no longer derives from ACTIVE_PANEL"
);

assert(
  source.includes("const RAM_WIDTH=ACTIVE_PANEL.ramWidth;"),
  "RAM_WIDTH no longer derives from ACTIVE_PANEL"
);

assert(
  source.includes("const RAM_HEIGHT=ACTIVE_PANEL.ramHeight;"),
  "RAM_HEIGHT no longer derives from ACTIVE_PANEL"
);

assert(
  source.includes("const STRIDE=ACTIVE_PANEL.stride;"),
  "STRIDE no longer derives from ACTIVE_PANEL"
);

assert(
  source.includes("const TOTAL=ACTIVE_PANEL.payloadBytes;"),
  "TOTAL no longer derives from ACTIVE_PANEL"
);

console.log("PASS: D25A panel registry single-panel foundation");
console.log("DEFAULT_PANEL_ID: hink213-bw-250x122");
console.log("REGISTRY_ENTRIES: 1");
console.log("PAYLOAD_BYTES: 4000");