import { readFileSync } from 'node:fs';

const root = 'D:/EINK/Clock';
const custs = readFileSync(
  `${root}/firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c`,
  'utf8',
);
const periph = readFileSync(
  `${root}/firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c`,
  'utf8',
);

function assert(condition, message) {
  if (!condition) throw new Error(message);
}
function must(text, needle, label) {
  assert(text.includes(needle), `missing ${label}: ${needle}`);
}

must(custs, '#define HINK_RETAIN_META_ADDR        0x3B040UL', 'retained metadata address');
must(custs, '#define HINK_RETAIN_FRAME_ADDR       0x3B060UL', 'retained frame address');
must(custs, '#define HINK_RETAIN_FRAME_BYTES      HINK_E5_TOTAL_BYTES', '4000-byte frame contract');
must(custs, '#define HINK_RETAIN_MODE_IMAGE       1U', 'retained image mode');
must(custs, 'hink_retained_frame_crc16(fb_bw) == hink_u16_le(&retained_meta[8])', 'boot frame CRC validation');
must(custs, 'hink_retained_valid = 1U;', 'valid retained boot state');
must(custs, 'hink_retained_refresh_pending = 1U;', 'one-shot boot refresh state');
must(custs, '(void)hink_retained_store_image();', 'persist only after E6 display completion');
must(custs, 'Metadata is committed last so a power loss cannot validate a partial frame.', 'power-loss ordering');
must(custs, 'sf_erase(HINK_D3D_STORE_SECTOR, 0x1000, 1);', 'sector-bounded erase');
must(custs, 'hink_retained_valid = hink_retained_write_after_erase(fb_bw);', 'D3D erase preserves retained image');
must(custs, 'fb_rr aliases fb_bw on this B/W target.', 'framebuffer alias safety guard');
must(custs, 'fspi_exit();\n            return 0U;', 'busy D3D persistence skips destructive sector erase');
must(custs, 'void hink_retained_display_on_connect(void)', 'connect refresh entrypoint');
must(custs, 'hnd = app_easy_timer(1, hink_retained_refresh_timer_cb);', 'deferred first-connect refresh');
must(custs, 'hink_retained_refresh_pending = 0U;', 'one-shot refresh consume');
must(periph, 'if (!hink_image_mode_is_active())', 'no clock timer in retained image mode');
must(periph, 'hink_retained_display_on_connect();', 'connection hook');
must(periph, 'if (hink_image_mode_is_active())', 'disconnect image hold guard');

const meta = 0x3b040;
const frame = 0x3b060;
const bytes = 4000;
const sectorEndExclusive = 0x3c000;
assert(meta + 32 === frame, 'metadata/frame boundary mismatch');
assert(frame + bytes === sectorEndExclusive, 'retained frame must end exactly at 0x3BFFF');
assert(meta >= 0x3b000, 'retained metadata escaped approved sector');

assert(!custs.includes('0x3C000UL'), 'unapproved 0x3C000 sector must not be used as storage');
assert(!custs.includes('0x3D000UL'), 'unapproved 0x3D000 sector must not be used as storage');
assert(!custs.includes('0x3E000UL'), 'unapproved 0x3E000 sector must not be used as storage');
assert(!custs.includes('0x3F000UL'), 'unapproved 0x3F000 sector must not be used as storage');

console.log('EINK B/W retain-mode connect-refresh smoke PASS');
