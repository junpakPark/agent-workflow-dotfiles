---
name: finalize-run
description: Codex finalization router for docs-plan v2. Use after code-quality-ready to choose finalize-closeout or finalize-archive, enforce approval gates, and stop on policy/ADR/parent-scope decisions.
---

# Finalize Run

## Overview

Route the finalization stage after code quality is ready. Codex owns closeout and archive preparation/execution in docs-plan v2.

Read `../plan-protocol/references/plan-protocol.md` before routing.

## PLAN_ROOT Preflight

Before routing finalization, apply plan-protocol § 14.1. If canonical
`plan/` is absent, report that PLAN_ROOT bootstrap is required. If
`docs/plan`, `docs/check`, `docs/archive`, `docs/roadmap`, or
`docs/runbook` exists, stop and report the legacy conflict. If only
some canonical directories are missing and no legacy conflict exists,
create the missing directories idempotently. Never overwrite existing
files, migrate artifacts, or move artifacts without explicit user
approval.

## Workflow

1. Read the parent plan `## Status` and run Q2.
2. Enter finalization only when the latest family-level marker is `code-quality-ready`.
3. If closeout has not been completed for the current family state, use `finalize-closeout`.
4. If closeout returned `archive-ready`, use `finalize-archive` only after explicit user approval.
5. Stop for policy/ADR/parent-scope decisions and route those to Claude `plan-reconcile`.

## Boundaries

Do not run code-quality, child execution, or archive automatically from a planning-stage command. Do not archive without explicit user approval.
