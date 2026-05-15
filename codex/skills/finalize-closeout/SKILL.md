---
name: finalize-closeout
description: Close out a docs-plan v2 family after code-quality-ready. Use to check completion, root docs/operating policy/ADR/roadmap sync, produce archive-ready or follow-up-needed, and escalate policy decisions to Claude plan-reconcile.
---

# Finalize Closeout

## Overview

Close out a docs-plan v2 family after `code-quality-ready`. This is the documentation/finalization audit; it does not mean general feature documentation work beyond closeout/archive.

Read `../plan-protocol/references/plan-protocol.md` before entering.

## PLAN_ROOT Preflight

Before closeout reads or writes finalization artifacts, apply
plan-protocol § 14.1. If canonical `plan/` is absent, report that
PLAN_ROOT bootstrap is required. If `docs/plan`, `docs/check`,
`docs/archive`, `docs/roadmap`, or `docs/runbook` exists, stop and
report the legacy conflict. If only some canonical directories are
missing and no legacy conflict exists, create the missing directories
idempotently. Never overwrite existing files, migrate artifacts, or
move artifacts without explicit user approval.

## Workflow

1. Confirm latest family-level status is `code-quality-ready` and Q2 passes.
2. Check parent and child completion, quality result, remaining board items, and unresolved manual gates.
3. Check whether root docs, operating policy, ADRs, or roadmap handoff notes need synchronization.
4. Make only mechanical/current-contract doc sync that is clearly implied by completed work. If a policy, ADR, source-of-truth, or parent-scope decision is needed, stop and route to Claude `plan-reconcile`.
5. Return one result: `archive-ready` or `follow-up-needed`, with changed files and rationale.
6. Do not execute archive; hand off to `finalize-archive` after user approval.

## Boundaries

Do not reopen implementation intent. Do not run code-quality. Do not archive. Do not preserve obsolete root-doc contracts as history; local plan/archive/rationale areas hold history.
