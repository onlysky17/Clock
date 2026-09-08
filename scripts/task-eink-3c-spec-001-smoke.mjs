import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const root=path.resolve(
  path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,"$1")),
  ".."
);

const registryPath=path.join(root,"web","clock-app","panel-registry.js");
const htmlPath=path.join(root,"web","clock-app","hl24a-canvas-e5.html");
const registrySource=fs.readFileSync(registryPath,"utf8");
const htmlSource=fs.readFileSync(htmlPath,"utf8");

function assert(value,message){
  if(!value)throw new Error(message);
}

const sandbox={
  window:{},
  document:{
    readyState:'loading',
    createElement:()=>({dataset:{}}),
    head:{append(){}},
    querySelector:()=>null,
    addEventListener(){}
  }
};
vm.createContext(sandbox);
vm.runInContext(registrySource,sandbox);

const registry=sandbox.window.EINK_PANEL_REGISTRY;
const defaultId=sandbox.window.EINK_DEFAULT_PANEL_ID;
const active=sandbox.window.EINK_ACTIVE_PANEL;
const bw=registry["hink213-bw-250x122"];
const bwr=registry["hink213-bwr-250x122"];

assert(defaultId==="hink213-bw-250x122","B/W default panel changed");
assert(active===bw,"Active panel is no longer the B/W panel");
assert(bw.planeCount===1&&bw.payloadBytes===4000,"B/W payload contract changed");
assert(bwr?.model==="HINK-E0213A67","HINK-E0213A67 descriptor missing");
assert(bwr.logicalWidth===250&&bwr.logicalHeight===122,"B/W/R logical geometry changed");
assert(bwr.ramWidth===122&&bwr.ramHeight===250,"B/W/R controller RAM geometry changed");
assert(bwr.stride===16,"B/W/R stride must remain 16 bytes");
assert(bwr.planeCount===2,"B/W/R must expose two planes");
assert(bwr.planeBytes===4000&&bwr.payloadBytes===8000,"B/W/R plane/payload sizes are not explicit");
assert(bwr.packing==="plane-major","B/W/R packing order is not explicit");
assert(JSON.stringify([...bwr.planeOrder])===JSON.stringify(["black","red"]),"B/W/R plane order must be black then red");
assert(bwr.planes.black.command===0x24,"Black plane command must be 0x24");
assert(bwr.planes.black.zero==="black"&&bwr.planes.black.one==="white","Black plane polarity changed");
assert(bwr.planes.red.command===0x26,"Red plane command must be 0x26");
assert(bwr.planes.red.zero==="not-red"&&bwr.planes.red.one==="red","Red plane polarity must be explicit");
assert(bwr.firmware.driverMode==="EPD_BWR","Firmware B/W/R driver mode missing");
assert(bwr.firmware.redPlaneOwner==="firmware","Red plane ownership must remain firmware-owned");
assert(bwr.firmware.framebufferOwnership==="separate-black-red","Separate red framebuffer ownership is required");
assert(bwr.firmware.nextImplementationTask==="EINK-3C-FW-001","Next firmware task is not explicit");
assert(bwr.rotation===3&&bwr.bitOrder==="msb-first"&&bwr.whiteBit===1,"B/W/R mapping contract changed");

for(const fragment of [
  "const PANEL_RUNTIME_CONTRACT=Object.freeze({",
  "planeCount:ACTIVE_PANEL.planeCount",
  "const TOTAL=PACKER_CONTRACT.payloadBytes;",
  "function packCanvas(contract=PACKER_CONTRACT){",
  "function startPacket(id,contract=PACKER_CONTRACT){"
]){
  assert(htmlSource.includes(fragment),`Missing active B/W contract boundary: ${fragment}`);
}

console.log("PASS: EINK-3C-SPEC-001 panel contract");
console.log("PANEL: HINK-E0213A67");
console.log("GEOMETRY: logical 250x122 / RAM 122x250 / stride 16");
console.log("PLANES: black + red / plane-major / 4000 bytes each / 8000 total");
console.log("RED: firmware-owned / command 0x26 / 1=red, 0=not-red");
console.log("NEXT_FIRMWARE_TASK: EINK-3C-FW-001");
