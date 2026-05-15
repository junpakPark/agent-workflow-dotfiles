---
name: plan-protocol
description: Shared cross-orchestrator contract for the docs-plan v2 workflow split between Claude (planning) and Codex (execution + finalization). Use when a planning or execution skill needs to cite the canonical `family_status` vocabulary, Q1/Q2 query rules, parent-lock / child-plan-locked gates, decision-blocked guard, child concurrency rule, `## Status` invariants, `## Child Handoff Board` contract, `child-checkpoint.v1` JSON envelope, recurrence routing, refactor-child review-skip rule, cross-orchestrator escalation rules, or PLAN_ROOT / `current_check_root` variable. The wrapper carries Claude-environment phrasing; the byte-identical contract body lives in `references/plan-protocol.md`.
---

# Plan Protocol — Claude-side Wrapper

## Overview

This skill is a Claude-side wrapper for the shared docs-plan v2
contract. The contract body lives in
[references/plan-protocol.md](references/plan-protocol.md) and is the
byte-identical sync target between this Claude-side copy and the
Codex-side counterpart. Wrapper `SKILL.md` files in each ecosystem may
differ; the reference file may not.

Other Claude skills (`plan-run`, `plan-intake`, `plan-draft`,
`plan-review`, `plan-reconcile`, `draft-intent-worker`,
`test-intent-worker`) cite this protocol rather than redefine its
rules.

## When to Read This Skill

- Before writing or updating a `family_status` entry in `## Status` —
  to confirm the writer is permitted by the single-writer table
  ([references/plan-protocol.md § 2](references/plan-protocol.md)).
- Before evaluating Q1 / Q2 — to apply the legacy `_ready` read-path
  equivalence and the `_plan_revision_required` invalidation rule
  ([§ 3](references/plan-protocol.md)).
- Before admitting a child draft, tests, or implementation — to check
  parent-lock / child-plan-locked / decision-blocked gates ([§ 4](references/plan-protocol.md)).
- Before producing a `child-checkpoint.v1` JSON verdict — to confirm
  the envelope shape, ledger key, `revise_scope`, and `governing_source`
  rules ([§ 7](references/plan-protocol.md)).
- Before treating an `over-satisfies` finding as a `_blocked` cause —
  to apply the safe/unsafe/scope-wrong branches ([§ 10](references/plan-protocol.md), [§ 11](references/plan-protocol.md)).
- Before applying the refactor-child review-skip path — to verify all
  four AND conditions ([§ 9](references/plan-protocol.md)).
- Before emitting an artifact path — to substitute `${current_check_root}`
  rather than hardcoding `plan/check/` ([§ 14](references/plan-protocol.md)).
- Before any plan, execution, or finalization stage reads or writes
  PLAN_ROOT artifacts — to apply the PLAN_ROOT preflight
  ([§ 14.1](references/plan-protocol.md)).

## Wrapper Invariants (Claude-side)

- This wrapper writes no files. It points to the reference file. Other
  skills are responsible for their own artifacts.
- Frontmatter, descriptions, and any local path examples in this
  wrapper may diverge from the Codex-side wrapper. The
  byte-identical sync target is **only** `references/plan-protocol.md`.
- If a Claude-side skill's wording disagrees with the contract body in
  `references/plan-protocol.md`, the reference file wins. Update the
  Claude-side skill first, not the reference. Reference-file changes
  must be mirrored to the Codex-side reference in the same change.

## Drift Reporting

When a caller detects that the Claude-side and Codex-side
`references/plan-protocol.md` have drifted (e.g., by SHA256 mismatch),
the workflow stops and escalates to the user. The drift guard is a
closure violation candidate; do not work around by editing only one
side.

The wrapper `SKILL.md` (this file) is **not** part of the drift guard.
Frontmatter, invocation wording, and Claude-environment-specific
examples are allowed to differ from the Codex-side wrapper.

## PLAN_ROOT Preflight

The executable preflight is defined in
[references/plan-protocol.md § 14.1](references/plan-protocol.md).
Stages must report bootstrap need when canonical `plan/` is absent,
stop on legacy `docs/plan`, `docs/check`, `docs/archive`,
`docs/roadmap`, or `docs/runbook`, create only missing canonical
directories when partial canonical structure exists without legacy
conflict, and never overwrite, migrate, or move artifacts without
explicit user approval.

## Cross-References

- `plan-run` — planning-stage router. Cites this protocol for Q1/Q2,
  parent-lock gate, and routing into `plan-intake` / `plan-draft` /
  `plan-review` / `plan-reconcile`.
- `plan-reconcile` — writes `decision-blocked` / `decision-resolved` /
  `parent_review_converged` / `policy-locked` /
  `child_<id>_plan_revision_required` / `child_<id>_frozen`.
- `draft-intent-worker` / `test-intent-worker` — return
  `child-checkpoint.v1` JSON per § 7.
- Codex `exec-run` — writes most child-transition entries; cites this
  protocol from the Codex-side wrapper.
- Codex `exec-code-quality` — writes `code-quality-ready` /
  `refactor-needed` / `code-quality-blocked`.

Record future protocol changes in a project-local parent plan before
editing the reference body.
