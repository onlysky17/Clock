# EINK Harness v0.5.1 - Contract Visualizer

## Scope

v0.5.1 changes presentation only.

It does not change:

- Brain persistence
- Task Compiler classification
- Task Contract schema
- execution policy
- firmware
- build
- burn
- Git policy

## Visualizer

The current compiled Task Contract is projected into:

- colored task-class / risk / state pills;
- required-capability chips;
- Owner-gate chips;
- forbidden-action chips;
- candidate-scope chips;
- explicit execution / exact-file / auto-merge safety badges;
- syntax-highlighted raw JSON.

Raw JSON remains available for exact inspection.

## Safety

Visualizer values are rendered with DOM textContent.

Raw JSON is syntax-highlighted only after HTML-sensitive
characters &, < and > are escaped.

No external UI or syntax-highlighting dependency is added.

Owner visual review remains required before publication.