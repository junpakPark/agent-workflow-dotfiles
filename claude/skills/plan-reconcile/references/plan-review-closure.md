# Plan Review Closure-First Reconciliation Reference

This reference complements `SKILL.md`. It defines the exact formats and templates for closure-first reconciliation on **plan review artifacts only**. The code-quality artifact path is unchanged — see `reconcile.md` for that flow.

## v2 Compatibility Header (docs-plan v2)

The body below originated in v1 docs-plan and is reused verbatim for v2
`plan-reconcile`. Read this header alongside the body to translate v1
references into v2 vocabulary.

- `## Status` vocabulary, single-writer rule, and gates: the canonical
  source is now the [plan-protocol reference](../../plan-protocol/references/plan-protocol.md).
  Where this body and the protocol disagree on a closed-set marker or
  gate condition, the protocol wins.
- New family-level markers (`code-quality-ready`, `refactor-needed`,
  `code-quality-blocked`) and new child-transition markers
  (`child_<id>_plan_locked`, `child_<id>_plan_revision_required`,
  `child_<id>_tests_started`, `child_<id>_blocked`) are defined in
  protocol § 2.
- Writer ownership shifts in v2: Codex `exec-run` writes most
  child-transition markers; Claude `plan-reconcile` writes
  `parent_review_converged`, `policy-locked`, `decision-blocked`,
  `decision-resolved`, `child_<id>_plan_revision_required`, and
  `child_<id>_frozen`. See protocol § 2 single-writer table.
- Legacy markers `child_<id>_ready` and `child_<id>_review_converged`
  are recognized in read-paths only; new writes use the v2 values.
- The child-ready gate from v1 lifecycle is renamed to
  `child-plan-locked` in v2 protocol § 4.2; the body of that gate now
  lives in the protocol, not in lifecycle.
- `child_<id>_plan_revision_required` is valid **only** when the child
  plan contract itself must change (acceptance / scope / source-of-
  truth). Test-only and manual-only repeats never produce this marker;
  see protocol § 8 recurrence routing.
- Code-quality result writing moved to Codex `exec-code-quality`.
  Reconcile no longer writes `## Code-quality result` in v2; reconcile
  only handles escalation cases (decision-needed / closure violation /
  plan-blocker) from `exec-code-quality`.
- Child Full Panel review/reconcile is removed from the canonical v2
  path. Child plan reviews use Codex `draft-review` + Claude
  `draft-intent-worker` and produce `child-checkpoint.v1` JSON, not an
  F-NNN artifact. The body below's "child reconcile" references apply
  only to the legacy/explicit-only path.

When citing this file from a v2 skill, prefer the protocol reference
for vocabulary and gates and use this file only for the closure /
decision-needed / forbidden-wording / remaining-obligation / triage
detail that has not moved.

## Closure Map Format

Family-level closures live in the **parent plan's `## Closure map`** section. Child plans reference closure ids and may track child-local remaining obligations only — they must not record family-level closure body content.

Each Decision uses the following 9-field form:

```markdown
### D-NNN: <decision title>
- source of truth: <one of>
  - `docs/operating-policy.md` — operator contract / runtime policy
  - `docs/adr/<file>.md` — architecture decision
  - `parent invariant + acceptance test` — implementation contract
  - `parent closure-only` — local sequencing / runbook decision
    (small scope, no impact on other families)
- allowed wording: <wording guide / canonical phrases>
- forbidden wording: <bullet list of phrases that must not appear>
- remaining implementation obligations:
  - [ ] <obligation 1>
  - [ ] <obligation 2>
- affected child docs: <list of child plan paths>
- decided cycle: <YYYY-MM-DD or cycle marker>
- evidence: <commit / file / link>
```

Required fields (all 9): `decision id`, `title`, `source of truth`, `allowed wording`, `forbidden wording`, `remaining implementation obligations`, `affected child docs`, `decided cycle`, `evidence`.

In Parent Plan 1, the closure map is a **single active list**. The active/archived split and automatic archived-section freezing are Parent Plan 2 candidates.

## Closure Registration Scope

Register a `D-NNN` closure when the accepted finding locks a parent-level decision:

- a policy
- a contract
- a boundary (port / module / responsibility split)
- a source-of-truth mapping
- a cross-child invariant

Do not register a closure for purely localized body fixes (typo, ambiguity, structural improvement) that do not change a parent decision. When uncertain, prefer registering a closure — closures cost little and prevent same-topic re-debate.

## Decision-Needed Stop Rule (Plan Review)

When a finding is classified `need-user-decision` for a plan review artifact, reconcile enters `decision-blocked` and **does not**:

- create a new official review artifact
- edit the contract / proposal body in the decision-needed area (the policy/contract text being decided about)
- close findings
- transition any child stage (`write-tests`, `implement-code`, `code-quality`, `closeout`, `archive`)

Reconcile **may**:

- perform read-only evidence checks (code, tests, tracked root docs, ADRs, operating-policy document, prior review artifacts) to refine the question
- write a `user-question artifact` in **append-only** form to either:
  - a `## Decision Block` section in the same plan (append-only — never edit or delete prior entries), or
  - a `plan/check/*` handoff artifact

## User-Question Artifact Template

```markdown
## Decision Block

### D-NNN-question: <one-line question>
- blocked issue: <one-line summary>
- context: <relevant background>
- checked evidence: <files / lines / tests>
- why repo evidence does not settle: <why repo evidence does not settle>
- options:
  1. <option A> - effect: <impact>
  2. <option B> - effect: <impact>
  (3. <option C> - effect: <impact>)
- recommendation: <one of the options + rationale>
- operator-facing summary: <plain-language summary>
```

Required fields (all 9): `D-NNN-question` id, `blocked issue`, `context`, `checked evidence`, `why repo evidence does not settle`, `options` (2-3 options), `recommendation`, each option's effect line, `operator-facing summary`.

## Decision-Needed Close Condition

A `need-user-decision` finding is **closed only when both** of the following exist:

1. a recorded user response (e.g. a `## User decision (YYYY-MM-DD)` subsection appended under the question artifact, naming the chosen option and rationale)
2. a corresponding `D-NNN` closure entry registered in the parent plan's `## Closure map`

Until both exist, the finding remains unresolved and reconcile is `decision-blocked`. **Closing only one of the two is forbidden** — reconcile must not silently apply the user's answer without registering a closure, and must not register a closure without a recorded user response.

## family_status Section

family-level state lives in the parent plan's `## Status` section, append-only:

```markdown
## Status

- 2026-05-07 — `family_status: parent_review_converged`
- 2026-05-07 — `family_status: child_d_draft_started`
- 2026-05-07 — `family_status: decision-blocked`
  (waiting on D-NNN-question)
- 2026-05-07 — `family_status: decision-resolved`
```

Each entry is a new line. **Never edit or delete prior entries** — corrections are made by appending a new entry.

### Writer ownership

Every entry in the parent plan's `## Status` section is appended by the stage skill whose transition it represents. `plan-run` / `exec-run` routing is **read-only** for `## Status` — it consumes the latest entry to gate stage transitions but does not write entries. This avoids any circular dependency where lifecycle both checks a gate and writes the gate-pass marker.

For the values defined in this reference (decision-needed handling), reconcile is the writer:

- `family_status: decision-blocked` — appended by reconcile the moment a `need-user-decision` finding is raised on a plan review artifact.
- `family_status: decision-resolved` — appended by reconcile **only when both** close conditions hold (recorded user response + corresponding `D-NNN` closure entry registered). This is the canonical release marker; lifecycle gates that were blocked by `decision-blocked` lift only after this exact entry appears.

Other `family_status` values (gate-pass markers, stage-transition markers, child-frozen, etc.) and their writer ownership are locked by the parent plan's family_status vocabulary closure (registered by Child A — `P1-D-10`). Cross-file drift between this reference and that closure is itself a closure violation.

### `## Status` Section Fallback

If the parent plan has no `## Status` section, reconcile **appends a new `## Status` section to the end of the plan** and adds the first entry. Creating a new section by appending is not a body contract modification — it adds new content without altering existing contract text.

Mandating `## Status` at parent draft time is `plan-draft` (Child B) responsibility — not handled here.

## Forbidden Wording Self-Check

After registering or updating a `D-NNN` closure with a `forbidden wording` list, reconcile self-checks the forbidden wording before closing reconciliation.

Check spans **three scopes**:

1. parent plan body, **excluding the `## Closure map` section itself**
2. all child plans listed in the closure's `affected child docs` field
3. the current reconcile target plan

The `## Closure map` section is excluded because it contains the forbidden wording **definitions** themselves (under each Decision's `forbidden wording:` field). Matching the definition string against itself is a meta-mention, not a violation. The same rule extends to any prose elsewhere that quotes a forbidden wording for the explicit purpose of *defining or referencing* it (e.g., a closure-violation log entry citing the matched phrase) — meta-mentions are not violations; only *uses* of the forbidden phrase as if it were canonical wording are.

If any forbidden wording matches in any of the three scopes:

- reconcile appends an entry to its trail of the form `closure-violation: D-NNN — <match location>`
- reconcile **does not** create a new review artifact
- reconcile **does not** close

Reconcile remains open until violations are resolved (by editing the matching plan body to the allowed wording, or by parent-escalate revisiting the closure itself).

In Parent Plan 1 this self-check is **manual** — the reconciler runs the grep equivalent. Automation (e.g. diff-time grep, CI hook) is a Parent Plan 2 candidate.

## Remaining Obligation Tracking

Each `D-NNN` closure may carry a `remaining implementation obligations` checklist. The closure is closed when the policy decision is locked, **not when the obligations are complete**.

After closure:

- the obligation checklist remains visible in the closure entry
- a future review may find a gap that maps to an unchecked obligation
- reconcile classifies that gap as a **remaining-obligation finding**, not a re-opened policy question
- reconcile updates the checklist (checks off completed items, leaves incomplete ones) and **does not re-open the closure**

This keeps the `## Closure map` stable while implementation work continues against tracked obligations.

## Triage Classifications (P2-D-20 lock)

Reconcile triage routes every (merged, validated) F-NNN entry into one of four categories — locked by Parent Plan 2 P2-D-20. The full definitions, the four conditions for `transferred-obligation`, the anti-bypass invariant for user-decision findings, and the `blocking-only` × `transferred-obligation` interaction live in [`../SKILL.md`](../SKILL.md) § Step 5 Triage. This reference does not redefine those rules — drift is itself a closure violation.

Summary (the SKILL.md is authoritative — these are pointers):

- `plan-blocker` — plan body / closure / status edit required now. Triggers material-change review re-run when an edit changes any of the seven areas.
- `decision-needed` — repo evidence cannot settle a real decision. Close condition: user response + closure registered (both).
- `transferred-obligation` — finding's verification is already captured by a specific acceptance row / manual scenario / remaining implementation obligation, and the four P2-D-20 conditions all hold. Reconcile trail must record the mapping. Not unresolved; not a material-change re-run trigger; counted as remaining work in child-ready evaluation.
- `reject` / `backlog` — invalid evidence (`reject`) or out-of-scope improvement (`backlog`).

`transferred-obligation` may not be used to close a user-decision finding (P2-D-20 anti-bypass invariant — drift is a closure violation).

## Triage Input Forms

### Canonical v2 input (the only shape produced by the docs-plan v2 wrapper)

In docs-plan v2 with the Codex CLI structured-output transport, the Codex `plan-review-worker` emits a `parent-plan-review.v1` JSON payload (validated against the shared schema by `codex exec --output-schema`); the Claude `plan-review` wrapper then **deterministically renders that JSON into the `## Codex output` F-NNN Markdown without merging across lenses**. Every entry in `## Codex output` is therefore a **raw single-lens F-NNN block** with exactly the five mandatory sub-field lines below (in this order) — the shape below is the *only* shape v2 produces and matches `plan-review/SKILL.md` § "Structured-JSON → F-NNN Markdown Rendering" rule 4 verbatim. An entry missing any of these five sub-fields is rejected as a Category B malformed-v2 artifact (see `plan-review/SKILL.md` § "Bad Artifact Rejection (no-op adversarial + malformed v2)" § Category B).

```
#### F-001 [blocking] <issue>
- source lens: Implementer
- issue: ...
- why it matters: ...
- evidence: ...
- suggested action: ...
```

Per `plan-review/SKILL.md` § "Structured-JSON → F-NNN Markdown Rendering" rule 6: "The rendering does NOT merge across lenses." Cross-lens normalization (merge / split / parent-escalate / closure-related annotation) is `plan-review`'s post-processing responsibility and is surfaced in the artifact's **optional `## Normalized findings` section**, which is **display-only**. Reconcile MUST consume `## Codex output`, NOT `## Normalized findings`. The wrapper-rendered `## Codex output` is the sole canonical reconcile input in v2.

In v2, reconcile triage therefore:

- Reads only `## Codex output`;
- Treats every entry as a raw single-lens F-NNN block (the shape above);
- Performs cross-lens merging itself at triage time when two single-lens entries clearly describe the same evidence anchor (i.e., reconcile does the merging, not the worker, and not the wrapper renderer);
- Ignores `## Normalized findings` entirely for triage decisions (the wrapper guarantees that, if `## Normalized findings` disagrees with `## Codex output`, the rendering wins and `## Normalized findings` is regenerated — see `plan-review/SKILL.md` § "Artifact Layout").

### Legacy `normalized F-NNN` shape (pre-v2 artifacts only — NOT produced by v2)

Some archived pre-v2 artifacts (and any artifact still being parsed for migration purposes) may carry a merged shape with a `contributing lenses:` field instead of `source lens:`, e.g.:

```
#### F-001 [blocking] <issue>
- contributing lenses: implementer, maintainer
- issue: ...
- evidence: ...
- suggested action: ...
```

This shape is **legacy-only**. The v2 wrapper does NOT emit this shape into `## Codex output`. If reconcile encounters a `contributing lenses:` line in a v2 artifact, that artifact is malformed and triage stops as a contract violation (it matches Category B — Malformed v2 `## Codex output` shape signatures — under `plan-review/SKILL.md` § "Bad Artifact Rejection (no-op adversarial + malformed v2)", and the same atomic-archive-then-rerun recovery applies; the v2 deterministic rendering contract guarantees one `source lens:` line per F-NNN entry, not a `contributing lenses:` aggregate). Legacy-shape tolerance exists only for reading **pre-v2 archived** artifacts during migration and MUST NOT be a path for accepting merged content from current v2 review runs.

## Cross-File Drift Rule

The closure / decision-needed / user-question / forbidden wording / remaining obligation / triage input rules in this reference must stay in sync with the corresponding section in `SKILL.md`. When changing either, update the other.

Drift between `SKILL.md` and this reference is itself a closure violation (treat as forbidden wording match) and must be resolved before reconcile closes.

## Material Change → Delta Review (Caller Contract)

The seven material-change areas, the obligation to re-invoke `plan-review` with explicit `review_scope` + `review_severity` + `delta_scope` (the v2 split-key contract — the legacy single-key `mode` is deprecated; `delta_scope` is required only when `review_scope = "delta"`) when any area changed, the prohibition on reconciler self-judgment skipping the re-review, the `recovery_mode` parameter (`auto | manual`, caller-side explicit passing for all four mandatory keys including `recovery_mode`, no default fallthrough, no silent normalization of missing keys), the auto recovery four-step path, the manual recovery path (caller / operator explicit invocation only — no automatic transition from auto), and the retry artifact policy = archive (move all three guarded files `<basename>-review.md` / `<basename>-review.md.pending` / `<basename>-review.failed.md` to `<check_dir>/archive/<cycle-id>/` before re-invocation; partial archive is forbidden; attempt-suffixed paths are not used) live in [`../SKILL.md`](../SKILL.md) § "Material Change → Delta Review (Caller Contract)" + § `recovery_mode` parameter + § Retry artifact policy. This reference does not redefine those rules. Wrapper-side (Claude `plan-review`) scope-aware behavior — the structured prefix (4 mandatory keys plus conditional `delta_scope`; full-scope calls emit 4 keys on the wire, delta-scope calls emit 5), caller-side preflight rejection of malformed `review_scope` / `review_severity` / `delta_scope` combinations, and the archive-then-rerun expectation at re-invocation — lives in [`../../plan-review/SKILL.md`](../../plan-review/SKILL.md) § "Focus Text Prefix Contract" (preflight rejects) and § "Caller-side Scope-aware Contract" (reconcile-owned `delta_scope` derivation). Worker-side scope-aware behavior — directive parsing of the structured prefix (4 mandatory keys plus conditional `delta_scope`), `delta_scope` canonical encoding consumption, and the emission of a `Delta scope missing or insufficient` finding when `review_scope = "delta"` is sent without a parseable `delta_scope` — lives in the Codex worker reference at `codex/skills/plan-review-worker/references/review.md` § "Focus text structured prefix" / § "Review Modes". Drift between any of those is a closure violation.

## M-A2 material change automated classifier (Child A — source of truth: SKILL.md)

The material change automated classifier inserted into the `Material Change -> Delta Review` self-check (Child A M-A2) — including the input set (plan diff + closure map diff + accepted finding's suggested action), the output (7-area change candidates with evidence anchors per area: diff line / closure id / accepted finding id), the reconciler-final-judgment invariant (the classifier is input only; reconciler manual self-check stays the final decision per P1-D-16 self-judgment-skip lock), and the false-positive handling (reconciler may reject classifier output with reason recorded in trail) live in [`../SKILL.md`](../SKILL.md) § Reconcile automation procedures (Child A M-A1 / M-A2 / M-A3 / M-A4) § M-A2. This reference does not redefine those rules — drift between SKILL.md and this reference is itself a closure violation.

## M-A3 decision-needed bypass detection (Child A — source of truth: SKILL.md)

The decision-needed bypass automated detection grep inserted into the reconcile workflow (Child A M-A3) — including the insertion point (immediately after step 5 Triage and before step 6 Apply, preserving abort-before-write and no-write preflight), the procedure (enumerate active decision-needed areas from Decision Block § P2-D-NNN-question / P1-D-NNN-question entries -> grep the plan diff against the latest baseline -> emit a closure violation finding -> enter reconcile decision-blocked immediately -> block entry to step 6), the no-write preflight invariant (failure means no plan body edit occurred), the P1-D-04 stop rule body preservation (grep input only; no stop-rule body change), and the false-positive handling (reconciler may manually classify unrelated plan diffs as false positives with an explicit reason) live in [`../SKILL.md`](../SKILL.md) § Reconcile automation procedures § M-A3. This reference does not redefine those rules — drift between SKILL.md and this reference is itself a closure violation.
