# HL25A ONE-SHOT PANEL LIVENESS

## Goal

Prove whether the white-screen HINK213 2.13-inch panel can execute one real
refresh.

HL25A does not enable arbitrary framebuffer display. It only writes one fixed
border/checker pattern and then locks itself.

## Safety sequence

1. Open a valid E4 session.
2. Arm with ASCII `HL25`.
3. Arm expires after 10 seconds.
4. Fire with the returned arm ID plus `A5 5A`.
5. Firmware clears the arm and latches USED before panel access.
6. Only one fire is allowed per cold boot.
7. A second attempt requires a full power cycle.

All legacy refresh-capable E2 commands remain blocked by HL20A.

## Protocol

Arm:

```text
E6 00 48 4C 32 35
```

Expected:

```text
E6 80 00 armId state 0A
```

Fire:

```text
E6 01 armId A5 5A
```

Expected sequence:

```text
E6 81 00 armId state 0A
E2 25 10
E2 25 02
```

Query:

```text
E6 03
```

State bits:

- bit 0: ARMED
- bit 1: USED this cold boot
- bit 2: panel job BUSY

## Fixed pattern

- full 128 x 296 frame,
- solid outer border,
- large checker blocks,
- one refresh only.

If black/white polarity is inverted, the panel is still considered alive when
the geometric pattern is clearly visible.

## Source hashes

Base:

`0C4EA0DD9931FB9FC4D9B6EE12C2203E481A5DEB1E2A31FEB8404040252FFC84`

HL25A candidate:

`5AC693AA560AC1ED0A594B00CB459FBE5C3247FD624EA6DFC965773C38DA08CB`

## Validation

1. Apply and sync source.
2. Keil Rebuild: require 0 errors.
3. Commit source/web/docs; never commit `.bin`.
4. Pack and flash only the white-screen board.
5. Open the stable `test.html` page.
6. Run safe preflight.
7. Open E4 session.
8. Confirm the board checkbox.
9. Arm and fire before the 10-second timeout.
10. Require `E2 25 10`, then `E2 25 02`.
11. Visually inspect the physical panel.
12. Confirm a second arm returns status `03` until power cycle.
