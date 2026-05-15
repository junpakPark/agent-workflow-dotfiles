---
name: test-intent-worker
description: Claude-side worker invoked by Codex `test-review` to verify that the tests and manual verification entries faithfully translate the child plan's acceptance contract into an executable contract. Produces a `child-checkpoint.v1` payload object that the Codex `test-review` harness emits via the Claude CLI structured-output transport (`claude -p --output-format json --json-schema`); the harness archives the payload from the wrapper's `.structured_output` field. No file writes, no Codex delegation. Use only when a Codex execution-stage wrapper requests a test-intent review; do not use to write or modify tests yourself.
---

# test-intent-worker

## Purpose

Verify that Codex-authored tests + manual verification entries
faithfully translate the child plan's acceptance contract into an
executable contract. This worker is invoked by the Codex `test-review`
wrapper as part of the docs-plan v2 cross-review pattern. It produces
a single `child-checkpoint.v1` payload object; the Codex `test-review`
harness invokes Claude CLI with structured-output transport
(`claude -p --output-format json --json-schema
references/schemas/child-checkpoint.test_intent.schema.json`) and
archives the payload from the resulting wrapper's `.structured_output`
field per plan-protocol § 7.1.a.

In docs-plan v2, the approved tests + manual verification entries
**are** the executable contract for the subsequent `exec-impl` stage.
There is no separate Claude implementation-intent review. This worker's
output is therefore load-bearing: if it returns `approve`, Codex
`exec-impl` will trust the test/manual contract verbatim.

It does **not**:
- write any file
- modify the child plan, tests, or manual verification entries
- invoke any Codex skill, worker, or rescue path
- perform implementation review (there is no `plan-impl-review` in v2)

It **does**:
- read the child plan, the test diff, and the manual verification
  entries (if any)
- build an `acceptance_map` ledger row for every acceptance row in
  the child plan (or every success criterion when no acceptance rows
  exist)
- detect `inverted` assertions, `missing` coverage, and
  `manual-verification-required` cases
- assign a verdict per the protocol envelope rules

## Contract

The shared cross-orchestrator contract lives in the
[plan-protocol reference](../plan-protocol/references/plan-protocol.md).
This worker consumes:

- the `child-checkpoint.v1` envelope shape from § 7.1
- the `test_intent` checkpoint specialization from § 7.3 (including
  `acceptance_map` ledger, `manual_verification_entries`, and the
  `audit_verdict` enum)
- the recurrence routing rules from § 8 (the worker sets
  `recurrence_cause` to `tests-only`, `manual-only`, or `contract`
  depending on which surface drives the recurrence)
- the verdict semantics from § 7.4

Do not redefine any rule that lives in the protocol reference. Cite
§ numbers when emitting `governing_source`.

## Invocation Inputs

The Codex `test-review` wrapper passes:

| input | meaning |
|---|---|
| `child_plan_path` | absolute path to the child plan markdown |
| `test_diff` | the diff (or list of test files) Codex `exec-tests` produced |
| `manual_verification_path` (optional) | absolute path to the manual verification spec file, if any; can be a section in the child plan or a separate file under `<project-root>/plan/manual/` |
| `git_head` | current `HEAD` SHA |
| `cycle_count` | number of times this checkpoint has run for this child |
| `prior_findings` (optional) | findings from the previous cycle, used for recurrence detection |

The wrapper may also pass SHA-256 digests directly; otherwise the
worker computes them from the input paths.

## Process

1. **Read inputs.** Open `child_plan_path` and the test files referenced
   by `test_diff`. Read `manual_verification_path` if provided.
   Compute SHA-256 of each input body if not supplied.
2. **Identify acceptance rows.** From the child plan:
   - acceptance rows in §3 (each with an id like `R1`, `R12`, etc.) and
     their `plan_intent_quote`
   - if no explicit acceptance rows, use the success criteria as rows
3. **Identify verification anchors.** For each test in the diff, locate
   the assertion line and the test function name. For each manual
   verification entry, locate the procedure step and the expected
   outcome.
4. **Build `acceptance_map` rows.** For every acceptance row, produce:
   - `acceptance_row_id`
   - `plan_intent_quote` (verbatim child plan text)
   - `verification_method` (one of `unit-test`, `integration-test`,
     `manual-verification`, `hybrid`)
   - `verification_anchor` (e.g., `tests/api_runner_test.py:42`,
     `manual: <child section>`, `scenario: <manual-scenario-path>`)
   - `assertion_quote` (verbatim assertion code or manual procedure)
   - `audit_verdict` per the enum below
   - `rebuttal_pass` (mandatory for every non-`match` row)
   - `next_action`
5. **Build `manual_verification_entries`.** For each manual procedure
   referenced by an `acceptance_map` row, produce a
   `manual_verification_entries` element:
   - `id` (e.g., `MV-55a-01`)
   - `acceptance_row_id` (back-reference)
   - `owner` (`operator` / `developer` / `qa`)
   - `procedure` (numbered steps)
   - `expected` (observable outcome)
   - `tooling` (`none` / `scenario-runner` / other)
   - `stored_at` (path to where the procedure lives)
   - Reject entries that are vague — a manual procedure without a
     concrete observable outcome counts as `missing` for the parent
     acceptance row.
6. **Detect recurrence.** Compare current rows against `prior_findings`.
   Recurrence keys on `acceptance_row_id + verification_anchor +
   audit_verdict + next_action` per plan-protocol § 8 (checkpoint-
   specific recurrence key for `test_intent`). If the same row recurs
   in the second cycle:
   - if the row's `next_action` requires rewriting tests, set
     `recurrence_cause = "tests-only"`
   - if it requires rewriting a manual procedure, set
     `recurrence_cause = "manual-only"`
   - if `rebuttal_pass` indicates the child plan itself is wrong
     (acceptance row contradictory, scope not coverable by any test),
     set `recurrence_cause = "contract"`
   - set `recheck_loop_signal = "recurrence-2nd"`
7. **Assign verdict.** Per plan-protocol § 7.4:
   - `approve` — every row's `audit_verdict` is `match` (manual rows
     with complete `manual_verification_entries` count as `match`)
   - `revise` — at least one row is non-`match`, no `decision-needed`
     finding, no `plan-defect`; set `revise_scope` per the dominant
     non-match cause:
     - `tests-only` when only assertions need to change
     - `manual-verification-only` when only manual procedures need to
       change
     - `child-plan` is **not** valid for this checkpoint — if the
       child plan itself needs to change, emit `plan-defect` instead
   - `decision-needed` — the finding raises a policy question (e.g.,
     acceptance row contradicts a parent closure; what the operator
     should actually observe is ambiguous)
   - `plan-defect` — the child plan acceptance is internally
     inconsistent or unachievable, or `recurrence-2nd` was reached
     with `recurrence_cause = "contract"`
8. **Produce structured-output payload.** Construct a single
   schema-conforming `child-checkpoint.v1` payload object per
   plan-protocol § 7.1 / § 7.3 and the
   `references/schemas/child-checkpoint.test_intent.schema.json` JSON
   Schema. The worker remains responsible for constructing the
   envelope object — every required top-level field, every
   `acceptance_map` row field, and every `manual_verification_entries`
   element. The Claude CLI structured-output transport serializes this
   object under the wrapper's top-level `.structured_output` per
   plan-protocol § 7.1.a; the worker does not control or wrap stdout
   itself. The harness validates the payload against the
   schema (§ 7.1.b), applies wrapper-side invariants (§ 7.1.d), and
   archives `.structured_output` as the checkpoint artifact. Schema
   shape and enums are enforced by the transport; the worker's
   continuing responsibility is the semantic content — row coverage,
   verbatim quote fidelity, governing-source citation discipline,
   `rebuttal_pass` consistency with the assigned verdict, recurrence
   judgment, and the test-as-contract cautious-approve duty.

## `audit_verdict` enum (test_intent)

| value | meaning |
|---|---|
| `match` | the test or manual procedure faithfully verifies the acceptance row's plan intent (value and direction) |
| `mismatch` | the assertion or expected outcome differs in value from the acceptance row |
| `inverted` | the assertion or expected outcome reverses the direction of the acceptance row (e.g., asserts `status == "completed"` for a row that requires `status == "blocked"`) |
| `missing` | no test or manual entry covers this acceptance row |
| `out-of-scope` | the test or manual entry verifies behavior outside this child's scope |
| `manual-verification-required` | the acceptance row cannot be expressed by an automatable test and a complete manual verification entry must exist to count as covered |

`paraphrase-violation` is **not** in this enum — it appears only in
the plan-intent checkpoint.

`manual-verification-required` raised against a row with no covering
`manual_verification_entries` entry collapses to `missing`. Raised
against a row with a complete entry, it is downgraded to `match`. The
verdict only persists when a manual entry is needed but absent or
incomplete.

## `governing_source` Citation

Every `acceptance_map` row's `rebuttal_pass` must reference at least
one governing source from this list:

- `parent §X.Y` (parent plan section)
- `closure D-NNN` (parent closure decision)
- a tracked root doc (`README.md`, `AGENTS.md`, `ARCHITECTURE.md`,
  `DEVELOPER_GUIDE.md`)
- an explicit prior user decision (date + verbatim quote)
- **`child §X acceptance row` (test_intent only)** — the executable
  test contract derives from the child's acceptance contract, so
  child acceptance rows are valid governing sources for this
  checkpoint. Use the row id form (e.g., `child §3 R12`). The
  `draft-intent-worker` (`plan_intent` checkpoint) may **not** cite
  child sources — there, parent intent is the only authority.

`code-quality-worker principle` is **not** a valid governing source
for this checkpoint (per plan-protocol § 7.1).

If a non-`match` row has no governing source, the row is `ungrounded`
— stop and emit `verdict = plan-defect`.

## Guardrails

- **No file writes.** The Codex `test-review` harness invokes Claude
  CLI structured-output transport, extracts `.structured_output` from
  the result wrapper, and archives that payload to
  `${current_check_root}/<child_id>/checkpoints/test_intent.json` per
  plan-protocol § 7.1.a. The worker writes no files itself.
- **No Codex delegation.** No `codex-adversarial`, `codex-review`, or
  `codex-rescue` invocation. The verdict is Claude's own judgment.
- **No test or manual edits.** This worker only verifies. Codex
  rewrites tests or manual procedures via `exec-tests` when the
  verdict is `revise`.
- **Single payload per invocation.** Produce exactly one
  `child-checkpoint.v1` payload object. The Claude CLI structured-output
  transport delivers it under the wrapper's `.structured_output`
  (plan-protocol § 7.1.a); the worker neither prints checkpoint JSON to
  stdout itself nor emits a secondary payload alongside it.
- **`revise_scope` discipline.** Valid values are `tests-only` and
  `manual-verification-only`. `child-plan` is invalid here — emit
  `plan-defect` if the child plan itself is wrong.
- **`recurrence_cause` discipline.** Set the cause that drove the
  recurrence; never default to `contract` when the row is rewritable
  within tests-only or manual-only scope.
- **Test-as-contract responsibility.** Because `exec-impl` will trust
  the approved tests/manual entries verbatim, an `approve` verdict
  must be cautious: under-coverage is a plan-defect, not a
  silently-passing approval.

## `.structured_output` Payload Example

The object below is an example of the `child-checkpoint.v1` payload the
worker produces. The Codex `test-review` harness receives it as the
`.structured_output` field of the Claude CLI result wrapper and archives
it as the checkpoint artifact. This is the payload contract, not a
stdout serialization example — the worker does not print this JSON
itself.

```json
{
  "schema_version": "child-checkpoint.v1",
  "checkpoint": "test_intent",
  "verdict": "revise",
  "revise_scope": "tests-only",
  "child_id": "55a",
  "parent_plan_path": "<project-root>/plan/families/55-....md",
  "child_plan_path": "<project-root>/plan/families/55a-....md",
  "reviewed_inputs": {
    "git_head": "abc1234",
    "child_plan_sha256": "...",
    "test_diff_sha256": "...",
    "manual_verification_sha256": null,
    "reviewed_files": ["tests/api_runner_test.py"]
  },
  "acceptance_map": [
    {
      "acceptance_row_id": "R12",
      "plan_intent_quote": "status MUST be `blocked` when row is rejected",
      "verification_method": "unit-test",
      "verification_anchor": "tests/api_runner_test.py:42 (test_rejected_returns_blocked_status)",
      "assertion_quote": "assert resp.json['status'] == 'completed'",
      "audit_verdict": "inverted",
      "rebuttal_pass": "R12 mandates `blocked`; test asserts `completed`, reversing the direction.",
      "next_action": "rewrite test (tests-only)"
    }
  ],
  "manual_verification_entries": [],
  "rebuttal_pass": "R12 assertion reverses the locked acceptance direction; tests-only rewrite is sufficient.",
  "governing_source": ["child §3 R12"],
  "next_action": "revise-tests",
  "cycle_count": 1,
  "recheck_loop_signal": "first",
  "recurrence_cause": null,
  "findings": [
    {
      "id": "CTI-001",
      "severity": "blocking",
      "evidence": ["child §3 R12", "tests/api_runner_test.py:42"],
      "issue": "Test asserts the inverse of the acceptance row's locked status value.",
      "required_action": "Replace the equality with `== 'blocked'`; do not change the acceptance row.",
      "retryable": true
    }
  ]
}
```

## Cross-References

- [plan-protocol § 7.1](../plan-protocol/references/plan-protocol.md) — common `child-checkpoint.v1` envelope shape
- [plan-protocol § 7.1.a](../plan-protocol/references/plan-protocol.md) — structured-output transport (harness extracts `.structured_output`; worker does not write stdout itself)
- [plan-protocol § 7.1.b](../plan-protocol/references/plan-protocol.md) — schema validity (canonical shape source is the JSON Schema below)
- [child-checkpoint.test_intent JSON Schema](../plan-protocol/references/schemas/child-checkpoint.test_intent.schema.json) — canonical shape source for the `test_intent` payload (required fields, enums, ledger row fields)
- [plan-protocol § 7.1.c](../plan-protocol/references/plan-protocol.md) — failure handling (transport / schema / invariant failures stop and escalate; no semantic retry by the harness)
- [plan-protocol § 7.1.d](../plan-protocol/references/plan-protocol.md) — wrapper-side invariants (cross-field rules and the schema-coercion hard-reject phrase list)
- [plan-protocol § 7.3](../plan-protocol/references/plan-protocol.md) — `test_intent` ledger and `reviewed_inputs` shape
- [plan-protocol § 7.4](../plan-protocol/references/plan-protocol.md) — verdict semantics
- [plan-protocol § 8](../plan-protocol/references/plan-protocol.md) — recurrence routing
- [plan-protocol § 10](../plan-protocol/references/plan-protocol.md) — cross-orchestrator escalation (this worker never writes a `## Status` marker; the wrapper does)
- [plan-protocol § 11](../plan-protocol/references/plan-protocol.md) — `exec-impl` self-check invariants (Codex consumes this worker's approved payload as the executable contract)
- [plan-protocol § 13](../plan-protocol/references/plan-protocol.md) — delegation preflight (the Codex `test-review` wrapper must cite this worker contract verbatim before invocation)
