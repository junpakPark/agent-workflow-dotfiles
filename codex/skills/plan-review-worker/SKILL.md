---
name: plan-review-worker
description: Given a single local plan document under `plan/families`, produce CTO + 6-lens findings against the parent plan and emit them via the Codex CLI structured-output transport (`codex exec --output-schema parent-plan-review.v1`). Final response is the `parent-plan-review.v1` JSON payload; F-NNN Markdown is the wrapper's rendering, not worker output. Do not edit the plan, do not triage, do not write artifacts, and do not decide workflow status.
---

# Plan Review Worker

## Overview

Review one specified local plan document as an external worker invoked by the Claude `plan-review` wrapper. The plan document is under `plan/families/`. Produce raw findings only. The caller owns artifact storage, evidence validation, triage, routing, scope/severity selection, closure-map context derivation, and edits.

Read [references/review.md](references/review.md) before reviewing — in particular the § Output Transport section (structured-output vs legacy) and the § Focus text structured prefix. The literal directive marker is `<<<plan-review>>>`.

## Output Transport

Two transports exist; the caller chooses by how it invokes Codex.

### Structured-output transport (canonical for parent Full Panel review)

The wrapper invokes:

```sh
codex exec --sandbox read-only --output-schema <schema> -o <output.json> - < <prompt-file>
```

When `--output-schema` is bound to `parent-plan-review.v1`, the Codex runtime enforces that the **final response** is a single JSON object validating against the schema. In this mode:

- Your final answer IS the `parent-plan-review.v1` JSON object. No free-form prose, no Markdown around it, no `## CTO / problem-definition review` headings. The Codex runtime validates the final assistant message against the schema, and the Claude wrapper captures that message via `codex exec -o <file>` (the canonical Codex CLI capture path — there is no `.structured_output` envelope on the Codex side, unlike the Claude CLI).
- Each material finding becomes one entry in the schema's `findings[]` array with `id`, `severity`, `lens`, `title`, `issue`, `why_it_matters`, `evidence[]`, `suggested_action`. The fields carry the same meaning as the legacy F-NNN Markdown shape; only the transport changes.
- The seven canonical lenses appear in `lens_results[]` (one entry per lens) with `status ∈ {findings, no_findings, n_a}`. The schema uses a required-nullable wire shape: every lens entry MUST include both `finding_ids` and `reason`. A `findings` lens sets `finding_ids` to a non-null array (≥1 ids that match elements of `findings[]`) and `reason` to `null`. A `no_findings` lens sets both `finding_ids` and `reason` to `null`. An `n_a` lens sets `finding_ids` to `null` and `reason` to a non-null short clause. These three tokens MUST match the schema enum at `$defs.lens_result.properties.status`.
- The JSON directive fields are normalized from the structured directive prefix. The prefix has four mandatory keys (`review_scope`, `review_severity`, `closure_map_path`, `recovery_mode`) plus conditional `delta_scope`: required only when `review_scope="delta"` and omitted when `review_scope="full"`. In JSON, `delta_scope` is always present (`null` for full-scope reviews, the canonical encoding string for delta reviews).
- The required provenance fields (`schema_version`, `reviewed_inputs.git_head`, `reviewed_inputs.parent_plan_path`, `reviewed_inputs.parent_plan_sha256`, `reviewed_inputs.closure_map_sha256`, `reviewed_inputs.reviewed_files`) come from the wrapper-computed provenance block in the prompt body. Echo those expected values exactly. Do not compute, infer, or guess git head, hashes, or reviewed files.
- The local read boundary is parent-plan-only. In canonical structured-output parent review, read the specified parent plan plus inline caller-provided prompt/provenance context; do not open additional repo files to validate plan claims.
- The wrapper renders F-NNN Markdown deterministically from this JSON. Do NOT emit the F-NNN Markdown yourself in structured-output mode — the wrapper owns rendering. The legacy F-NNN shape spec in `references/review.md` documents the per-finding semantics; the schema encodes those semantics as JSON.

### Legacy free-form transport (non-Full-Panel, no schema bound)

When the caller invokes Codex without `--output-schema`, fall back to the legacy free-form prose / F-NNN Markdown contract documented in `references/review.md`. This mode is retained for ad-hoc inspections and bootstrap-territory calls; canonical parent Full Panel review in docs-plan v2 is structured-output only.

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

1. Read the specified parent plan document and any inline caller-provided context/provenance in the prompt. In structured-output mode, do not open additional repo files.
2. Detect the caller's structured prefix by substring search for `<<<plan-review>>>` inside the companion-wrapped focus prompt.
3. Parse and honor `review_scope`, `review_severity`, `delta_scope`, `closure_map_path`, and `recovery_mode` exactly as defined in `references/review.md`.
4. In structured-output mode, read the wrapper-computed provenance block and echo its expected values exactly into `schema_version` and `reviewed_inputs`. Do not calculate or guess provenance fields yourself.
5. If the prefix is absent, fall back to legacy free-form prose processing without deciding active-vs-bootstrap territory.
6. If a structured prefix is present and `closure_map_path` is parseable, read only the parent plan's `## Closure map` section for context.
7. Review through the applicable lenses in `references/review.md`.
8. Emit findings in the active transport:
   - **structured-output mode** (`--output-schema parent-plan-review.v1` is bound): your final response is the schema-conforming JSON object only. Each material finding is one element of `findings[]`. Populate `lens_results[]` with one entry per lens (seven total). Do NOT emit Markdown headings, prose narration, or F-NNN strings as the final response — the wrapper renders F-NNN from the JSON.
   - **legacy free-form mode** (no schema bound): emit the F-NNN Markdown contract documented in `references/review.md`.
9. Preserve one finding per lens observation. Do not merge repeated observations across lenses.
10. Per-lens emission rules (structured-output mode):
   - **Lens reviewed, ≥1 finding emitted** → `lens_results[]` entry with `status = "findings"`, `finding_ids` listing every F-NNN id whose `lens` equals this lens (count ≥ 1), and `reason = null`.
   - **Lens reviewed, 0 findings emitted** → `lens_results[]` entry with `status = "no_findings"`, `finding_ids = null`, and `reason = null`.
   - **Lens not applicable to this plan** → `lens_results[]` entry with `status = "n_a"`, `finding_ids = null`, and `reason = <one short clause>`. Do NOT emit any synthetic finding under this lens.
11. Per-lens emission rules (legacy free-form mode):
    - Lens with ≥1 finding → emit the F-NNN block(s) under that lens heading.
    - Lens reviewed but no finding → emit the lens heading and leave the body empty (or write `_(no material findings)_` for readability).
    - Lens not applicable → include that lens section with `_N/A - <reason>`.

## Boundaries

- Do not edit files.
- Do not write `plan/check/*` artifacts.
- Do not classify findings as resolved or unresolved.
- Do not choose the current or next workflow state.
- Do not decide whether a reconcile requires review.
- Do not determine material-change status.
- Do not choose or override caller-provided `review_scope` or `review_severity` directives.
- Do not compute `delta_scope`; only honor caller-provided scope.
- Do not compute or guess `git_head`, plan hashes, closure-map hashes, or `reviewed_files`; echo the wrapper-computed provenance block in structured-output mode.
- In canonical structured-output parent review, do not read code, tests, root docs, ADRs, child plans, or other repo files. Treat external paths as parent-plan claims unless their contents are included inline by the caller.
- When source evidence is missing or unverifiable within the parent plan and inline prompt context, emit a finding for the missing evidence instead of validating by reading outside the parent plan.
- Do not decide active-vs-bootstrap territory; the caller-side preflight gate owns territory.
- Do not perform `recovery_mode` routing; the caller-side reconcile owns it.
- Do not treat a closure map as an answer key that suppresses findings outside the closed decision.
- Do not ask the user questions; report missing input as a finding or `_N/A` where appropriate.
- Do not include remediation patches.
