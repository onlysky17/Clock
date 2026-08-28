# EINK Assistant Failure Playbook

Purpose: prevent repeated agent, assistant, command, Git, PowerShell, and test-environment mistakes.

This file is mandatory execution context for EINK Harness agents.

## Governance

- Apply these rules before mutating source.
- Do not silently add, remove, or rewrite failure rules.
- New failure patterns require an explicit reviewed task / commit / PR.
- A green test is not enough if the test environment or assertion is invalid.
- Diagnose root cause before changing implementation or acceptance code.

## Failure Patterns

### PS-FINALLY-EXIT

Failure:
PowerShell parser error: `Flow of control cannot leave a Finally block.`

Root cause:
Using `return`, `break`, or `continue` to leave a `finally` block.

Prevention:
Never use flow-control exits from `finally`.

Detection:
Parser-check PowerShell before asking Owner to run it.

---

### CONFLICT-STAGED-BEFORE-CLEAN

Failure:
A conflicted file was staged while `<<<<<<<`, `=======`, or `>>>>>>>` markers still existed.

Root cause:
Treating `git add` as proof that conflict content was resolved.

Prevention:
Before staging a resolved conflict, scan for conflict markers.

Detection:
Run conflict-marker scan, then `git diff --check`.

---

### DETACHED-HEAD-ACCEPTANCE

Failure:
Acceptance failed because it assumed a named branch while the test worktree was detached HEAD.

Root cause:
Test-environment assumptions were mistaken for implementation regressions.

Prevention:
Check `git branch --show-current` before branch-sensitive acceptance.

Detection:
Classify failure as implementation, stale acceptance, or environment before mutation.

---

### WORKTREE-REGISTRY-MISMATCH

Failure:
Control Center acceptance server refused startup with registry workspace mismatch.

Root cause:
A test worktree used `projects.json` whose EINK workspace still pointed to the canonical production repo.

Prevention:
Verify registry workspace before starting server acceptance in a worktree.

Detection:
Compare registry EINK workspace with the repository root used by the server.

---

### STALE-ACCEPTANCE

Failure:
Behavior remained valid but an old assertion no longer matched the equivalent implementation shape.

Root cause:
Testing syntax shape instead of required behavior.

Prevention:
Read the failing assertion and implementation together before changing either.

Detection:
Distinguish implementation failure, stale assertion, and environment failure.

---

### TEMP-FIXTURE-RESTORE

Failure:
Temporary test configuration can leak into source or production state.

Root cause:
Fixture mutation without exact restoration verification.

Prevention:
Backup original bytes, mutate only the isolated fixture, restore in `finally`.

Detection:
Verify restored SHA256 equals original SHA256.

---

### POWERSHELL-COMMAND-QUALITY

Failure:
Owner receives unnecessarily long or syntactically unsafe PowerShell blocks.

Root cause:
Too much mutation and validation combined before proving the previous step.

Prevention:
Prefer short targeted blocks. After a command error, simplify the next step.

Detection:
Parser-check scripts and avoid complex control flow when a smaller command is sufficient.

---

### WINPS-CHILD-EXITCODE

Failure:
Windows PowerShell returned null/unreliable `Process.ExitCode` after child completion.

Root cause:
Host-specific `System.Diagnostics.Process` behavior.

Prevention:
Use the Harness child exit-code transport file as authoritative.

Detection:
Require explicit integer child exit-code evidence.

---

### DIAGNOSE-BEFORE-MUTATE

Failure:
Code or tests are changed before the actual failure class is known.

Root cause:
Trying to make a red test green before identifying root cause.

Prevention:
Use read-only diagnostics first.

Detection:
Before mutation, state which class applies:
`IMPLEMENTATION_FAIL`, `STALE_ACCEPTANCE`, or `TEST_ENVIRONMENT_FAIL`.