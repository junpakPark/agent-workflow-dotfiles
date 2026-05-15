---
name: plan-intake
description: Clarify a user request — intent, scope, non-goals, success criteria, source-of-truth candidates — at parent-plan level, before any docs-plan v2 family is drafted or extended. Use as the first stage for every "build / change / fix X" request. Hand off to `/plan-draft` only after explicit user confirmation.
---

# plan-intake

## Purpose

Produce a parent-level intake summary that the user explicitly confirms
before any plan file is written. Intake is parent-level only: it
agrees on what the family will accomplish, what is out of scope, what
"done" looks like, and which document(s) own the source of truth.

In docs-plan v2 this skill is the planning-stage entry point owned by
Claude. It precedes `/plan-draft` (parent draft), `/plan-review`
(parent Full Panel review), and `/plan-reconcile` (closure lock).

## Read First

- `AGENTS.md`, `README.md`, `DEVELOPER_GUIDE.md`, `ARCHITECTURE.md` for
  current contract.
- `docs/adr/*` only when a structural decision is implicated.
- The shared protocol contract:
  [plan-protocol reference](../plan-protocol/references/plan-protocol.md)
  — for the family_status vocabulary, Q1/Q2, parent-lock gate, single-
  writer rule, and `## Child Handoff Board` contract that the
  subsequent stages will enforce.

## PLAN_ROOT Preflight

Before intake hands off to any plan-writing stage, apply
plan-protocol § 14.1. If canonical `plan/` is absent, report that
PLAN_ROOT bootstrap is required. If `docs/plan`, `docs/check`,
`docs/archive`, `docs/roadmap`, or `docs/runbook` exists, stop and
report the legacy conflict. If only some canonical directories are
missing and no legacy conflict exists, they may be created
idempotently. Never overwrite existing files, migrate artifacts, or
move artifacts without explicit user approval.

## Output Shape

Produce a 5-section intake summary in chat (no file writes in intake):

1. **Goal** — what is being built / changed / fixed, in user-facing
   terms.
2. **Scope** — which surface (code module, doc area, operator flow,
   workflow skill, etc.).
3. **Non-goals** — explicit boundaries; what this family will not do.
4. **Success criteria** — observable signals that "done" has occurred
   (operator outcome, test outcome, doc presence, etc.).
5. **Source-of-truth candidates** — which document or contract will
   carry the locked decisions for this family. Per the parent draft
   depth rule, source-of-truth candidates fall into a 4-value enum:
   `docs/operating-policy.md` (operator contract / runtime policy), `docs/adr/<file>.md`
   (architecture decision), `parent invariant + acceptance test`
   (implementation contract), `parent closure-only` (local sequencing
   / runbook decision).

Stop after the summary is in chat. The user must confirm explicitly
before the assistant proceeds to `/plan-draft`. Sourcing complexity or
trivial scope does not waive the confirmation.

## Stop Gate

- Intake never writes a plan file.
- Intake never enters `/plan-draft` in the same turn it produces the
  summary, even if the user seems to be in a hurry.
- After the user confirms, `/plan-draft` runs in a subsequent turn.

## Routing

- `/plan-draft` — runs after explicit user confirmation; writes the
  parent plan (parent-only — child plans are Codex's `exec-draft`
  territory in v2, not `plan-draft`).
- `/plan-protocol` (reference) — cited by all downstream stages.

## Removed Legacy Path

The old `docs-plan-*` bridge was removed after Phase 2 cleanup. New work must use this v2 skill surface. Do not mix v1 lifecycle routing with v2 `plan-*`, `exec-*`, or `finalize-*` routing.

## Cross-References

- [plan-protocol § 2](../plan-protocol/references/plan-protocol.md) — family_status vocabulary (used downstream)
- [plan-protocol § 4.1](../plan-protocol/references/plan-protocol.md) — parent-lock gate (the goal of the planning stage)
- `plan-draft` — next stage after user confirms intake
