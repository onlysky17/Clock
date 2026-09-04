# EINK Clock Agent Rules

## Canonical Workspace

- Workspace canonical: `D:\EINK\Clock`
- Canonical source: `D:\EINK\Clock\firmware\active\HINK213_CLOCK_22_BASE`
- SDK: `D:\EINK\DA14585_SDK_6.0.22.1401`
- SDK project: `D:\EINK\DA14585_SDK_6.0.22.1401\projects\target_apps\ble_examples\HINK213_CLOCK_22_BASE`
- Canonical web duy nhat: `https://onlysky17.github.io/Clock/test.html`

## Hardware And Web Gates

- PC khong co BLE; Web Bluetooth test bang dien thoai.
- Khong duoc tu Burn SPI, flash, reset board, hoac ket luan hardware PASS.
- Khong claim PASS neu khong co command output hoac Owner evidence.
- Hardware test, flash, Burn SPI, reset board, and physical display verification must stop for Owner action.

## Change Discipline

- Khong commit BIN/build output.
- Khong dung `git add .`.
- Moi task uu tien 3-5 file va toi da mot validation nang.
- Khong sua smoke lich su tru khi test that su fail vi code hien tai.
- Khong doc lai toan bo `MEMORY.md` hoac docs dai; chi doc `docs/agent/CURRENT_STATE.md`, `docs/agent/NEXT_ACTION.md`, va tai lieu truc tiep lien quan.

## Git Lifecycle

Required flow:

1. Workspace gate.
2. Branch.
3. Implement.
4. Validate.
5. Owner review.
6. Commit.
7. Push.
8. PR.
9. Owner merge.
10. Sync main.
11. Closeout.

## Failure Playbook Gate

- Before agent execution, load `docs/agent/ASSISTANT_FAILURE_PLAYBOOK.md`.
- Treat the playbook as mandatory execution context, not optional documentation.
- Diagnose failures before mutation: implementation failure, stale acceptance, or test-environment failure.
- Do not silently mutate the playbook. New prevention rules require an explicit reviewed change.

## Owner-Facing Execution Guardrails

These rules are repository governance and must survive chat/account/model/agent changes. Conversational memory is not sufficient enforcement.

- Before repository mutation, verify canonical workspace/project identity, Git root, branch, HEAD, working-tree status, and task identity. On mismatch, stop with exactly `SAI PROJECT/WORKSPACE`.
- A user question is not an instruction to change roadmap, implementation, or task order. Change direction only on explicit Owner instruction.
- Before each hardware step, state its class first: `🟢 KHÔNG CẦN BOARD`, `🟡 CẦN BOARD` for non-destructive device work, or `🔴 CẦN BOARD + CÓ GHI/XÓA` for firmware/SPI mutation. Red-class work requires explicit Owner authorization.
- Do not claim physical, visual, burn, merge, or local-sync PASS without the matching command output, GitHub state, or explicit Owner evidence.
- Never auto-merge. Owner keeps the final merge gate.
- Whenever a PR is created, or a PR is the Owner's next action, the same response MUST include the direct clickable PR URL. A PR number without its clickable link is incomplete.
- After Owner reports a merge, verify the PR is merged and record the exact merge commit before continuing. Do not claim the Owner's local checkout is synced until local `main == origin/main` is explicitly verified.
- Before retrying a hardware write after an error, inspect actual phase evidence first. Do not repeat a write/erase merely because a wrapper or parser reported failure.
- Record each material state transition as `YYYY-MM-DD HH:mm — PROJECT — TASK — STATE — NEXT`.
