# TASK D3D SPI Safe Sector Proof

## Scope

- Workspace: `D:\EINK\Clock`
- Audit only: no firmware, web, packer, build, flash, or SPI writes.
- Final packed image audited: `D:\EINK\Clock\_incoming\TASK_D3C_FINAL_PACKED_256KB.bin`
- Packed size: `262144` bytes (`0x40000`)
- Packed SHA256: `648123BE0CC83291D9CD0DC6E5B8D3B2AD68373698954BA7F6C189C1260F44F1`

## Flash Geometry And APIs

Evidence from active source and packer:

- Flash image size: `0x40000` bytes.
- Packer full image layout: `7050@0x00000`, `7051@0x04000`, payload at `0x04040`, product header at `0x38000`.
- Keil target IROM size is `0x40000`.
- Flash write API: `sf_page_write(addr, buf, size)`.
- Flash read API: `sf_read(addr, len, buf)`.
- Flash erase API: `sf_erase(addr, size, wait)`.
- Erase granularity used by source: `0x1000` 4 KiB sectors and `0x8000` 32 KiB blocks.
- Page writes are 256-byte oriented in existing OTA paths.

## Reserved Regions

Observed final packed image regions:

- `0x00000`: boot header begins with `70 50`.
- `0x04000`: active image header begins with `70 51 AA 01`.
- `0x04040..0x13ABF`: active image payload, size `0xFA80` / `64128` bytes.
- `0x1F000`: inactive image slot start from product table, currently erased.
- `0x38000`: product/image table begins with `70 52 12 34`.
- `0x39000`: screen pin configuration.
- `0x3A000`: panel profile / resolution information.

Product table values at `0x38000`:

- signature word: `0x34125270`
- image0 start: `0x00004000`
- image1 start: `0x0001F000`

Image slot audit:

- image0 header: `0x04000`
- image0 payload: `0x04040..0x13ABF`
- image1 header: `0x1F000`
- image1 is erased in the final packed image.
- With the packer raw limit `0x10000`, an inactive image written at `0x1F000` would consume at most header + payload through approximately `0x2F03F`, still below `0x38000`.

## Candidate Sector

Chosen sector:

- start: `0x3B000`
- end: `0x3BFFF`
- size: `0x1000` / `4096` bytes

Packed image evidence:

- Sector `0x3B000..0x3BFFF` is entirely `0xFF`.
- First 32 bytes at `0x3B000`:
  `FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF`

Safety proof:

- It does not overlap boot header at `0x00000`.
- It does not overlap active image header/payload at `0x04000..0x13ABF`.
- It does not overlap inactive image slot at `0x1F000` or the worst-case inactive image range ending below `0x30000`.
- It does not overlap product/image table at `0x38000`.
- It does not overlap screen pin config at `0x39000`.
- It does not overlap panel profile at `0x3A000`.
- It is inside the valid 256 KiB flash image range ending at `0x3FFFF`.
- It is 4 KiB aligned.
- A 4 KiB erase at `0x3B000` affects only `0x3B000..0x3BFFF`; it does not erase neighboring config sectors.

Decision:

- `0x3B000..0x3BFFF` is approved for D3D last-known-time persistence.
- D3D implementation must use only this sector unless a new proof updates this document.

## Journal Fit

The D3D-1 proposed record is about 24 bytes:

- magic: `uint32`
- version: `uint8`
- flags: `uint8`
- length: `uint8`
- reserved: `uint8`
- sequence: `uint32`
- epoch_utc: `uint32`
- timezone_minutes: `int16`
- d2_flags: `uint8`
- validity_state: `uint8`
- crc16: `uint16`

An A/B journal with two records fits easily:

- 2 records x 32-byte aligned slot = 64 bytes
- 64 bytes is far below the 4096-byte sector size.

Recommended slot offsets:

- slot A: `0x3B000`
- slot B: `0x3B020`

The remaining sector bytes stay erased/reserved for future journal expansion.

## D3D-2 Allowed Storage Contract

D3D-2 may implement SPI persistence only under these rules:

- Use sector `0x3B000..0x3BFFF`.
- Use `sf_read`, `sf_page_write`, and `sf_erase`.
- Erase only `0x3B000..0x3BFFF`.
- Never erase the full chip.
- Never write `0x38000`, `0x39000`, `0x3A000`, boot headers, or image slots.
- Write only on successful `D2 00 SET_TIME`.
- Do not write every minute, every render, every disconnect, or every five-minute boundary.
- Cold boot must treat the record as last-known metadata only.
- Cold boot must not mark D2 time RUNNING from persisted data.
- Cold boot must not start the D3B/D3C scheduler from persisted data.
- A fresh `D2 00 SET_TIME` always overrides RAM and persisted state.

## Rejected Alternatives

- `0x38000`: rejected because it is the product/image table.
- `0x39000`: rejected because it is screen pin configuration.
- `0x3A000`: rejected because it is panel profile/resolution configuration.
- Any address below `0x30000`: rejected because it may overlap active or inactive image storage.
- Any unverified sector: rejected until proven against the final packed image and product table.

## D3D-2 Exact Scope

Allowed files for implementation:

- `firmware/active/HINK213_CLOCK_22_BASE/src/user_custs1_impl.c`
- `scripts/task-d3d-last-known-time-record-smoke.mjs`
- `firmware/active/HINK213_CLOCK_22_BASE/src/user_peripheral.c` only if a startup/init hook is truly required

Expected behavior:

- Encode/decode the A/B last-known-time record.
- Read both slots at boot/init.
- Validate magic/version/range/CRC.
- Ignore empty or corrupt records safely.
- Write inactive slot only after valid SET_TIME.
- Persisted record remains stale metadata until fresh SET_TIME.
- No scheduler start from persisted metadata.
