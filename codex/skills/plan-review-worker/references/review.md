# Plan Review Worker Reference

## Contents

- [Output Transport](#output-transport)
- [Output Contract (shape semantics)](#output-contract-shape-semantics)
- [Severity](#severity)
- [Review Modes](#review-modes)
- [Focus text structured prefix](#focus-text-structured-prefix)
- [Lenses](#lenses)

## Output Transport

Two transports exist; the active transport is determined by how the Claude `plan-review` wrapper invokes Codex.

### Structured-output transport (canonical for parent Full Panel review)

The wrapper invokes `codex exec --sandbox read-only --output-schema <schema> -o <output.json> - < <prompt-file>`. When `--output-schema` is bound to `parent-plan-review.v1`, the Codex runtime enforces that the final response is a single JSON object validating against the schema.

In this mode:

- The final response is the `parent-plan-review.v1` JSON object **only**. No Markdown around it, no `## CTO / problem-definition review` headings as final answer, no `_N/A - <reason>` line outside the JSON, no F-NNN string in final-answer text.
- The schema fields map 1:1 to the per-finding shape in § Output Contract below. The F-NNN Markdown shape is the wrapper's deterministic rendering of the JSON; do **not** emit it yourself as the final response in this mode.
- The schema uses a required-nullable wire shape for fields that are conditionally absent in the logical contract: always include `delta_scope`, `reviewed_inputs.closure_map_sha256`, `lens_results[].finding_ids`, and `lens_results[].reason`; use `null` when the value is not logically present.
- The wrapper enforces lens uniqueness, status-specific nullability, finding-id uniqueness, echoed-field consistency, and reviewed-inputs hashes as wrapper invariants after schema validation. Drift on any of these is a wrapper-side rejection (`.failed.md`). Echo wrapper-provided provenance exactly; do not coerce substantive findings to satisfy the schema.
- Schema-coercion or contradiction phrases (`cannot complete as requested`, `schema limitation`, `not in the schema`, `forced by schema`, `Verdict: approve / no material findings`, `code diff`) anywhere in the JSON (other than verbatim `findings[].evidence` quoting plan text) are wrapper-side rejections.

#### Wrapper-computed provenance block

Canonical structured-output prompts include a wrapper-computed provenance block separate from the structured directive prefix. The directive prefix controls review behavior; the provenance block controls exact echo fields. The provenance block contains:

- `expected_schema_version`
- `expected_git_head`
- `expected_parent_plan_path`
- `expected_parent_plan_sha256`
- `expected_closure_map_path`
- `expected_closure_map_sha256`
- `expected_reviewed_files`

Structured-output provenance mapping:

| JSON field | Source |
|---|---|
| `schema_version` | exact echo of `expected_schema_version` |
| `closure_map_path` | directive prefix `closure_map_path`; it must name the same host file as `expected_closure_map_path` |
| `reviewed_inputs.git_head` | exact echo of `expected_git_head` |
| `reviewed_inputs.parent_plan_path` | exact echo of `expected_parent_plan_path` |
| `reviewed_inputs.parent_plan_sha256` | exact echo of `expected_parent_plan_sha256` |
| `reviewed_inputs.closure_map_sha256` | exact echo of `expected_closure_map_sha256` |
| `reviewed_inputs.reviewed_files` | exact echo of `expected_reviewed_files` |

Do not compute, infer, or guess any provenance value. Do not run git commands to discover `git_head`. Do not hash files to fill `parent_plan_sha256` or `closure_map_sha256`. Do not derive `reviewed_files` from the files you happened to inspect. In canonical v2, `closure_map_path` points at the parent plan, so `closure_map_sha256` is the SHA-256 of the parent-plan host file, not the extracted `## Closure map` section, and `expected_closure_map_sha256` equals `expected_parent_plan_sha256`.

#### Structured-output evidence boundary

Canonical structured-output parent Full Panel review is parent-plan-only for local file reads. The worker may read the parent plan named by `closure_map_path` / `expected_parent_plan_path` and inline caller-provided prompt or provenance context. Do not open code, tests, root docs, ADRs, child plans, or other repo files to validate parent-plan claims.

When the parent plan cites an external path, treat that path as a parent-plan-cited reference unless the caller included the referenced content inline in the prompt. If a lens question cannot be answered from the parent plan and inline prompt context, emit a finding for missing or unverifiable source evidence instead of validating by reading outside the parent plan. `reviewed_inputs.reviewed_files` remains the exact wrapper-provided echo and must not be expanded to match files you inspected.

### Legacy free-form transport (no schema bound)

When the wrapper invokes Codex without `--output-schema`, fall back to the Markdown F-NNN format documented under § Output Contract. This mode is retained for ad-hoc inspections and bootstrap-territory calls; canonical parent Full Panel review in docs-plan v2 is structured-output only.

## Output Contract (shape semantics)

The seven lenses in canonical order:

1. CTO / problem-definition review
2. Implementer review
3. Operator review
4. QA review
5. Maintainer review
6. Docs usability review
7. Risk / rollout review

Per-finding shape (same semantics in both transports; structured-output encodes these as JSON fields, legacy free-form renders these as Markdown):

```markdown
#### F-NNN [severity] <one-line title>
- source lens: <one lens name>
- issue: <what is unclear, incomplete, unsafe, or contradictory>
- why it matters: <practical effect>
- evidence: <parent-plan line/heading, inline caller context, parent-plan-cited external path marked as unverified, or explicit missing evidence>
- suggested action: <one short action for the caller>
```

Schema field mapping (structured-output mode — see `parent-plan-review.v1.schema.json`):

| Markdown line | JSON field |
|---|---|
| `F-NNN` token | `findings[].id` (`^F-[0-9]{3}$`) |
| `[severity]` | `findings[].severity` (`blocking` \| `decision-needed` \| `non-blocking`) |
| source lens display name | `findings[].lens` (kebab-case token: `cto-problem-definition`, `implementer`, `operator`, `qa`, `maintainer`, `docs-usability`, `risk-rollout`) |
| `<one-line title>` | `findings[].title` |
| `issue:` | `findings[].issue` |
| `why it matters:` | `findings[].why_it_matters` |
| `evidence:` | `findings[].evidence` (array of strings) |
| `suggested action:` | `findings[].suggested_action` |
| `_N/A - <reason>` for a whole lens | `lens_results[]` entry with `status="n_a"`, `finding_ids=null`, `reason=<reason>` |
| lens reviewed but no finding (legacy emits empty section or `_(no material findings)_`) | `lens_results[]` entry with `status="no_findings"`, `finding_ids=null`, `reason=null` |
| lens reviewed with ≥1 finding | `lens_results[]` entry with `status="findings"`, `finding_ids = [<all F-NNN ids whose lens equals this lens>]`, `reason=null` |

Rules (both transports):

- Number findings in source-doc order across the whole output, starting at `F-001`. Finding ids are unique across the array.
- Use exactly one severity: `blocking`, `decision-needed`, or `non-blocking`.
- Keep duplicate observations from different lenses separate when they come from different lens concerns.
- In structured-output mode: every lens appears exactly once in `lens_results[]` with one of the three schema-enumerated statuses — `findings` (≥1 finding emitted; `finding_ids` non-null array, `reason=null`), `no_findings` (lens reviewed, zero findings; `finding_ids=null`, `reason=null`), or `n_a` (lens not applicable; `finding_ids=null`, `reason` non-null). The schema enforces the always-present shape; the wrapper enforces status-dependent nullability and 7-element exact-set lens uniqueness post-schema.
- In structured-output mode: evidence must not imply the worker opened a local file outside the parent plan unless that content was supplied inline in the prompt.
- In legacy free-form mode: use `_N/A - <reason>` only for a non-applicable lens. For a reviewed lens with zero findings, leave the section empty or write `_(no material findings)_` for readability.
- Do not include pass/fail status, artifact instructions, or workflow routing.

## Severity

- `blocking`: the plan cannot be executed safely without resolving the issue.
- `decision-needed`: the plan requires a user/product/operating-policy choice that repo evidence cannot decide.
- `non-blocking`: the plan can proceed, but the issue would improve clarity, maintainability, or safety.

Simple wording, header, or stale-status issues are normally `non-blocking` unless they change executable behavior or hide the next required action. Execution contracts, gates, source-of-truth ownership, or decision-needed bypasses may be `blocking` or `decision-needed` when the plan cannot be safely executed without resolving them.

Captured-obligation rule (P2-D-20 worker severity rule):

- If an issue is already captured by a concrete acceptance row, manual scenario, or remaining implementation obligation, and it does not hide a new decision, unsafe gate, source-of-truth conflict, or wrong next action, prefer `non-blocking` in `full-panel` mode and omit it in `blocking-only` mode.
- Do not lower severity without an explicit acceptance row, manual scenario, or remaining implementation obligation that names the verification hook.
- Continue to emit `blocking` or `decision-needed` when the issue exposes a user/product/operating-policy choice, unsafe stage gate, source-of-truth conflict, or wrong next action.
- Do not use caller-side triage labels such as `transferred-obligation`; the caller/reconcile owns routing captured obligations to write-tests or implement-code.

## Review Modes

The caller owns scope and severity selection. The invocation contract uses two split keys (per Child A `prc-A-worker-docs` lock — full wire format defined in § Focus text structured prefix below): `review_scope` ∈ `full | delta`, and `review_severity` ∈ `full-panel | blocking-only`. The legacy single-key `review_mode` enum is deprecated; callers MUST emit the split keys.

### `review_severity = full-panel`

- Within the selected `review_scope`, review through all seven lenses.
- Emit `blocking`, `decision-needed`, and `non-blocking` findings.
- This is the legacy/default behavior only when no structured prefix is present. If a structured prefix is present, missing or invalid `review_severity` is a malformed directive finding.

### `review_severity = blocking-only`

- Within the selected `review_scope`, review through all seven lenses.
- Emit only `decision-needed` and `blocking` findings; suppress `non-blocking` entirely under this directive.
- Do not emit wording, readability, stale-header, or maintainability findings that are only `non-blocking`.
- Do not emit captured-obligation details that the caller can route to write-tests or implement-code. Omission is not a resolved/unresolved judgment.
- Still cover all seven lenses. In structured-output mode, include every lens in `lens_results[]`; use `status="no_findings"` for a reviewed lens with no emitted blocking / decision-needed finding, and `status="n_a"` only when the lens is not applicable. In legacy free-form mode, include all seven lens sections and use `_N/A - <reason>` only for a non-applicable lens.

### `review_scope = delta`

- Review only the caller-provided `delta_scope`.
- Valid `delta_scope` names the changed areas (drawn from the 7-area canonical underscore enum below), affected plan paths, or affected closure ids; use the caller's wording when reporting evidence.
- Do not expand to full-plan review on your own.
- If `review_scope=delta` is requested but `delta_scope` is missing or too vague to identify the review surface, emit a finding titled `Delta scope missing or insufficient` and do not perform full-plan review as a fallback.
- Findings outside the provided scope should not be emitted unless they directly invalidate the scoped change.

### Combined `review_scope=delta` + `review_severity=blocking-only`

The two directives are orthogonal. When the caller emits both, apply scope limiting and severity suppression in one pass: limit the review surface to `delta_scope.changed_areas` AND emit only `decision-needed` / `blocking` findings within that scope.

Closure maps, when provided via `closure_map_path`, are context for identifying related decisions. They are not an answer key. Do not silence a new contradiction merely because a closure exists, and do not triage whether a finding is a closure violation or remaining implementation obligation.

## Path note

Plan paths are under `plan/families/`. Check artifacts are under `plan/check/`. The worker does not write artifacts in either location. Legacy `docs/*` paths are recorded only in `plan/LEGACY_PATH_MAP.md` for historical reference.

## Focus text structured prefix — caller contract (Child A `prc-A-worker-docs` lock)

The caller (Claude `plan-review`) encodes invocation parameters as a structured first-line directive embedded in the focus text. The companion CLI wraps the focus text inside a `User focus: {{USER_FOCUS}}` block; the worker locates the directive via **substring search** inside the companion-wrapped prompt (raw line 1 assumption forbidden — the wrapper is not the raw line, and other companion wrapping may surround the directive).

### Prefix marker

Literal: `<<<plan-review>>>`. The worker scans the companion-wrapped prompt for this substring; when present, it parses the trailing `key=value` pairs on the same line as the marker.

### Static fixture sample (companion-wrapped form — `review_scope=delta`, `review_severity=full-panel`)

```
User focus: <<<plan-review>>> review_scope=delta review_severity=full-panel delta_scope=changed_areas:parent_boundary,acceptance_test;affected_plan_paths:<project-root>/plan/families/child.md closure_map_path=<project-root>/plan/families/parent.md recovery_mode=auto
```

The worker reads the wrapper as-is and applies substring search for `<<<plan-review>>>` inside it; the `User focus:` prefix is the companion's own wrapping and is not the raw line 1 of the caller's focus text payload.

### Static fixture sample — combined `review_scope=delta` + `review_severity=blocking-only`

```
User focus: <<<plan-review>>> review_scope=delta review_severity=blocking-only delta_scope=changed_areas:parent_boundary closure_map_path=<project-root>/plan/families/parent.md recovery_mode=auto
```

### Static fixture sample — `review_scope=full` + `review_severity=blocking-only`

```
User focus: <<<plan-review>>> review_scope=full review_severity=blocking-only closure_map_path=<project-root>/plan/families/parent.md recovery_mode=manual
```

### Structured directive prefix contract (4 mandatory keys + conditional `delta_scope`)

The structured directive prefix has five contract keys. Four are required whenever the prefix is present (`review_scope`, `review_severity`, `closure_map_path`, `recovery_mode`). `delta_scope` is required only when `review_scope=delta` and forbidden when `review_scope=full`. Provenance values are not directive-prefix keys; they live in the wrapper-computed provenance block described in § Output Transport.

| key | values | role |
|---|---|---|
| `review_scope` | `full` \| `delta` | review surface selector (split key 1 of 2) |
| `review_severity` | `full-panel` \| `blocking-only` | severity threshold selector (split key 2 of 2) |
| `delta_scope` | semicolon+colon canonical encoding (see below) | mandatory only when `review_scope=delta`; forbidden when `review_scope=full` |
| `closure_map_path` | absolute path to the parent plan | closure context source (PRC-D-03 lock — see worker obligations below) |
| `recovery_mode` | `auto` \| `manual` | caller-side reconcile routing hint (read-only for the worker — PRC-D-04 always-explicit lock) |

### `delta_scope` canonical encoding

- Top-level fields separated by semicolon (`;`); within each field, list values separated by colon-prefixed pairs `key:value1,value2,...`.
- `changed_areas` field is **mandatory**; values MUST be drawn from the canonical 7-area underscore enum: `parent_boundary` / `source_of_truth` / `child_responsibility` / `acceptance_test` / `operator_visible_behavior` / `stage_gate` / `closure_map_semantics`.
- Optional fields: `affected_plan_paths` (absolute paths), `affected_closure_ids`.
- Non-canonical area name or malformed (semicolon/colon grammar violation) encoding → emit an F-NNN finding for the malformed scope; do not silently expand to full-plan review.

### Directive application

- Prefix present + missing or invalid required key: emit a malformed directive finding. Do not silently apply a default.
- `review_scope=delta`: limit the review to the areas named in `delta_scope.changed_areas` (the 7-area canonical enum). Do not emit findings outside the scoped areas unless they directly invalidate the scoped change.
- `review_severity=blocking-only`: suppress `non-blocking` severity entirely; emit only `decision-needed` and `blocking`. (Compatible with the P2-D-20 captured-obligation rule above — see § P2-D-20 compatibility below.)
- combined `review_scope=delta` + `review_severity=blocking-only`: scope limiting and severity suppression apply simultaneously (scope 제한 + severity suppress 동시 적용; review surface limited AND non-blocking suppressed in one pass).
- `recovery_mode`: read-only — the worker does NOT perform recovery routing; the caller-side reconcile owns it (PRC-D-04 always-explicit lock).

### `closure_map_path` worker obligations (PRC-D-03 lock — 4 sub-obligations, all mandatory)

1. **Mandatory + absolute path + parent plan target**: the value is mandatory whenever the structured prefix is present, MUST be an absolute path, and MUST point to the parent plan itself (PRC-D-03 lock — non-parent-plan target is a caller-side reject before the worker ever sees the call).
2. **`## Closure map` section extraction only**: the worker reads the file at `closure_map_path` and extracts only the `## Closure map` section as closure context; other sections of the parent plan are ignored for the closure-context purpose.
3. **Context-only usage**: the closure map is consumed as context for spotting closure-related contradictions; the worker does NOT triage closure violations vs. remaining obligations (caller-side `plan-reconcile` owns triage).
4. **Missing / unreadable error handling — no silent ignore**: when the path is missing, non-absolute, unreadable, or lacks `## Closure map`, the worker emits an explicit warning finding (e.g., `closure_map_path file missing` produces a missing-file warning finding; `closure_map_path file unreadable` produces an unreadable-file warning finding); the review itself proceeds without closure context.

Semantic behavior and provenance behavior are separate. For semantic review, read `closure_map_path` and extract only `## Closure map`. For provenance, echo `expected_closure_map_sha256` from the wrapper-computed provenance block; do not hash the extracted section and do not hash the file yourself.

### Prefix-absent fallback (worker boundary — PRC-D-08 cross-reference)

- **Prefix present**: substring search inside the companion-wrapped prompt finds `<<<plan-review>>>` → parse the structured directive prefix (4 mandatory keys plus conditional `delta_scope`) + apply the directives above.
- **Prefix absent**: substring search returns no match → fall back to **legacy free-form prose** processing (the review proceeds against the focus text as ordinary natural-language prose; prefix absence itself emits no finding).
- **The worker does NOT decide territory** (active vs bootstrap):
  - The worker does not consume audit markers, status-trail entries, or the `child_B_implement_completed` parent plan entry as input.
  - The worker cannot tell whether prefix absence is an active-territory bug or an intentional bootstrap-territory call.
  - Active-territory + prefix-absent reject is the caller-side preflight gate's responsibility (`plan-review` caller-side preflight gate); those calls are blocked before they reach the worker.
  - Bootstrap-territory calls (PRC-D-08 active) intentionally use a legacy free-form prose template without the prefix — the worker handles them via the same fallback branch. PRC-D-08 (Bootstrap exception) is a closure on the caller side; the worker is unchanged across territories.

### P2-D-20 compatibility

The `review_severity` directive and the P2-D-20 captured-obligation rule (§ Severity above) are orthogonal. The directive sets the emit threshold (`blocking-only` suppresses the entire `non-blocking` tier), while P2-D-20 classifies which findings within the emitted tier earn `non-blocking`. Under `review_severity=blocking-only`, P2-D-20-classified `non-blocking` findings are suppressed (consistent with P2-D-20's explicit "omit in `blocking-only` mode" clause). The directive does not override P2-D-20 classification; P2-D-20 classification operates within whatever threshold the directive permits.

## Lenses

### CTO / Problem-Definition

Explicitly check all five CTO checklist items. In structured-output mode, a checklist item is sufficiently covered only when the answer is supported by evidence in the parent plan body or inline caller-provided context. Parent-plan citations to code, tests, root docs, or ADRs may be cited as unverified plan claims, but do not open those files. If answering an item requires inference or external validation beyond the parent plan and inline context, treat it as a material gap and emit an F-NNN finding.

- User scenario: identify what user, operator, or external trigger raises the problem this plan addresses.
- Case completeness: check whether all relevant cases are listed and whether any missing case could change the work.
- Current handling: check how the current code, docs, or operating process handles this situation today.
- Side effects: check what behavior, workflow, policy, or maintenance side effects the proposed solution may introduce.
- Design decision resolution: check whether unresolved product, architecture, or operating-policy choices are surfaced for user decision instead of being silently chosen.

For each checklist item:

- If the item has a material gap, emit an F-NNN finding and name the checklist item in the title or issue.
- If the item is sufficiently covered with adequate evidence, do not emit a finding for that item.
- If all five items are sufficiently covered, treat the CTO / problem-definition lens as reviewed with zero findings, not as non-applicable:
  - In structured-output mode, set that lens entry to `status="no_findings"`, `finding_ids=null`, and `reason=null`.
  - In legacy free-form mode, leave the section empty or write `_(no material findings)_` for readability.
  - Do not use `_N/A - <reason>` for this case; `n_a` is reserved for a lens that is not applicable to the plan.

When CTO / problem-definition and another lens flag the same evidence, both lenses should emit their own F-NNN finding. The caller merges across lenses by shared evidence anchor; do not pre-merge findings in worker output.

### Implementer

- Check whether an implementer can proceed without making new product or architecture decisions.
- Verify the runnable work unit, dependencies, scope boundaries, validation target, and completion checks.

### Operator

- Check operational commands, stop gates, expensive operational/pipeline commands, and user-confirmation gates.
- Confirm the plan does not appear to reopen policy it identifies as already locked in the repository operating-policy document; in structured-output mode, evaluate the parent plan's cited policy relationship without opening the policy file unless the caller supplied its contents inline.

### QA

- Check that automated and manual validation match the actual change surface.
- Flag unclear pass/fail criteria, regression risk, and unexplained skipped validation.

### Maintainer

- Check whether the parent plan establishes and cites source precedence in the expected order: code/tests, root docs, ADRs, then local planning docs. In structured-output mode, do not read those sources directly; flag missing or unverifiable source evidence when the plan does not provide enough context.
- Flag risks to architectural boundaries or repository operating rules.

### Docs Usability

- Check whether a future worker or non-developer can find current status and the immediate action quickly.
- Verify umbrella/child links, status blocks, terms, and out-of-scope language.

### Risk / Rollout

- Check runtime state, migrations, partial failures, rollback limits, and approval needs.
- Flag retire/delete/sync actions without explicit safety gates.
