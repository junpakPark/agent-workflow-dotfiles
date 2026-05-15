---
name: plan-run
description: Planning-stage router for docs-plan v2. Reads the parent plan's `## Status` and selects the next planning action — `plan-intake`, `plan-draft`, `plan-review`, or `plan-reconcile`. Stops at the parent-lock gate (`policy-locked`) so the family can hand off to Codex `exec-run`. Does not route execution or finalization — those are owned by Codex `exec-run` and `finalize-run`.
---

# plan-run

## Purpose

Pick exactly one planning-stage action for a docs-plan v2 family.
Stops at confirmation gates rather than trying to finish the whole
planning lifecycle in one pass. Hands off to Codex `exec-run` after
`policy-locked`.

In docs-plan v2 the lifecycle is split across three routers:
- `plan-run` — planning (Claude). This skill.
- `exec-run` — execution (Codex).
- `finalize-run` — finalization (Codex).

`plan-run` is read-only for `## Status` and `## Child Handoff Board`.
It consumes entries to choose the next worker, but never appends or
edits.

## Read First

- The parent plan's `## Status` and `## Closure map`.
- [plan-protocol reference](../plan-protocol/references/plan-protocol.md)
  for the family_status vocabulary, Q2 query rule, and parent-lock
  gate conditions.

## PLAN_ROOT Preflight

Before routing a planning stage, apply plan-protocol § 14.1. If
canonical `plan/` is absent, report that PLAN_ROOT bootstrap is
required. If `docs/plan`, `docs/check`, `docs/archive`,
`docs/roadmap`, or `docs/runbook` exists, stop and report the legacy
conflict. If only some canonical directories are missing and no legacy
conflict exists, create the missing directories idempotently. Never
overwrite existing files, migrate artifacts, or move artifacts without
explicit user approval.

## Routing Decision

Pick the next action based on the latest family-level `## Status`
entry and the parent plan's content:

| Latest family-level entry | Next action |
|---|---|
| (none — no parent plan yet, or `## Status` empty after a fresh draft) | `/plan-intake` if intake summary is not yet confirmed in this turn-thread; otherwise `/plan-draft` |
| `parent_review_converged` | `/plan-reconcile` (close out the converged review) |
| `policy-locked` | hand off to Codex `exec-run` for the first child; this skill stops |
| `decision-blocked` | wait — only Claude `plan-reconcile` can release this via `decision-resolved` after user response + `D-NNN`. If reconcile has not yet routed, route to `/plan-reconcile`. |
| `decision-resolved` | re-evaluate `## Status` excluding the resolved decision; usually `/plan-reconcile` to consolidate or `policy-locked` is appended in the same reconcile pass |
| `code-quality-ready` / `refactor-needed` / `code-quality-blocked` | not planning's territory in v2; `finalize-run` (Codex) consumes these. `plan-run` stops. |

Child-transition entries (`child_<id>_*`) do **not** appear in the
family-level table above. They are excluded from the Q2 family-level
latest determination per plan-protocol § 3.2. Route them via the
Child-transition Routing table below instead.

### Child-transition Routing

When the most recent `## Status` entry overall is a child-transition
marker, `plan-run` ignores it for family-level Q2 and applies the
table below for child-specific recovery routing. Q2 itself still
reads only the family-level namespace.

| Child-transition marker | Next action |
|---|---|
| `child_<id>_plan_revision_required` | `/plan-reconcile` has already processed the reason. The next move is for Codex `exec-run` to re-enter child draft for that child. `plan-run` stops and reports the recovery hand-off to the user. |
| any other child-transition entry (`_draft_started`, `_plan_locked`, `_tests_started`, `_tests_written`, `_implement_started`, `_implement_completed`, `_blocked`, `_frozen`) | not planning's territory; Codex `exec-run` consumes these. `plan-run` stops. |

Plan review and reconcile cycles iterate: a new `/plan-review`
artifact lands → `/plan-reconcile` triages → if material change
occurred, `/plan-reconcile` triggers a re-review per protocol § 10
material-change rules. `plan-run` reads the latest state and routes
accordingly each turn.

## Stop Gates

- After `/plan-intake`, stop. The user must explicitly confirm intake
  in a separate turn before `/plan-draft`.
- After `/plan-draft`, stop. The next stage is `/plan-review`.
- After `/plan-review`, stop. The next stage is `/plan-reconcile`.
- After `/plan-reconcile` writes `policy-locked`, hand off to Codex
  `exec-run`. `plan-run` does not invoke `exec-run` directly — that is
  a Codex command surface. Report the hand-off to the user.
- After `decision-blocked` is raised, wait. Do not attempt to bypass
  by re-running review or rewriting plan body.
- Never write to `## Status` or `## Child Handoff Board`.
- Never invoke `exec-*` or `finalize-*` skills from this router.

## Delegation Preflight

When invoking a worker skill (`plan-intake`, `plan-draft`,
`plan-review`, `plan-reconcile`), this router cites the active
branching line as **file path + line number + verbatim one-liner**
in chat before the invocation, per plan-protocol § 13.

If a worker skill's contract conflicts with the protocol body (e.g.,
the worker emits a closed-set marker not in protocol § 2), stop and
report contract drift. Do not work around by substituting another
worker.

## Cross-References

- [plan-protocol § 2](../plan-protocol/references/plan-protocol.md) — vocabulary the router reads
- [plan-protocol § 3](../plan-protocol/references/plan-protocol.md) — Q1 / Q2 query rules
- [plan-protocol § 4](../plan-protocol/references/plan-protocol.md) — gates the router respects
- `plan-intake` / `plan-draft` / `plan-review` / `plan-reconcile` — the four planning skills this router dispatches to
- Codex `exec-run` — successor router after `policy-locked`

## Removed Legacy Path

The old lifecycle bridge was removed after Phase 2 cleanup. New work routes through `plan-run` + Codex `exec-run` + Codex `finalize-run`. Do not mix v1 lifecycle routing with v2 routing on the same family.
