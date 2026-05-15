---
name: exec-tests
description: Write tests and manual verification entries for a locked docs-plan v2 child. Use after a child plan is locked and before implementation to translate acceptance rows into executable checks, without changing production code.
---

# Exec Tests

## Overview

Write the tests and manual verification entries for one locked child. In docs-plan v2, approved tests plus manual verification are the executable contract for implementation.

Read `../plan-protocol/references/plan-protocol.md` before entering.

## PLAN_ROOT Preflight

Before writing tests or manual verification artifacts, apply
plan-protocol § 14.1. If canonical `plan/` is absent, report that
PLAN_ROOT bootstrap is required. If `docs/plan`, `docs/check`,
`docs/archive`, `docs/roadmap`, or `docs/runbook` exists, stop and
report the legacy conflict. If only some canonical directories are
missing and no legacy conflict exists, create the missing directories
idempotently. Never overwrite existing files, migrate artifacts, or
move artifacts without explicit user approval.

## Workflow

1. Confirm Q1 (`child_<id>_plan_locked` after latest draft/revision) and Q2 pass.
2. Append `family_status: child_<id>_tests_started` when entering through `exec-run`.
3. Read every child acceptance row and map each row to at least one verification anchor: unit test, integration test, manual verification, manual scenario, or hybrid.
4. Modify only test/verification artifacts. Do not implement production behavior in this stage.
5. Keep test names feature-centric; do not put internal docs-plan IDs on collaborator-facing surfaces.
6. For manual-only verification, write a concrete owner/procedure/expected/tooling entry that `test-review` can evaluate.
7. Run the relevant tests when safe and not expensive. Do not run expensive project-specific runtime commands unless the user explicitly requested it.
8. Hand off to `test-review`. `child_<id>_tests_written` is appended only after `test-review` returns `approve`.

## Stop Conditions

Stop if a new acceptance row, changed source-of-truth, or scope expansion is needed. That is a child contract issue for Claude `plan-reconcile`, not a tests-only rewrite.
