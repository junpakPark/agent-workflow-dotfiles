---
name: exec-impl
description: Implement one docs-plan v2 child after tests/manual verification are approved. Use when the child tests-written marker is present to make code pass the executable contract, run scoped validation, perform over-satisfies self-check, append implement_completed, and stop.
---

# Exec Impl

## Overview

Implement one child against the approved executable contract. There is no Claude `plan-impl-review`; the approved tests/manual verification are the contract.

Read `../plan-protocol/references/plan-protocol.md` before entering.

## PLAN_ROOT Preflight

Before implementation reads or writes plan state, apply plan-protocol
§ 14.1. If canonical `plan/` is absent, report that PLAN_ROOT
bootstrap is required. If `docs/plan`, `docs/check`, `docs/archive`,
`docs/roadmap`, or `docs/runbook` exists, stop and report the legacy
conflict. If only some canonical directories are missing and no legacy
conflict exists, create the missing directories idempotently. Never
overwrite existing files, migrate artifacts, or move artifacts without
explicit user approval.

## Workflow

1. Confirm `child_<id>_tests_written` or an explicit `tests: skip` contract, Q2 pass, and no unsafe dirty diff.
2. Append `family_status: child_<id>_implement_started` when entering through `exec-run`.
3. Implement only what is needed to satisfy approved tests/manual verification and the child allowed write set.
4. Do not add, remove, or rewrite approved tests/manual verification during implementation. If they are wrong, stop and route back through `test-review`.
5. Run the relevant tests/checks. Do not run expensive project-specific runtime commands unless explicitly requested by the user.
6. Perform the `over-satisfies` self-check: compare changed files and behavior against the child implementation contract and allowed/forbidden write set.
7. If unrelated/scope-widening changes are safe to narrow back, remove them and continue without a marker. If narrow-back is unsafe because of user-owned dirty diff, regression risk, or needed approval, stop and append `child_<id>_blocked`.
8. If the scope itself is wrong or a new acceptance/source-of-truth decision is needed, stop and route to Claude `plan-reconcile`; do not write `_plan_revision_required` yourself.
9. On success, append `family_status: child_<id>_implement_completed`, update board, report changed files, validation, and stop.

## Hard Stops

Stop for parent intent/policy/source-of-truth conflict, scope expansion, manual/external gate, destructive cleanup, runtime prerequisite gap, unexpected user-owned dirty diff, or any expensive operator command requirement.
