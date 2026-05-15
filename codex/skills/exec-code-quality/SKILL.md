---
name: exec-code-quality
description: Run the docs-plan v2 code-quality gate after all children complete and the user explicitly requests it. Calls code-quality-worker, writes ## Code-quality result, creates refactor children when needed, and appends code-quality-ready/refactor-needed/code-quality-blocked.
---

# Exec Code Quality

## Overview

Run the family-level code-quality gate after all children are implemented and the user explicitly asks for code-quality. This skill owns result triage and family-level quality markers; `code-quality-worker` remains the separate findings engine.

Read `../plan-protocol/references/plan-protocol.md` before entering. Read `../code-quality-worker/SKILL.md` and `../code-quality-worker/references/code-quality.md` before reviewing.

## PLAN_ROOT Preflight

Before reading family state or writing code-quality artifacts, apply
plan-protocol § 14.1. If canonical `plan/` is absent, report that
PLAN_ROOT bootstrap is required. If `docs/plan`, `docs/check`,
`docs/archive`, `docs/roadmap`, or `docs/runbook` exists, stop and
report the legacy conflict. If only some canonical directories are
missing and no legacy conflict exists, create the missing directories
idempotently. Never overwrite existing files, migrate artifacts, or
move artifacts without explicit user approval.

## Workflow

1. Confirm every active child has `child_<id>_implement_completed`; Q2 must pass.
2. Build an explicit change surface: code/test files changed by the family, excluding unrelated dirty files.
3. Invoke `code-quality-worker` on that surface. The worker emits only F-NNN quality findings.
4. Save the raw worker output under `${current_check_root}` as a code-quality artifact.
5. Triage findings yourself into a `## Code-quality result` section on the parent plan:
   - `code-quality-ready`: all findings rejected or non-blocking with no refactor needed
   - `refactor-needed`: one or more accepted quality findings, no decision-needed/plan-blocker, refactor child or children created
   - `code-quality-blocked`: decision-needed, closure violation, or plan-blocker found
6. Append exactly one family-level marker matching the result: `code-quality-ready`, `refactor-needed`, or `code-quality-blocked`.
7. If blocked, route to Claude `plan-reconcile`. If refactor is needed, create refactor child plans with `origin: code-quality` and exact F-NNN mapping.

## Boundaries

- This is quality-only. Do not emit or accept intent/acceptance/source-of-truth findings as code quality.
- Refactor child review-skip is allowed only when all four protocol conditions hold.
- Do not enter closeout/archive automatically.
