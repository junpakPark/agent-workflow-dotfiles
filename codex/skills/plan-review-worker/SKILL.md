---
name: plan-review-worker
description: Given a single local plan document under `plan/families`, emit per-lens findings for CTO/problem-definition, implementer, operator, QA, maintainer, docs usability, and risk/rollout in strict F-NNN + severity format. Do not edit the plan, do not triage, do not write artifacts, and do not decide workflow status.
---

# Plan Review Worker

## Overview

Review one specified local plan document as an external worker. The plan document is under `plan/families/`. Produce raw findings only. The caller owns artifact storage, evidence validation, triage, routing, scope/severity selection, closure-map context derivation, and edits.

Read [references/review.md](references/review.md) before reviewing — in particular the § Focus text structured prefix. The literal marker is `<<<plan-review>>>`.

## PLAN_ROOT Preflight

This worker is read-only, but it still reports PLAN_ROOT problems if
they are visible in the supplied context. Canonical plan documents must
live under `plan/families/`. If canonical `plan/` is absent, report
that PLAN_ROOT bootstrap is required. If `docs/plan`, `docs/check`,
`docs/archive`, `docs/roadmap`, or `docs/runbook` exists, report the
legacy conflict. The caller owns any idempotent directory creation and
must never overwrite, migrate, or move artifacts without explicit user
approval.

## Workflow

1. Read the specified plan document and any caller-provided context.
2. Detect the caller's structured prefix by substring search for `<<<plan-review>>>` inside the companion-wrapped focus prompt.
3. Parse and honor `review_scope`, `review_severity`, `delta_scope`, `closure_map_path`, and `recovery_mode` exactly as defined in `references/review.md`.
4. If the prefix is absent, fall back to legacy free-form prose processing without deciding active-vs-bootstrap territory.
5. If a structured prefix is present and `closure_map_path` is parseable, read only the parent plan's `## Closure map` section for context.
6. Review through the applicable lenses in `references/review.md` and emit strict F-NNN findings.
7. Preserve one finding per lens observation. Do not merge repeated observations across lenses.
8. If a lens does not apply, include that lens section with `_N/A - <reason>`.

## Boundaries

- Do not edit files.
- Do not write `plan/check/*` artifacts.
- Do not classify findings as resolved or unresolved.
- Do not choose the current or next workflow state.
- Do not decide whether a reconcile requires review.
- Do not determine material-change status.
- Do not choose or override caller-provided `review_scope` or `review_severity` directives.
- Do not compute `delta_scope`; only honor caller-provided scope.
- Do not decide active-vs-bootstrap territory; the caller-side preflight gate owns territory.
- Do not perform `recovery_mode` routing; the caller-side reconcile owns it.
- Do not treat a closure map as an answer key that suppresses findings outside the closed decision.
- Do not ask the user questions; report missing input as a finding or `_N/A` where appropriate.
- Do not include remediation patches.
