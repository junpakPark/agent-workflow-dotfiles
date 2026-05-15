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
2. Run the plan-protocol § 13.2 Claude CLI capability preflight. Require `claude --help` to list `--json-schema` and `--output-format json`. If unsupported, stop as a runtime prerequisite blocker; do not retry and do not fall back to bare stdout.
3. Resolve the `test_intent` schema path at `../plan-protocol/references/schemas/child-checkpoint.test_intent.schema.json`, compact it with `schema_json="$(jq -c . "${schema_path}")"`, and invoke Claude `test-intent-worker` with `claude -p --output-format json --json-schema "${schema_json}"`. The schema path is the source file only; do not pass the file path itself as the `--json-schema` value. Build the long worker prompt as a prompt file or wrapper-native argv value; do not embed it in a nested shell heredoc such as `zsh -lc '... <<EOF ...'`. Pass the prompt body as a single Claude prompt argument. The prompt names the installed worker path (`${HOME}/.claude/skills/test-intent-worker/SKILL.md`) and supplies the child path, test anchors, manual entries, and prior findings. When spawning the Claude CLI, preserve the runtime identity environment required by plan-protocol § 13.1 (`HOME`, `PATH`, `SHELL`, `USER`, `LOGNAME` when available; derive missing `USER`/`LOGNAME` at runtime, never hard-code them). If the initial invocation fails because a restricted runtime blocks Claude auth/session lookup, perform at most one user-approved elevated retry in an auth-capable runtime with the same `schema_json`, prompt body, command arguments, inputs, and environment. If the Claude CLI is unavailable, schema compaction fails, identity env is missing, or the retry fails, stop without creating a checkpoint and report the blocker.
4. Parse stdout as a Claude Code result wrapper, not as the checkpoint payload. Require `is_error = false`, `terminal_reason = "completed"`, and top-level `.structured_output` to exist as an object. Wrapper `result`, stderr, debug logs, and raw stdout are not checkpoint artifacts.
5. Validate only `.structured_output` as the checkpoint payload. It must validate against the `test_intent` schema and satisfy plan-protocol § 7.1.d wrapper-side invariants: invocation identity fields match the request, recurrence nullability is coherent, `test_intent` revise uses only `tests-only` or `manual-verification-only`, `governing_source` does not cite `code-quality-worker principle`, and the § 7.4 verdict / `next_action` / `revise_scope` matrix is satisfied.
5a. Hard-reject schema-coercion or contradiction signals in free-text fields, excluding only the verbatim quote and evidence field paths enumerated in plan-protocol § 7.1.d. Reject phrases include `cannot complete as requested`, `schema limitation`, `not in the schema`, and `forced by schema`.
5b. On wrapper parse failure, `is_error = true`, non-completed `terminal_reason`, missing/non-object `.structured_output`, schema-invalid `.structured_output`, or wrapper-side invariant violation, stop without archiving and escalate per plan-protocol § 7.1.c. These failures are not worker verdicts and are not same-input checkpoint retries.
5c. The wrapper MAY preserve the failed attempt as a debug-only artifact named `${current_check_root}/<child>/checkpoints/test_intent.failed-1.txt`, including exit code, parsed wrapper JSON or raw stdout, stderr trailing lines, and validation failures after redacting secrets. The current structured-output contract has no same-input checkpoint retry, so at most one failed debug artifact is produced per checkpoint invocation. This file is never consumed as a checkpoint artifact.
6. Archive the validated `.structured_output` object, and only that object, to `${current_check_root}/<child>/checkpoints/test_intent.json`.
7. Handle verdict:
   - `approve`: append `child_<id>_tests_written`, update board, continue to `exec-impl` when under `exec-run`
   - `revise` + `tests-only`: rewrite tests only, then repeat this checkpoint
   - `revise` + `manual-verification-only`: rewrite manual verification only, then repeat this checkpoint
   - `decision-needed`: stop; route to Claude `plan-reconcile`
   - `plan-defect`: stop; route to Claude `plan-reconcile`; only reconcile may write `child_<id>_plan_revision_required`
8. If `recheck_loop_signal = recurrence-2nd` with `tests-only` or `manual-only`, stop on the board and escalate to the user without writing a `## Status` marker. If cause is `contract`, route to Claude `plan-reconcile`.

## Boundaries

Do not perform implementation review. There is no `plan-impl-review` in v2. Do not approve tests by Codex self-review alone.
