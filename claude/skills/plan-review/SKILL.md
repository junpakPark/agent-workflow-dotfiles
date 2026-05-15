---
name: plan-review
description: Delegate parent plan Full Panel review (CTO + 6 lenses) to the Codex `plan-review-worker` and save the verbatim output for triage. Use when the parent plan is drafted and needs Full Panel review evidence before `/plan-reconcile`. The Codex worker owns lens definitions, F-NNN format, and severity rules; this skill only invokes, saves, runs the closure-aware post-processing pipeline, and hands off. Parent-only — child Full Panel review is legacy/explicit-only in v2; canonical child plan review goes through Codex `draft-review` + Claude `draft-intent-worker`.
---

# plan-review

## Purpose

Invoke the Codex `plan-review-worker` against a parent plan and save
its verbatim F-NNN findings into a check artifact for `/plan-reconcile`
to triage. This skill is the Claude-side wrapper of the Codex worker;
it owns:
- the structured focus-text prefix contract
- caller-side scope-aware preflight (rejecting malformed requests)
- closure-aware post-processing of the worker's raw output

It does **not** perform semantic triage — that is `/plan-reconcile`'s
job. It does **not** review child plans — that is Codex `draft-review`
+ Claude `draft-intent-worker` in v2.

## Read First

- The parent plan being reviewed and its `## Closure map` (if any).
- [plan-protocol reference](../plan-protocol/references/plan-protocol.md)
  for the `## Status` invariants the review must not violate.
- Codex `plan-review-worker` and its `references/review.md` for the worker-side lens and prefix parser contract.

## PLAN_ROOT Preflight

Before reading or writing review artifacts, apply plan-protocol § 14.1.
If canonical `plan/` is absent, report that PLAN_ROOT bootstrap is
required. If `docs/plan`, `docs/check`, `docs/archive`,
`docs/roadmap`, or `docs/runbook` exists, stop and report the legacy
conflict. If only some canonical directories are missing and no legacy
conflict exists, create the missing directories idempotently. Never
overwrite existing files, migrate artifacts, or move artifacts without
explicit user approval.

## Parent-Only Canonical Path

In docs-plan v2, `/plan-review` is invoked only for the parent plan.
The Codex worker emits CTO + 6-lens findings against the parent's
intent, scope, source-of-truth, child responsibility boundaries,
acceptance criteria, and risk surface.

Child plan review uses a different cross-review pattern in v2:
- the wrapper is **Codex `draft-review`** (not `/plan-review`)
- the worker is **Claude `draft-intent-worker`** (not Codex
  `plan-review-worker`)
- the output is a `child-checkpoint.v1` JSON envelope, not an F-NNN
  artifact

Do not confuse the two paths. `/plan-review` does not call
`draft-intent-worker`. Codex `draft-review` does not call
`plan-review-worker`.

## Child Full Panel Path

Child Full Panel review is not available in canonical v2 routing. Child plan review is Codex `draft-review` + Claude `draft-intent-worker`. If a user asks for a child Full Panel review anyway, stop and explain that v2 removed the legacy path; do not route to deleted `docs-plan-*` skills.

## Structured Focus-Text Prefix Contract

Every Codex `plan-review-worker` invocation passes a structured
prefix on the focus-text first line. The Codex worker parses this
v2 marker (renamed from the Phase 1 bridge marker
`<<<docs-plan-review>>>` during Phase 2 cleanup; the worker now
parses `<<<plan-review>>>` only):

```
<<<plan-review>>> review_scope=<full|delta> review_severity=<full-panel|blocking-only> [delta_scope=<canonical encoding>] closure_map_path=<project-root>/plan/families/<parent>.md recovery_mode=<auto|manual>
```

Five keys; four always-mandatory (`review_scope`, `review_severity`,
`closure_map_path`, `recovery_mode`); `delta_scope` is conditional —
required only when `review_scope=delta`, forbidden when
`review_scope=full`.

This skill rejects malformed invocations at the caller-side preflight:
- `full` + `delta_scope` combination → reject.
- missing any always-mandatory key → reject.
- missing `delta_scope` when `review_scope=delta` → reject.
- silent normalization of any key to its spec default → forbidden.

See Codex `plan-review-worker/references/review.md` for the worker-side parser details. This wrapper owns caller-side preflight and recovery behavior.

## Closure-aware Post-processing Pipeline

After the worker returns its raw artifact, the wrapper performs the
following before handing off to `/plan-reconcile`:
1. **merge exact duplicates** — identical findings from multiple
   lenses collapse to one entry with `contributing lenses: <list>`.
2. **split independent risks** — single findings that bundle multiple
   independent risks split into separate entries.
3. **parent-escalate conversion** — findings that should land on the
   parent plan are tagged so reconcile can route them up.
4. **related-closure annotation** — annotate findings that already
   map to an existing `D-NNN` so reconcile can apply
   `transferred-obligation` triage when the four conditions hold.

The Codex worker's raw shape is preserved verbatim under `## Codex
output`. Post-processing produces a `## Normalized findings` section
alongside.

**Finding source boundary**: `## Codex output` is the **sole canonical
reconcile input**. The `## Normalized findings` section is
**display/advisory only** — for human reviewers scanning the artifact.
Reconcile **must not** consume the normalized section as authoritative;
it reads F-NNN findings only from `## Codex output` (per
`plan-reconcile` workflow step 2). If the normalized section disagrees
with the raw section, the raw section wins and the normalized section
is regenerated, not the other way around.

## Caller-side Scope-aware Contract

Reconcile (not this skill) decides whether a re-review is needed
after material change. When reconcile triggers a re-review, it
derives `delta_scope` itself and emits the structured prefix; the
worker only parses what reconcile sends. This skill enforces preflight
on the caller side per the contract above.

## Artifact Path

Saved to `${current_check_root}/<parent-basename>-review.md` per the
plan-protocol § 14 `current_check_root` variable. Canonical resolved
path: `plan/check/<parent-basename>-review.md`.

Failed artifacts use `.failed.md` suffix. Pending sidecars use
`.md.pending`. Only the success file is reconcile input; `.failed.md`
is informational.

## Stop Gate

- Stop after the artifact is saved. The next stage is
  `/plan-reconcile`.
- Do not triage findings in this skill.
- Do not append any `family_status` entry (single-writer rule —
  reconcile owns `parent_review_converged` and `policy-locked`).

## Removed Legacy Path

`docs-plan-review` was a Phase 1 to Phase 2 bridge and is removed after Phase 2 cleanup. New work must use `plan-review`; child plan review must use Codex `draft-review`.

## Cross-References

- [plan-protocol § 5](../plan-protocol/references/plan-protocol.md) — `## Status` invariants (this skill does not write here)
- `plan-reconcile` — next stage; triages the artifact saved here
- Codex `plan-review-worker` — the worker invoked behind this wrapper
- Codex `draft-review` + Claude `draft-intent-worker` — the v2 child plan review path (separate from this skill)
