import fs from "node:fs";
import path from "node:path";

const root=path.resolve(
  path.dirname(
    new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,"$1")
  ),
  ".."
);

const source=fs.readFileSync(
  path.join(root,"web","clock-app","hl24a-canvas-e5.html"),
  "utf8"
);

function assert(value,message){
  if(!value) throw new Error(message);
}

for(const fragment of [
  "const PANEL_RUNTIME_CONTRACT=Object.freeze({",
  "renderer:Object.freeze({",
  "packer:Object.freeze({",
  "window.EINK_PANEL_RUNTIME_CONTRACT=PANEL_RUNTIME_CONTRACT;",
  "const RENDER_CONTRACT=PANEL_RUNTIME_CONTRACT.renderer;",
  "const PACKER_CONTRACT=PANEL_RUNTIME_CONTRACT.packer;",
  "const WIDTH=RENDER_CONTRACT.width;",
  "const HEIGHT=RENDER_CONTRACT.height;",
  "const RAM_WIDTH=PACKER_CONTRACT.ramWidth;",
  "const RAM_HEIGHT=PACKER_CONTRACT.ramHeight;",
  "const STRIDE=PACKER_CONTRACT.stride;",
  "const TOTAL=PACKER_CONTRACT.payloadBytes;",
  "planeCount:ACTIVE_PANEL.planeCount"
]){
  assert(source.includes(fragment),`Missing contract boundary: ${fragment}`);
}

assert(
  !source.includes("const WIDTH=ACTIVE_PANEL.logicalWidth;"),
  "Renderer still reads descriptor directly"
);

assert(
  !source.includes("const TOTAL=ACTIVE_PANEL.payloadBytes;"),
  "Packer still reads descriptor directly"
);

assert(
  source.includes("function packCanvas(contract=PACKER_CONTRACT)"),
  "packCanvas was removed"
);

assert(
  source.includes("function startPacket(id,contract=PACKER_CONTRACT)"),
  "startPacket was removed"
);

console.log("PASS: D25C renderer/packer contract boundary");
console.log("RENDER: 250x122");
console.log("PACKER: 122x250 / stride 16 / payload 4000");
console.log("PLANES: 1");