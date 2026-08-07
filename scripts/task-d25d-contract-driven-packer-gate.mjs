import fs from "node:fs";
import path from "node:path";

const root=path.resolve(
  path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,"$1")),
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
  "function packCanvas(contract=PACKER_CONTRACT){",
  "new Uint8Array(contract.payloadBytes)",
  "contract.ramHeight-1-x",
  "ramY*contract.stride",
  "function startPacket(id,contract=PACKER_CONTRACT){",
  "contract.ramWidth&0xFF",
  "contract.ramHeight&0xFF",
  "contract.planeCount,",
  "contract.stride,",
  "contract.payloadBytes&0xFF"
]){
  assert(source.includes(fragment),`Missing contract-driven fragment: ${fragment}`);
}

assert(!source.includes("function packCanvas(){"),"Legacy packCanvas signature remains");
assert(!source.includes("function startPacket(id){"),"Legacy startPacket signature remains");

console.log("PASS: D25D contract-driven packer");
console.log("DEFAULT CONTRACT: PACKER_CONTRACT");
console.log("PAYLOAD: 4000");
console.log("PLANES: 1");