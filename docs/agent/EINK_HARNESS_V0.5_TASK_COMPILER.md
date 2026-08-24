# EINK Harness v0.5 — Brain Task Compiler

## Goal

Brain v0.5 turns an Owner natural-language task into a durable typed Task
Contract before any agent execution is allowed.

This version is intentionally PLAN_ONLY. It does not edit code, build firmware,
burn hardware, stage Git changes, commit, push, or merge.

## Durable event

Compiling a task appends a `COMPILE` record to the existing append-only Brain
history. The current task snapshot carries the same compiled contract so the UI
can project it immediately and restore it after restart.

The compiler event is a durable fact. Resume preserves an existing contract.

## Task Contract schema

`eink-task-contract-v1` contains:

- task class;
- risk level;
- required capability seams;
- candidate file scopes;
- exact allowed files placeholder;
- forbidden actions;
- Owner gates;
- acceptance criteria;
- execution policy;
- source branch / HEAD;
- contract SHA256.

Candidate file scopes are NOT authorization. `allowedFiles` remains empty and
`exactFilesRequiredBeforeExecution` remains true until a future execution
planner resolves and validates an exact task scope.

## Compiler policy

v0.5 uses `DETERMINISTIC_HEURISTIC_V1`.

The compiler folds Unicode text for classification so Vietnamese Owner input
can be classified without embedding locale-sensitive source-code literals.

Task classes:

- HARNESS
- FIRMWARE
- DOCS
- HARDWARE
- GENERAL

GENERAL remains blocked pending classification review.

## Safety invariants

The compiler cannot:

- execute repository edits;
- call build or pack;
- call hardware burn;
- bypass the write token;
- bypass the project action allow-list;
- authorize `git add .` or `git add -A`;
- auto-merge;
- commit BIN artifacts;
- replace exact-file review with broad candidate scopes.

Hardware intent always carries Owner burn and physical gates.

## Architectural direction

v0.5 begins separating task intent from capabilities and execution. Later
versions can consume the typed contract through capability providers while
keeping the event stream as durable history.

No external harness runtime is introduced as a dependency.