---
name: plan-draft
description: Draft a parent plan (umbrella) for a docs-plan v2 family. Use after `/plan-intake` is confirmed. Parent-only — child plan creation is Codex `exec-draft` territory in v2, not this skill. Enforces parent draft depth control (no child detail in parent), parent decision reference rule, parent `## Status` section mandate, and `## Child Handoff Board` seed at creation.
---

# plan-draft

## Purpose

Write the parent (umbrella) plan for a docs-plan v2 family after intake
is confirmed. In v2 the parent plan locks family-level intent, policy,
source-of-truth, child responsibility boundaries (abstract framing
only), and parent acceptance criteria — but **does not** contain child
implementation detail. Child plans are written by Codex `exec-draft`
during the execution stage.

This skill is owned by Claude. It produces local-only files under
`plan/families/`. The plan file itself is the artifact; this skill
writes nothing elsewhere.

## Read First

- `AGENTS.md`, `README.md`, `DEVELOPER_GUIDE.md`, `ARCHITECTURE.md` for
  current contract.
- `docs/adr/*` only when a structural decision matters.
- [plan-protocol reference](../plan-protocol/references/plan-protocol.md)
  — for `## Status`, `## Child Handoff Board`, family_status
  vocabulary, single-writer rule, and child concurrency rule that the
  drafted parent must conform to.

## PLAN_ROOT Preflight

Before writing a parent plan, apply plan-protocol § 14.1. If canonical
`plan/` is absent, report that PLAN_ROOT bootstrap is required. If
`docs/plan`, `docs/check`, `docs/archive`, `docs/roadmap`, or
`docs/runbook` exists, stop and report the legacy conflict. If only
some canonical directories are missing and no legacy conflict exists,
create the missing directories idempotently. Never overwrite existing
files, migrate artifacts, or move artifacts without explicit user
approval.

## Workflow

1. Confirm intake (`/plan-intake`) is closed in a prior turn.
2. Allocate the next unused umbrella number, or extend an existing
   family if the request clearly continues it.
3. Write the parent plan with these sections:
   - `## Goal` / `## Scope` / `## Non-goals` / `## Success criteria`
     (from intake).
   - `## Source of truth` — mapping each core decision to one of
     `docs/operating-policy.md`, `docs/adr/<file>.md`, `parent invariant + acceptance
     test`, or `parent closure-only`.
   - `## Children` — child responsibility framing only (name,
     purpose, responsibility boundary, dependencies). Target
     identifiers (skill / doc paths, module names) are allowed —
     they make handoff findable. Child implementation patch specs,
     line-level change lists, API call sequence bodies, and test-case
     bodies are forbidden in the parent and the save must be blocked
     if they appear.
   - `## Closure map` — created empty; reconcile fills it after
     review. Each Decision uses the 9-field form (id, title, source
     of truth, allowed wording, forbidden wording, remaining
     implementation obligations, affected child docs, decided cycle,
     evidence).
   - `## Child Handoff Board` — seeded empty per plan-protocol § 6.
     Claude fills `child` / `responsibility` / `dependencies`
     columns; Codex `exec-run` fills runtime columns at execution time.
   - `## Status` — seeded empty per plan-protocol § 5. The first
     entries will be appended later by `plan-reconcile` (after
     review/closure lock).
4. Bidirectionally link the parent with any pre-existing root docs it
   references.

## Draft Depth Control (Save Block)

The save is **blocked** if the draft output contains any of:
- child implementation patch specs (concrete patch / diff body)
- line-level file change lists
- API / library call sequence bodies
- test-case body specs (assertion / fixture body)

The block message names which forbidden item matched and offers two
recovery options:
- defer the matched content to a future child draft (Codex
  `exec-draft` territory in v2), or
- rewrite the matched content as child responsibility abstract framing
  and retry the save.

Target identifiers (skill / doc paths) are explicitly out of the
block.

## Parent Decision Reference Rule

Inside any child plan (written later by Codex `exec-draft`), parent
decisions must be cited as one of:
- `parent §X.Y` (a parent section)
- `Parent §D-NNN` or `Decision D-NNN` (a closure id)

Paraphrasing a parent decision in different words is forbidden in
child plans. This rule is enforced by the Claude `draft-intent-worker`
when it reviews child drafts via Codex `draft-review`. `plan-draft`
itself does not write child plans, but it must produce parent
decisions in wording that the child can cite verbatim — vague or
ambiguous parent wording defeats the citation rule downstream.

## Parent `## Status` Mandate

Every new parent plan ends with an empty `## Status` section. The
section starts with zero entries; the first entry will be appended by
`plan-reconcile` (or later stage skills per the single-writer table
in plan-protocol § 2).

If the parent plan being touched already has `## Status`, this skill
does not modify it (append-only invariant).

## Child Concurrency Rule

`plan-draft` is parent-only and does not write child plans. The child
concurrency rule (only one child in progress) is enforced at the
`exec-run` stage in Codex, not here. `plan-draft` may, however,
abstract-frame multiple children in the parent's `## Children`
section — those framings do not constitute child plans.

## Stop Gate

- Do not invoke `/plan-review` in the same turn as the parent draft.
- Do not write any child plan from this skill.
- Save the parent plan and stop.

## Removed Legacy Path

The old `docs-plan-*` bridge was removed after Phase 2 cleanup. New work must use this v2 skill surface. Do not mix v1 lifecycle routing with v2 `plan-*`, `exec-*`, or `finalize-*` routing.

## Cross-References

- [plan-protocol § 2](../plan-protocol/references/plan-protocol.md) — family_status vocabulary
- [plan-protocol § 4.4](../plan-protocol/references/plan-protocol.md) — child concurrency rule
- [plan-protocol § 5](../plan-protocol/references/plan-protocol.md) — `## Status` invariants
- [plan-protocol § 6](../plan-protocol/references/plan-protocol.md) — `## Child Handoff Board` contract
- `plan-review` — runs after parent draft for parent Full Panel review
- Codex `exec-draft` — child plan creation in v2 (not this skill)
