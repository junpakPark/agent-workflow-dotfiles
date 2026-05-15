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
2. Run the plan-protocol § 13.2 Claude CLI capability preflight. Require `claude --help` to list `--json-schema` and `--output-format json`. If unsupported, stop as a runtime prerequisite blocker; do not retry and do not fall back to bare stdout.
3. Resolve the `plan_intent` schema path at `../plan-protocol/references/schemas/child-checkpoint.plan_intent.schema.json`, compact it with `schema_json="$(jq -c . "${schema_path}")"`, and invoke Claude `draft-intent-worker` with `claude -p --output-format json --json-schema "${schema_json}"`. The schema path is the source file only; do not pass the file path itself as the `--json-schema` value. Build the long worker prompt as a prompt file or wrapper-native argv value; do not embed it in a nested shell heredoc such as `zsh -lc '... <<EOF ...'`. Pass the prompt body as a single Claude prompt argument. The prompt names the installed worker path (`${HOME}/.claude/skills/draft-intent-worker/SKILL.md`) and supplies the parent/child paths and prior findings. When spawning the Claude CLI, preserve the runtime identity environment required by plan-protocol § 13.1 (`HOME`, `PATH`, `SHELL`, `USER`, `LOGNAME` when available; derive missing `USER`/`LOGNAME` at runtime, never hard-code them). If the initial invocation fails because a restricted runtime blocks Claude auth/session lookup, perform at most one user-approved elevated retry in an auth-capable runtime with the same `schema_json`, prompt body, command arguments, inputs, and environment. If the Claude CLI is unavailable, schema compaction fails, identity env is missing, or the retry fails, stop without creating a checkpoint and report the blocker.
4. Parse stdout as a Claude Code result wrapper, not as the checkpoint payload. Require `is_error = false`, `terminal_reason = "completed"`, and top-level `.structured_output` to exist as an object. Wrapper `result`, stderr, debug logs, and raw stdout are not checkpoint artifacts.
5. Validate only `.structured_output` as the checkpoint payload. It must validate against the `plan_intent` schema and satisfy plan-protocol § 7.1.d wrapper-side invariants: invocation identity fields match the request, recurrence nullability is coherent, recurrent `plan_intent` uses `recurrence_cause = contract`, `plan_intent` revise uses `revise_scope = child-plan`, `plan_intent` `governing_source` does not cite child sources, `governing_source` does not cite `code-quality-worker principle`, and the § 7.4 verdict / `next_action` / `revise_scope` matrix is satisfied.
5a. Hard-reject schema-coercion or contradiction signals in free-text fields, excluding only the verbatim quote and evidence field paths enumerated in plan-protocol § 7.1.d. Reject phrases include `cannot complete as requested`, `schema limitation`, `not in the schema`, and `forced by schema`.
5b. On wrapper parse failure, `is_error = true`, non-completed `terminal_reason`, missing/non-object `.structured_output`, schema-invalid `.structured_output`, or wrapper-side invariant violation, stop without archiving and escalate per plan-protocol § 7.1.c. These failures are not worker verdicts and are not same-input checkpoint retries.
5c. The wrapper MAY preserve the failed attempt as a debug-only artifact named `${current_check_root}/<child>/checkpoints/plan_intent.failed-1.txt`, including exit code, parsed wrapper JSON or raw stdout, stderr trailing lines, and validation failures after redacting secrets. The current structured-output contract has no same-input checkpoint retry, so at most one failed debug artifact is produced per checkpoint invocation. This file is never consumed as a checkpoint artifact.
6. Archive the validated `.structured_output` object, and only that object, to `${current_check_root}/<child>/checkpoints/plan_intent.json`.
7. Handle verdict:
   - `approve`: append `child_<id>_plan_locked`, update board, continue to `exec-tests` when under `exec-run`
   - `revise`: revise only the child plan, then repeat this checkpoint
   - `decision-needed`: stop; route to Claude `plan-reconcile`
   - `plan-defect`: stop; route to Claude `plan-reconcile`; only reconcile may write `child_<id>_plan_revision_required`
8. For `recheck_loop_signal = recurrence-2nd`, follow protocol recurrence routing. For `plan_intent`, the cause is contract and routes to Claude `plan-reconcile`.

## Boundaries

Do not call Codex review workers for this checkpoint. Do not edit parent plans except for protocol-allowed board/status updates performed by the Codex runner.
