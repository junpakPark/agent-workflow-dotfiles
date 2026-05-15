---
name: exec-run
description: Codex execution-stage router for docs-plan v2. Use when the user asks to run or resume a locked parent plan, advance the next actionable child, recover child state from ## Status/Child Handoff Board, or execute one child through draft/test/implementation gates. Runs the selected child through available stages, then stops after that child or a stop condition.
---

# Exec Run

## Overview

Run the execution stage for one docs-plan v2 child. This skill is the Codex execution router: it reads a locked parent plan, restores child state from `## Status` plus `## Child Handoff Board`, advances exactly one actionable child through available missing stages, then stops.

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
6. Run missing stages in sequence for that child until a stop condition is reached. Do not stop merely because one transition marker was appended:
   - no child plan: use `exec-draft`, then append `child_<id>_draft_started`, then run `draft-review`
   - `draft-review` approve: append `child_<id>_plan_locked`, then run `exec-tests`
   - after `exec-tests`: run `test-review`; on approve append `child_<id>_tests_written`, then run `exec-impl`
   - `exec-impl` success: append `child_<id>_implement_completed`
7. Stop only for these cases: protocol stop condition; checkpoint verdict is not approve; Claude worker unavailable, non-JSON, or invalid `child-checkpoint.v1`; unsafe narrow-back; source-of-truth conflict; scope expansion; expensive/runtime command need; destructive action approval; external/manual gate; unexpected user-owned dirty diff; runtime prerequisite gap; or `child_<id>_implement_completed` reached.
8. When stopping after `child_<id>_implement_completed`, report the result. Do not start a second child, enter `exec-code-quality`, enter `finalize-closeout`, or enter `finalize-archive` without a separate explicit request.

## Status Writes

Use only protocol-allowed Codex writer entries. Append, never edit, prior `## Status` rows. Do not write `decision-blocked`, `decision-resolved`, `policy-locked`, `child_<id>_plan_revision_required`, or `child_<id>_frozen`; those are Claude `plan-reconcile` territory.

## Command Safety

Never run an expensive project-specific operator/runtime command unless the user explicitly requests it for this turn.
