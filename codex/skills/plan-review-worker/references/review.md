# Plan Review Worker Reference

## Contents

- [Output Contract](#output-contract)
- [Severity](#severity)
- [Review Modes](#review-modes)
- [Focus text structured prefix](#focus-text-structured-prefix)
- [Lenses](#lenses)

## Output Contract

Return the seven lens sections in this order:

1. CTO / problem-definition review
2. Implementer review
3. Operator review
4. QA review
5. Maintainer review
6. Docs usability review
7. Risk / rollout review

Each material finding must use this exact shape:

```markdown
#### F-NNN [severity] <one-line title>
- source lens: <one lens name>
- issue: <what is unclear, incomplete, unsafe, or contradictory>
- why it matters: <practical effect>
- evidence: <file:line, quoted plan heading, code path, doc path, or explicit missing evidence>
- suggested action: <one short action for the caller>
```

Rules:

- Number findings in source-doc order across the whole output, starting at `F-001`.
- Use exactly one severity: `blocking`, `decision-needed`, or `non-blocking`.
- Keep duplicate observations from different lenses separate when they come from different lens concerns.
- Use `_N/A - <reason>` for any lens with no applicable finding.
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
- Still include all seven lens sections, using `_N/A - <reason>` where there is no emitted finding.

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

### 5-key prefix contract

The structured prefix has five keys. Four are required whenever the prefix is present (`review_scope`, `review_severity`, `closure_map_path`, `recovery_mode`). `delta_scope` is required only when `review_scope=delta` and forbidden when `review_scope=full`.

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

### Prefix-absent fallback (worker boundary — PRC-D-08 cross-reference)

- **Prefix present**: substring search inside the companion-wrapped prompt finds `<<<plan-review>>>` → parse the 5-key contract + apply the directives above.
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

Explicitly check all five CTO checklist items. A checklist item is sufficiently covered only when the answer is supported by evidence in the plan body, cited code/tests, or root tracked docs. If answering an item requires inference beyond documented evidence, treat it as a material gap and emit an F-NNN finding.

- User scenario: identify what user, operator, or external trigger raises the problem this plan addresses.
- Case completeness: check whether all relevant cases are listed and whether any missing case could change the work.
- Current handling: check how the current code, docs, or operating process handles this situation today.
- Side effects: check what behavior, workflow, policy, or maintenance side effects the proposed solution may introduce.
- Design decision resolution: check whether unresolved product, architecture, or operating-policy choices are surfaced for user decision instead of being silently chosen.

For each checklist item:

- If the item has a material gap, emit an F-NNN finding and name the checklist item in the title or issue.
- If the item is sufficiently covered with adequate evidence, do not emit a finding for that item.
- If all five items are sufficiently covered, end the CTO / problem-definition section with this exact line:

```text
_N/A - all five CTO checklist items are covered with adequate evidence
```

When CTO / problem-definition and another lens flag the same evidence, both lenses should emit their own F-NNN finding. The caller merges across lenses by shared evidence anchor; do not pre-merge findings in worker output.

### Implementer

- Check whether an implementer can proceed without making new product or architecture decisions.
- Verify the runnable work unit, dependencies, scope boundaries, validation target, and completion checks.

### Operator

- Check operational commands, stop gates, expensive operational/pipeline commands, and user-confirmation gates.
- Confirm the plan does not reopen policy already locked in the repository operating-policy document, when one exists.

### QA

- Check that automated and manual validation match the actual change surface.
- Flag unclear pass/fail criteria, regression risk, and unexplained skipped validation.

### Maintainer

- Check source precedence: code/tests, root docs, ADRs, then local planning docs.
- Flag risks to architectural boundaries or repository operating rules.

### Docs Usability

- Check whether a future worker or non-developer can find current status and the immediate action quickly.
- Verify umbrella/child links, status blocks, terms, and out-of-scope language.

### Risk / Rollout

- Check runtime state, migrations, partial failures, rollback limits, and approval needs.
- Flag retire/delete/sync actions without explicit safety gates.
