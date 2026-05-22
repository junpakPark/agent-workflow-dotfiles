---
name: plan-reconcile
description: Triage parent plan review artifacts and code-quality escalation findings for docs-plan v2. Owns parent-plan closure map registration, decision-needed handling (with user-question artifact), forbidden-wording self-check, remaining-obligation tracking, and material change → Delta review caller contract. Writes the `## Status` markers `parent_review_converged`, `policy-locked`, `decision-blocked`, `decision-resolved`, `child_<id>_plan_revision_required`, and `child_<id>_frozen`. Child Full Panel reconcile path is removed in canonical v2; child plan reviews use Codex `draft-review` + Claude `draft-intent-worker`.
---

# plan-reconcile

## Purpose

Claude-side parent-plan reconcile. Triages F-NNN findings from:
- parent plan review artifacts produced by `/plan-review`
- code-quality escalation handoffs from Codex `exec-code-quality`
  (`decision-needed` / closure violation / `plan-blocker` cases)

It does not perform code-quality triage in v2 — Codex
`exec-code-quality` writes `## Code-quality result` directly and only
escalates the cases above. It does not perform child-plan-intent
review — that is Claude `draft-intent-worker` via Codex `draft-review`.

It does write the `## Status` markers that gate the planning side:
`parent_review_converged`, `policy-locked`, `decision-blocked`,
`decision-resolved`, `child_<id>_plan_revision_required`, and
`child_<id>_frozen`. It does NOT write Codex-domain markers
(`child_<id>_plan_locked`, `_tests_*`, `_implement_*`,
`_blocked`, `code-quality-*`).

## Read First

- The parent plan and its `## Closure map`.
- The triage artifact (`plan/check/*-review.md` or the escalation
  payload from `exec-code-quality`).
- [plan-protocol reference](../plan-protocol/references/plan-protocol.md)
  — for vocabulary, single-writer rule, gate conditions, and escalation
  rules.
- [`references/plan-review-closure.md`](references/plan-review-closure.md)
  — for closure map format, decision-needed close condition,
  user-question artifact template, forbidden-wording self-check,
  remaining-obligation tracking, triage classification (P2-D-20 lock),
  triage ledger, native `codex-review` boundary, closure-body wording
  drift routing default, and material change caller contract.

## PLAN_ROOT Preflight

Before reading or writing reconcile artifacts, apply plan-protocol
§ 14.1. If canonical `plan/` is absent, report that PLAN_ROOT
bootstrap is required. If `docs/plan`, `docs/check`, `docs/archive`,
`docs/roadmap`, or `docs/runbook` exists, stop and report the legacy
conflict. If only some canonical directories are missing and no legacy
conflict exists, create the missing directories idempotently. Never
overwrite existing files, migrate artifacts, or move artifacts without
explicit user approval.

## Workflow

1. **Identify artifact type.**
   - `plan/check/*-review.md` → plan review artifact (parent only in v2)
   - `plan/check/*-code-quality.md` with escalation payload → code-
     quality escalation handoff from `exec-code-quality`
2. **Build working list of F-NNN findings.** Read only the `## Codex
   output` section. List every F-NNN entry.
3. **Merge duplicates.** Collapse entries sharing an evidence anchor.
4. **Validate evidence.** Read each entry's cited evidence directly.
   Drop entries whose evidence fails as `reject` with the validation
   result attached. When the fix concerns a wrong concrete fact inside
   a table, list, grouped bullets, or other evidence cluster, also
   inspect the neighboring entries in that same source surface before
   applying the fix. For caller lists, tool invocation relationships,
   response-shape invariants, archive-derived tables, or current code
   behavior, validate both the cited archive/source table and the
   current code path when available before locking new wording.
5. **Triage (4-classification, P2-D-20 lock).** See
   [references/plan-review-closure.md § Triage Classifications](references/plan-review-closure.md).
   Default stance: acknowledge what is valid, push back actively when
   possible. Codex severity is informational; reconcile owns
   classification.
   - `plan-blocker` — validated finding requiring an edit now to keep
     the next stage safe or executable. Triggers material change
     re-review if any of the 7 areas changes.
   - `decision-needed` — real policy/operating tradeoff not settleable
     by repo evidence. Enters `decision-blocked`. Close condition:
     user response AND `D-NNN` registered (both).
   - `transferred-obligation` — verification responsibility already
     captured by acceptance row / manual scenario / closure obligation.
     Four conditions must all hold (P2-D-20 lock). Forbidden as
     `decision-needed` bypass.
   - `reject` / `backlog` — evidence fails (`reject`) or out-of-scope
     improvement (`backlog`).
6. **Apply accept actions.**
   - Plan review artifact: edit the parent plan per the accepted
     finding's suggested action. Re-run `/plan-review` for a fresh
     artifact when material change occurred (see § Material Change).
   - Code-quality escalation: do not write `## Code-quality result`
     — that is Codex `exec-code-quality`'s territory. Reconcile may
     register a `D-NNN`, append `decision-blocked`, or surface a
     user-question artifact; once the escalation closes, Codex
     re-enters `exec-code-quality` and writes a fresh
     `code-quality-ready` marker.
7. **Triage ledger.** Every finding gets one ledger row per
   [references/plan-review-closure.md § Triage Ledger](references/plan-review-closure.md).
   Ungrounded triage (no `governing_source` citation) is refused;
   stop and escalate to the user.
8. **Material change self-check.** After accept actions, run the
   7-area self-check (`parent_boundary`, `source_of_truth`,
   `child_responsibility`, `acceptance_test`,
   `operator_visible_behavior`, `stage_gate`,
   `closure_map_semantics`). If any area changed, invoke
   `/plan-review` with the structured prefix per
   [references/plan-review-closure.md § Material Change → Delta Review](references/plan-review-closure.md).
   Reconcile's self-judgment alone cannot skip the re-review.
9. **`## Status` writes.** Per plan-protocol § 2 single-writer table,
   reconcile appends:
   - `parent_review_converged` — parent review unresolved = 0
   - `policy-locked` — parent-lock 4 conditions met (see plan-protocol § 4.1).
     Append both `parent_review_converged` and `policy-locked` as
     **separate entries** in time order.
   - `decision-blocked` — the moment a `decision-needed` is raised
   - `decision-resolved` — when user response + `D-NNN` both exist
   - `child_<id>_plan_revision_required` — when reconcile decides a
     child plan contract itself must change (acceptance / scope /
     SoT). Test-only and manual-only repeats never produce this
     marker (per plan-protocol § 8).
   - `child_<id>_frozen` — when a child is deferred and releases
     concurrency.
10. **Hand off.** When triage closes with unresolved = 0 and the
    parent-lock 4 conditions hold, `policy-locked` admits the family
    to the execution stage (Codex `exec-run`). When `decision-blocked`
    or `child_<id>_plan_revision_required` is pending, the family
    waits.

## Refactor Child Creation (Code-quality Path)

Code-quality refactor children are created by Codex `exec-code-quality`
in v2 — reconcile no longer creates refactor children. Reconcile may
flag a quality escalation as `decision-needed` or `plan-blocker`; the
refactor child itself is Codex's writeup. If a refactor child arrives
at `draft-review` and fails the four-condition AND gate (plan-protocol
§ 9), Codex re-routes per § 9; reconcile does not unilaterally enforce
the gate.

## Stop Gates

- Do not advance a stage transition while `decision-blocked` is
  family-latest.
- Do not close a `decision-needed` finding without **both** the user
  response and the `D-NNN` registration.
- Do not edit a plan to silence an evidence-backed `reject`.
- Do not resolve a real product / operating-policy tradeoff on the
  user's behalf — surface the smallest possible question.
- Do not write Codex-domain markers; do not consume them as
  authoritative without reading `## Status` directly.

## Removed Legacy Path

The old `docs-plan-*` bridge was removed after Phase 2 cleanup. New work must use this v2 skill surface. Do not mix v1 lifecycle routing with v2 `plan-*`, `exec-*`, or `finalize-*` routing.

## Cross-References

- [plan-protocol § 2](../plan-protocol/references/plan-protocol.md) — family_status vocabulary + single-writer
- [plan-protocol § 4.1](../plan-protocol/references/plan-protocol.md) — parent-lock gate
- [plan-protocol § 4.3](../plan-protocol/references/plan-protocol.md) — decision-blocked guard
- [plan-protocol § 8](../plan-protocol/references/plan-protocol.md) — recurrence routing; `_plan_revision_required` is reconcile's writer for `recurrence_cause = contract`
- [plan-protocol § 10](../plan-protocol/references/plan-protocol.md) — cross-orchestrator escalation rules
- [references/plan-review-closure.md](references/plan-review-closure.md) — closure map, decision-needed, forbidden wording, remaining obligation, triage classification, ledger, native `codex-review` boundary, material change caller contract
- `plan-run` — calls this skill as part of the planning-stage routing
- `plan-review` — produces the artifact this skill triages
