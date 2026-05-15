---
name: exec-run
description: Codex execution-stage router for docs-plan v2. Use when the user asks to run or resume a locked parent plan, advance the next actionable child, recover child state from ## Status/Child Handoff Board, or execute one child through draft/test/implementation gates. Stops after one child or any protocol stop condition.
---

# Exec Run

## Overview

Run the execution stage for one docs-plan v2 child. This skill is the Codex execution router: it reads a locked parent plan, restores child state from `## Status` plus `## Child Handoff Board`, advances exactly one actionable child, then stops.

Read `../plan-protocol/references/plan-protocol.md` before routing.

## PLAN_ROOT Preflight

Before routing execution, apply plan-protocol § 14.1. If canonical
`plan/` is absent, report that PLAN_ROOT bootstrap is required. If
`docs/plan`, `docs/check`, `docs/archive`, `docs/roadmap`, or
`docs/runbook` exists, stop and report the legacy conflict. If only
some canonical directories are missing and no legacy conflict exists,
create the missing directories idempotently. Never overwrite existing
files, migrate artifacts, or move artifacts without explicit user
approval.

## Inputs

- Parent plan number or absolute parent plan path.
- Optional target child id. If absent, choose the first actionable child allowed by dependencies and protocol gates.

## Workflow

1. Resolve the parent plan path. Use `plan/families/`. Prefer an explicit absolute path when provided.
2. Read `## Status`, `## Closure map`, and `## Child Handoff Board`.
3. Run protocol checks: parent has `policy-locked`, Q2 passes, no other child is in progress, and the board is not ahead of `## Status`.
4. Reconcile board drift only when `## Status` is ahead. If the board is ahead of `## Status`, stop and report a closure-violation candidate.
5. Pick exactly one child. Do not start a second child in the same invocation.
6. Run the next missing stage for that child:
   - no child plan: use `exec-draft`, then append `child_<id>_draft_started`
   - child draft exists but not locked: use `draft-review`; on approve append `child_<id>_plan_locked`
   - plan locked but tests not written: append `child_<id>_tests_started`, use `exec-tests`, then `test-review`; on approve append `child_<id>_tests_written`
   - tests written but implementation incomplete: append `child_<id>_implement_started`, use `exec-impl`; on success append `child_<id>_implement_completed`
7. Stop immediately on any protocol stop condition: `decision-needed`, `plan-defect`, `recurrence-2nd` escalation, unsafe narrow-back, source-of-truth conflict, scope expansion, expensive/runtime command need, destructive action, external/manual gate, unexpected user-owned dirty diff, or runtime prerequisite gap.
8. Stop after `child_<id>_implement_completed` and report the result. Do not enter the next child, `exec-code-quality`, closeout, or archive without a separate explicit request.

## Status Writes

Use only protocol-allowed Codex writer entries. Append, never edit, prior `## Status` rows. Do not write `decision-blocked`, `decision-resolved`, `policy-locked`, `child_<id>_plan_revision_required`, or `child_<id>_frozen`; those are Claude `plan-reconcile` territory.

## Command Safety

Never run an expensive project-specific operator/runtime command unless the user explicitly requests it for this turn.
