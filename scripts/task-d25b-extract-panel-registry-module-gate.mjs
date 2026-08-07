import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const root=path.resolve(
  path.dirname(
    new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,"$1")
  ),
  ".."
);

const html=fs.readFileSync(
  path.join(root,"web","clock-app","hl24a-canvas-e5.html"),
  "utf8"
);

const registrySource=fs.readFileSync(
  path.join(root,"web","clock-app","panel-registry.js"),
  "utf8"
);

function assert(value,message){
  if(!value) throw new Error(message);
}

assert(
  html.includes('<script src="panel-registry.js"></script>'),
  "Registry module is not loaded"
);

assert(
  !html.includes("const PANEL_REGISTRY=Object.freeze({"),
  "Registry remains inline"
);

const sandbox={window:{}};
vm.createContext(sandbox);
vm.runInContext(registrySource,sandbox);

const registry=sandbox.window.EINK_PANEL_REGISTRY;
const defaultId=sandbox.window.EINK_DEFAULT_PANEL_ID;
const panel=sandbox.window.EINK_ACTIVE_PANEL;

assert(defaultId==="hink213-bw-250x122","Wrong default panel");
assert(Object.keys(registry).length===1,"Expected one panel");
assert(Object.isFrozen(registry),"Registry not frozen");
assert(Object.isFrozen(panel),"Descriptor not frozen");
assert(registry[defaultId]===panel,"Active panel mismatch");

const expected={
  id:"hink213-bw-250x122",
  logicalWidth:250,
  logicalHeight:122,
  ramWidth:122,
  ramHeight:250,
  stride:16,
  planeCount:1,
  payloadBytes:4000,
  rotation:3,
  bitOrder:"msb-first",
  whiteBit:1
};

for(const [key,value] of Object.entries(expected)){
  assert(panel[key]===value,`Wrong ${key}`);
}

console.log("PASS: D25B extracted panel registry module");
console.log("DEFAULT_PANEL_ID: "+defaultId);
console.log("REGISTRY_ENTRIES: "+Object.keys(registry).length);
console.log("PAYLOAD_BYTES: "+panel.payloadBytes);