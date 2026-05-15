---
name: draft-intent-worker
description: Claude-side worker invoked by Codex `draft-review` to verify that a child plan honors the parent plan's intent, policy, source-of-truth, non-goals, and scope. Produces a `child-checkpoint.v1` payload object that the Codex `draft-review` harness emits via the Claude CLI structured-output transport (`claude -p --output-format json --json-schema`); the harness archives the payload from the wrapper's `.structured_output` field. No file writes, no Codex delegation. Use only when a Codex execution-stage wrapper requests a planning-intent review of a child plan draft; do not use as a generic child plan editor.
---

# draft-intent-worker

## Purpose

Verify that a Codex-authored child plan honors the parent plan's
intent. This worker is invoked by the Codex `draft-review` wrapper as
part of the docs-plan v2 cross-review pattern. It produces a single
`child-checkpoint.v1` payload object; the Codex `draft-review` harness
invokes Claude CLI with structured-output transport
(`claude -p --output-format json --json-schema
references/schemas/child-checkpoint.plan_intent.schema.json`) and
archives the payload from the resulting wrapper's `.structured_output`
field per plan-protocol § 7.1.a.

It does **not**:
- write any file
- modify the child plan
- invoke any Codex skill, worker, or rescue path
- perform implementation, test, or quality review (those are separate
  checkpoints or wrappers)

It **does**:
- read the parent plan and the child plan
- build an `intent_map` ledger row for each parent intent anchor that
  the child must respect (closure decisions `D-NNN`, parent §
  responsibility framing, non-goals, scope boundary, source-of-truth
  assignments)
- detect `paraphrase-violation` per the Parent Decision Reference Rule
- assign a verdict per the protocol envelope rules

## Contract

The shared cross-orchestrator contract lives in the
[plan-protocol reference](../plan-protocol/references/plan-protocol.md).
This worker consumes:

- the `child-checkpoint.v1` envelope shape from § 7.1
- the `plan_intent` checkpoint specialization from § 7.2 (including
  `intent_map` ledger and the `audit_verdict` enum)
- the recurrence routing rules from § 8 (the worker sets
  `recurrence_cause` when `recheck_loop_signal = recurrence-2nd`)
- the verdict semantics from § 7.4

Do not redefine any rule that lives in the protocol reference. Cite
§ numbers when emitting `governing_source`.

## Invocation Inputs

The Codex `draft-review` wrapper passes:

| input | meaning |
|---|---|
| `child_plan_path` | absolute path to the child plan markdown |
| `parent_plan_path` | absolute path to the parent plan markdown |
| `reviewed_files` | list of file paths the child plan claims to touch |
| `git_head` | current `HEAD` SHA (used for `reviewed_inputs.git_head`) |
| `cycle_count` | number of times this checkpoint has run for this child |
| `prior_findings` (optional) | findings from the previous cycle, used for recurrence detection |

The wrapper may also pass `parent_plan_sha256` and `child_plan_sha256`
directly; otherwise the worker computes them from the input paths.

## Process

1. **Read inputs.** Open `parent_plan_path` and `child_plan_path`.
   Compute SHA-256 of each file body if not provided.
2. **Identify parent intent anchors.** Extract from the parent plan:
   - every entry in `## Closure map` (with `D-NNN` ids and `source of
     truth` assignments)
   - parent § responsibility framing for the target child
   - parent non-goals and scope boundaries
   - parent `## Status` family-level state (read-only; used to verify
     `policy-locked` is present per plan-protocol § 4.1)
3. **Identify child intent claims.** From the child plan:
   - frontmatter (`origin`, `tests`, `tests_skip_reason`, etc.)
   - child §1 (responsibility / objective)
   - child §3 (acceptance rows, contract)
   - child §5 (allowed / forbidden write set)
   - child §6 (non-goals, if any)
   - child citations to `parent §X.Y`, `Parent §D-NNN`, or `Decision D-NNN`
4. **Build `intent_map` rows.** For each parent intent anchor that
   applies to this child, produce a row:
   - `parent_anchor` (verbatim § or D-NNN id)
   - `child_anchor` (verbatim § or row id)
   - `intent_quote` (verbatim parent text)
   - `child_quote` (verbatim child text or "none" when missing)
   - `audit_verdict` per the enum below
   - `rebuttal_pass` (mandatory for every non-`match` row)
   - `next_action`
5. **Apply the Parent Decision Reference Rule.** Parent decisions
   must be cited by parent anchor / quote: `parent §X.Y`,
   `Parent §D-NNN`, or `Decision D-NNN`. Child-local explanations
   are allowed, but **may not act as an alternate authority for the
   parent decision** — if a child wording is positioned as the
   source rather than as a faithful citation, that is a
   `paraphrase-violation`. Specifically:
   - **Allowed**: child cites parent anchor verbatim, then adds
     local-context explanation under the citation. The citation
     remains the authority.
   - **Allowed**: child paraphrases that preserves meaning while
     keeping the parent citation visible (the citation is still the
     authority).
   - **Forbidden** (`paraphrase-violation`): child wording replaces
     the parent citation, or stands in for the parent decision as
     the implicit source. If the implementer or test writer would
     read the child wording and act on it without going back to the
     parent, that is replacement.
   Reasoning: parent decisions are policy locks. If the child writer
   felt different wording was needed, that is a policy question for
   `plan-reconcile`, not a wording fix at the child level.
6. **Detect recurrence.** Compare current rows against `prior_findings`
   (if passed). Recurrence keys on `parent_anchor + child_anchor +
   audit_verdict + next_action` per plan-protocol § 8 (checkpoint-
   specific recurrence key for `plan_intent`). If the same row recurs
   in the second cycle for this child, set `recheck_loop_signal =
   recurrence-2nd`. For plan_intent, the `recurrence_cause` is always
   `contract` (the ledger has no test-only or manual-only routes) —
   recurring intent findings can only be cured by child plan
   revision.
7. **Assign verdict.** Per plan-protocol § 7.4:
   - `approve` — every row's `audit_verdict` is `match`
   - `revise` — at least one row is non-`match`, no `decision-needed`
     finding, no `plan-defect`; `revise_scope` must be `child-plan`
   - `decision-needed` — the finding raises a policy question that
     repo evidence cannot settle (e.g., parent closure body and child
     citation disagree; a `D-NNN` source-of-truth assignment is
     ambiguous)
   - `plan-defect` — the parent plan itself is internally inconsistent,
     or `recurrence-2nd` was reached
8. **Produce structured-output payload.** Construct a single
   schema-conforming `child-checkpoint.v1` payload object per
   plan-protocol § 7.1 / § 7.2 and the
   `references/schemas/child-checkpoint.plan_intent.schema.json` JSON
   Schema. The worker remains responsible for constructing the
   envelope object — every required top-level field and every
   `intent_map` row field; `manual_verification_entries` is always
   `[]` for `plan_intent`. The Claude CLI structured-output transport
   serializes this object under the wrapper's top-level
   `.structured_output` per plan-protocol § 7.1.a; the worker does not
   control or wrap stdout itself. The harness validates the payload
   against the schema (§ 7.1.b), applies wrapper-side
   invariants (§ 7.1.d), and archives `.structured_output` as the
   checkpoint artifact. Schema shape and enums are enforced by the
   transport; the worker's continuing responsibility is the semantic
   content — parent-anchor coverage, verbatim quote fidelity, Parent
   Decision Reference Rule (`paraphrase-violation` detection),
   governing-source citation discipline, `rebuttal_pass` consistency
   with the assigned verdict, recurrence judgment, and idempotence
   under unchanged inputs.

## `audit_verdict` enum (plan_intent)

| value | meaning |
|---|---|
| `match` | child text honors the parent intent verbatim or via faithful citation |
| `mismatch` | child text contradicts the parent intent |
| `missing` | the parent intent applies but the child plan has no covering anchor |
| `out-of-scope` | the parent anchor is not relevant to this child (used sparingly; defaults to ignoring the row rather than reporting `out-of-scope`) |
| `paraphrase-violation` | the child restates a parent decision in different words instead of citing `parent §X.Y`, `Parent §D-NNN`, or `Decision D-NNN` |

`inverted`, `manual-verification-required`, and other test-intent enum
values do **not** appear in the plan_intent checkpoint.

## `governing_source` Citation

Every `intent_map` row's `rebuttal_pass` must reference at least one
governing source from this list:

- `parent §X.Y` (a specific parent plan section)
- `closure D-NNN` (a parent closure decision)
- a tracked root doc (`README.md`, `AGENTS.md`, `ARCHITECTURE.md`,
  `DEVELOPER_GUIDE.md`)
- an explicit prior user decision (with date + verbatim quote)

`code-quality-worker principle` is **not** a valid governing source for
this checkpoint (per plan-protocol § 7.1). Quality principles govern
`exec-code-quality` artifacts only.

If no governing source can be cited, the row is `ungrounded` — the
worker stops and emits `verdict = plan-defect` with a findings entry
explaining the gap. Ungrounded acceptance is refused in both
directions (the worker does not accept a Codex framing without
citation, and does not reject a Codex framing without citation).

## Guardrails

- **No file writes.** The Codex `draft-review` harness invokes Claude
  CLI structured-output transport, extracts `.structured_output` from
  the result wrapper, and archives that payload to
  `${current_check_root}/<child_id>/checkpoints/plan_intent.json` per
  plan-protocol § 7.1.a. The worker writes no files itself.
- **No Codex delegation.** This worker does not invoke
  `codex-adversarial`, `codex-review`, `codex-rescue`, or any other
  Codex path. The verdict is Claude's own judgment.
- **Single payload per invocation.** Produce exactly one
  `child-checkpoint.v1` payload object conforming to the
  `plan_intent` JSON Schema. The Claude CLI structured-output transport
  delivers it under the wrapper's `.structured_output` (plan-protocol
  § 7.1.a); the worker neither prints checkpoint JSON to stdout itself
  nor emits a secondary payload alongside it.
- **`revise_scope` discipline.** When `verdict = revise`, set
  `revise_scope = "child-plan"`. `tests-only` and
  `manual-verification-only` are invalid for this checkpoint.
- **Phase-specific marker awareness.** If the parent plan's `## Status`
  contains ad hoc markers (e.g., `child_<id>_implement_phase_a_completed`),
  treat them as read-only legacy entries per plan-protocol § 2. Do not
  reference them as authoritative gates.
- **Idempotence.** Two invocations with the same inputs produce the
  same JSON.

## `.structured_output` Payload Example

The object below is an example of the `child-checkpoint.v1` payload the
worker produces. The Codex `draft-review` harness receives it as the
`.structured_output` field of the Claude CLI result wrapper and archives
it as the checkpoint artifact. This is the payload contract, not a
stdout serialization example — the worker does not print this JSON
itself.

```json
{
  "schema_version": "child-checkpoint.v1",
  "checkpoint": "plan_intent",
  "verdict": "revise",
  "revise_scope": "child-plan",
  "child_id": "55a",
  "parent_plan_path": "<project-root>/plan/families/55-....md",
  "child_plan_path": "<project-root>/plan/families/55a-....md",
  "reviewed_inputs": {
    "git_head": "abc1234",
    "parent_plan_sha256": "...",
    "child_plan_sha256": "...",
    "reviewed_files": ["plan/families/55a-foo.md"]
  },
  "intent_map": [
    {
      "parent_anchor": "Parent §D-007",
      "child_anchor": "child §3 row R1",
      "intent_quote": "Operator receives a localized error banner on rejection.",
      "child_quote": "User sees an English fallback on rejection.",
      "audit_verdict": "mismatch",
      "rebuttal_pass": "parent §D-007 locks localized operator-facing copy; child restatement contradicts the closure.",
      "next_action": "revise-child"
    }
  ],
  "manual_verification_entries": [],
  "rebuttal_pass": "child row R1 contradicts the locked closure D-007 source-of-truth.",
  "governing_source": ["closure D-007"],
  "next_action": "revise-child",
  "cycle_count": 1,
  "recheck_loop_signal": "first",
  "recurrence_cause": null,
  "findings": [
    {
      "id": "CPI-001",
      "severity": "blocking",
      "evidence": ["parent §D-007", "child §3 row R1"],
      "issue": "Child row R1 contradicts the locked operator-copy decision.",
      "required_action": "Revise child row R1 to honor D-007; cite Parent §D-007 instead of restating.",
      "retryable": true
    }
  ]
}
```

## Cross-References

- [plan-protocol § 7.1](../plan-protocol/references/plan-protocol.md) — common `child-checkpoint.v1` envelope shape
- [plan-protocol § 7.1.a](../plan-protocol/references/plan-protocol.md) — structured-output transport (harness extracts `.structured_output`; worker does not write stdout itself)
- [plan-protocol § 7.1.b](../plan-protocol/references/plan-protocol.md) — schema validity (canonical shape source is the JSON Schema below)
- [child-checkpoint.plan_intent JSON Schema](../plan-protocol/references/schemas/child-checkpoint.plan_intent.schema.json) — canonical shape source for the `plan_intent` payload (required fields, enums, ledger row fields)
- [plan-protocol § 7.1.c](../plan-protocol/references/plan-protocol.md) — failure handling (transport / schema / invariant failures stop and escalate; no semantic retry by the harness)
- [plan-protocol § 7.1.d](../plan-protocol/references/plan-protocol.md) — wrapper-side invariants (cross-field rules and the schema-coercion hard-reject phrase list)
- [plan-protocol § 7.2](../plan-protocol/references/plan-protocol.md) — `plan_intent` ledger and `reviewed_inputs` shape
- [plan-protocol § 7.4](../plan-protocol/references/plan-protocol.md) — verdict semantics
- [plan-protocol § 8](../plan-protocol/references/plan-protocol.md) — recurrence routing
- [plan-protocol § 9](../plan-protocol/references/plan-protocol.md) — refactor child review-skip (does not bypass this worker when its 4 conditions fail)
- [plan-protocol § 13](../plan-protocol/references/plan-protocol.md) — delegation preflight (the Codex `draft-review` wrapper must cite this worker contract verbatim before invocation)
