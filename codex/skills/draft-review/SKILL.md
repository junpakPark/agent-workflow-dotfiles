---
name: draft-review
description: Codex wrapper for Claude draft-intent-worker. Use after exec-draft to review a child plan against parent intent, policy, source-of-truth, non-goals, and scope, archive the child-checkpoint JSON, and handle approve/revise/decision-needed/plan-defect verdicts.
---

# Draft Review

## Overview

Run the Codex wrapper around Claude `draft-intent-worker`. This is the execution-stage child plan intent gate. Codex does not self-approve child plan intent.

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

1. Gather parent path, child path, child id, git head, prior checkpoint JSON if any, and file hashes required by `child-checkpoint.v1`.
2. Invoke Claude `draft-intent-worker` with a prompt that names the installed worker path (`${HOME}/.claude/skills/draft-intent-worker/SKILL.md`) and supplies the parent/child paths and prior findings. When spawning the Claude CLI, preserve the runtime identity environment required by plan-protocol § 13.1 (`HOME`, `PATH`, `SHELL`, `USER`, `LOGNAME` when available; derive missing `USER`/`LOGNAME` at runtime, never hard-code them). If the initial invocation fails because a restricted runtime blocks Claude auth/session lookup, perform at most one user-approved elevated retry in an auth-capable runtime with the same command, inputs, and environment. If the Claude CLI is unavailable, fails due to missing identity env, fails the retry, or returns non-JSON, stop without creating a checkpoint and report the blocker.
3. Require stdout to be valid `child-checkpoint.v1` JSON with `checkpoint = plan_intent` and an `intent_map` ledger.
4. Archive the JSON to `${current_check_root}/<child>/checkpoints/plan_intent.json`.
5. Handle verdict:
   - `approve`: append `child_<id>_plan_locked`, update board, continue to `exec-tests` when under `exec-run`
   - `revise`: revise only the child plan, then repeat this checkpoint
   - `decision-needed`: stop; route to Claude `plan-reconcile`
   - `plan-defect`: stop; route to Claude `plan-reconcile`; only reconcile may write `child_<id>_plan_revision_required`
6. For `recheck_loop_signal = recurrence-2nd`, follow protocol recurrence routing. For `plan_intent`, the cause is contract and routes to Claude `plan-reconcile`.

## Boundaries

Do not call Codex review workers for this checkpoint. Do not edit parent plans except for protocol-allowed board/status updates performed by the Codex runner.
