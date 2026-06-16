---
name: exec-draft
description: Draft or revise a single docs-plan v2 child plan from a policy-locked parent. Use when Codex needs to create child acceptance rows, allowed/forbidden write sets, dependencies, and validation expectations before draft-review.
---

# Exec Draft

## Overview

Draft one child plan from a locked parent plan. Codex owns child plan drafting in docs-plan v2; Claude reviews intent later through `draft-review` + `draft-intent-worker`.

Read `../plan-protocol/references/plan-protocol.md` before writing.

## PLAN_ROOT Preflight

Before drafting or revising child plans, apply plan-protocol § 14.1. If
canonical `plan/` is absent, report that PLAN_ROOT bootstrap is
required. If `docs/plan`, `docs/check`, `docs/archive`,
`docs/roadmap`, or `docs/runbook` exists, stop and report the legacy
conflict. If only some canonical directories are missing and no legacy
conflict exists, create the missing directories idempotently. Never
overwrite existing files, migrate artifacts, or move artifacts without
explicit user approval.

## Workflow

1. Confirm parent `policy-locked`, Q2 pass, dependencies satisfied, and child concurrency clear.
2. Read the parent plan's source-of-truth, non-goals, child responsibility boundaries, closure map, and Child Handoff Board row.
3. Create or revise only the target child plan. Place it under `plan/families/`.
4. Include enough for executable work: responsibility, dependencies, acceptance rows, allowed/forbidden write set, validation expectations, manual verification entries if needed, and non-goals.
5. Preserve every parent-named production primitive as load-bearing per plan-protocol § 10a. If the parent names an SDK, MCP client, model/tool-call loop runtime, adapter, production builder or service composition path, runtime mode, migration, queue gateway, or external client boundary, the child must name the same primitive in its responsibility and acceptance/validation contract unless the parent explicitly allowed a substitute.
6. Limit fake/local test-double wording. It may cover external responses, network, model output, provider failure, clock, storage, or operator input, but it must not replace the named production primitive with a generic callback, fake runner, dependency string, constructor slot, or local-only adapter.
7. Do not lock implementation details such as exact helper function names, fixture bodies, patch order, or internal refactor sequence unless the parent explicitly requires them.
8. Do not add or alter parent decisions. If child acceptance/scope/source-of-truth must change, stop and route to Claude `plan-reconcile`.
9. Update the Child Handoff Board runtime columns if operating under `exec-run`.

## Status

When this skill creates a new child plan as part of `exec-run`, Codex appends `family_status: child_<id>_draft_started`. If invoked standalone, treat the invocation as the Codex runner for this transition and follow the same single-writer rule.
