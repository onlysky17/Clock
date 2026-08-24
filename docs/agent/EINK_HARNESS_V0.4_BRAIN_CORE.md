# EINK Harness v0.4 — Brain Core Contract

## Scope

Brain Core v0.4 introduces persistent Owner task memory for EINK / Clock.

The Owner can enter a natural-language task request in Harness Control Center.
Harness stores the task locally, exposes recent task history, survives Control
Center restarts, and can resume a previously stored task.

## Persistence

Production storage is fixed to:

`_incoming/EINK_HARNESS_BRAIN/`

Files:

- `current-task.json` — authoritative current Brain task.
- `history.jsonl` — append-only CREATE / RESUME event history.

The history file is never rewritten by normal Brain actions.

## v0.4 allowed behavior

Brain may:

- accept natural-language Owner intent;
- create a persistent task ID;
- persist current task state;
- append task events to history;
- restore state after Harness restart;
- resume an existing task from history;
- read Git branch / HEAD for context only.

## v0.4 forbidden behavior

Brain v0.4 MUST NOT:

- edit firmware;
- edit repository source files;
- stage, commit, push or merge Git changes;
- run firmware build or pack;
- run SPI backup, erase, write or burn;
- bypass Control Center write-token authorization;
- bypass project action allow-list;
- write outside its approved local persistence root.

Execution is intentionally disabled in v0.4.

## API

EINK project actions:

- `brain-create`
- `brain-resume`

Both are non-destructive actions but still require the existing
`X-Eink-Control-Token` write authorization and project action allow-list.

## Acceptance

Acceptance must prove:

1. missing write token is blocked;
2. UTF-8 natural-language task intake succeeds;
3. two tasks are persisted;
4. current task survives a server restart;
5. an older task can be resumed;
6. resume appends history rather than rewriting it;
7. production Brain storage is unchanged by isolated acceptance;
8. Git HEAD and workspace state are unchanged by Brain actions;
9. no firmware/build/burn operation is executed.