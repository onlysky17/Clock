import fs from "node:fs";
import path from "node:path";

const root=path.resolve(
  path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,"$1")),
  ".."
);
const firmwareRoot=path.join(root,"firmware","active","HINK213_CLOCK_22_BASE","src");
const read=(relative)=>fs.readFileSync(path.join(firmwareRoot,relative),"utf8");
const header=read(path.join("epd","epd.h"));
const gui=read(path.join("epd","epd_gui.c"));
const driver=read(path.join("epd","epd.c"));
const flash=read(path.join("epd","spi_flash.c"));
const app=read("user_peripheral.c");
const e5=read("user_custs1_impl.c");

function assert(value,message){
  if(!value)throw new Error(message);
}

assert(header.includes("#ifndef EPD_PANEL_BWR")&&header.includes("#define EPD_PANEL_BWR     0"),"B/W default target must remain compile-time disabled");
assert(header.includes("#define EPD_PANEL_PLANE_COUNT (EPD_PANEL_BWR ? 2 : 1)"),"Plane count is not target-driven");
assert(header.includes("#if EPD_PANEL_BWR")&&header.includes("extern u8 fb_rr[EPD_PLANE_BYTES];")&&header.includes("#define fb_rr fb_bw"),"B/W/R red ownership is not independent from the B/W alias");
assert(gui.includes("u8 fb_bw[EPD_FRAME_BYTES];")&&gui.includes("u8 fb_rr[EPD_PLANE_BYTES];"),"Expected independent black/red framebuffer storage missing");
assert(gui.includes("if(color==RED)")&&gui.includes("fb_rr[byte_pos] |= bit_mask;")&&gui.includes("fb_rr[byte_pos] &= (uint8_t)~bit_mask;"),"Red-plane draw ownership is incomplete");
const blackWrite=driver.indexOf("epd_cmd(0x24)");
const redWrite=driver.indexOf("epd_cmd(0x26)");
assert(blackWrite>=0&&redWrite>blackWrite,"Dual-plane write order must be black 0x24 then red 0x26");
assert(driver.includes("int detect_mode = EPD_PANEL_BWR ? EPD_BWR : EPD_BW;"),"EPD detect mode is not target-driven");
assert(flash.includes("detect_mode = EPD_PANEL_BWR ? EPD_BWR : EPD_BW;"),"SPI-loaded panel mode is not target-driven");
assert(app.includes("#if EPD_PANEL_BWR")&&app.includes("0x23111000, 0x07210120")&&app.includes("0x23200700, 0x05210006"),"B/W/R GPIO selection is not isolated from the B/W fallback");
assert(e5.includes("#define HINK_E5_TOTAL_BYTES    EPD_FRAME_BYTES")&&e5.includes("#define HINK_E5_STAGING_BUFFER fb_bw"),"Existing B/W E5 contract changed");
assert(!e5.includes("EPD_PANEL_PLANE_COUNT"),"E5/Web 2-plane transfer was expanded out of scope");

console.log("PASS: EINK-3C-FW-001 dual-plane ownership smoke");
console.log("B/W: EPD_PANEL_BWR=0 / one 4000-byte plane / E5 unchanged");
console.log("B/W/R: compile-time target / independent 4000-byte black + red planes");
console.log("WRITE: 0x24 black then 0x26 red");
console.log("RED: 1=red, 0=not-red / firmware-owned");
console.log("WEB 8000-BYTE TRANSFER: OUT OF SCOPE");
