---
name: test-review
description: Codex wrapper for Claude test-intent-worker. Use after exec-tests to verify tests/manual verification against child acceptance rows, archive the child-checkpoint JSON, and handle approve/revise/decision-needed/plan-defect verdicts.
---

# Test Review

## Overview

Run the Codex wrapper around Claude `test-intent-worker`. This checkpoint verifies that tests and manual verification faithfully translate child acceptance rows into an executable contract.

Read `../plan-protocol/references/plan-protocol.md` before handling a verdict.

## PLAN_ROOT Preflight

Before archiving checkpoint JSON or writing status/board updates, apply
plan-protocol § 14.1. If canonical `plan/` is absent, report that
PLAN_ROOT bootstrap is required. If `docs/plan`, `docs/check`,
`docs/archive`, `docs/roadmap`, or `docs/runbook` exists, stop and
report the legacy conflict. If only some canonical directories are
missing and no legacy conflict exists, create the missing directories
idempotently. Never overwrite existing files, migrate artifacts, or
move artifacts without explicit user approval.

## Workflow

1. Gather child path, parent path if needed, test diff/anchors, manual verification entries, git head, prior checkpoint JSON if any, and file hashes required by `child-checkpoint.v1`.
2. Invoke Claude `test-intent-worker` with a prompt that names the installed worker path (`${HOME}/.claude/skills/test-intent-worker/SKILL.md`) and supplies the child path, test anchors, manual entries, and prior findings. If the Claude CLI is unavailable or returns non-JSON, stop and report the blocker.
3. Require stdout to be valid `child-checkpoint.v1` JSON with `checkpoint = test_intent` and an `acceptance_map` ledger.
4. Archive the JSON to `${current_check_root}/<child>/checkpoints/test_intent.json`.
5. Handle verdict:
   - `approve`: append `child_<id>_tests_written`, update board, continue to `exec-impl` when under `exec-run`
   - `revise` + `tests-only`: rewrite tests only, then repeat this checkpoint
   - `revise` + `manual-verification-only`: rewrite manual verification only, then repeat this checkpoint
   - `decision-needed`: stop; route to Claude `plan-reconcile`
   - `plan-defect`: stop; route to Claude `plan-reconcile`; only reconcile may write `child_<id>_plan_revision_required`
6. If `recheck_loop_signal = recurrence-2nd` with `tests-only` or `manual-only`, stop on the board and escalate to the user without writing a `## Status` marker. If cause is `contract`, route to Claude `plan-reconcile`.

## Boundaries

Do not perform implementation review. There is no `plan-impl-review` in v2. Do not approve tests by Codex self-review alone.
