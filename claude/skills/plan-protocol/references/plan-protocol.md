# Plan Protocol — Shared Contract for docs-plan v2

This file is the byte-identical sync target between the Claude-side
`claude/skills/plan-protocol/references/plan-protocol.md` and the
Codex-side `codex/skills/plan-protocol/references/plan-protocol.md`.
Wrapper `SKILL.md` files in each ecosystem may differ in frontmatter,
invocation wording, and local path examples, but this contract body
must remain byte-identical across both copies.

A drift in this file is a closure violation. Wrapper `SKILL.md` drift
is not.

---

## 1. Purpose and Scope

This protocol governs the cross-orchestrator workflow split between
Claude (planning) and Codex (execution + finalization). It defines:

- the closed-set `family_status` vocabulary used in `## Status`
- gate query rules (Q1 / Q2)
- gate-pass conditions (parent-lock, child-plan-locked, decision-blocked)
- the `## Child Handoff Board` dashboard contract
- the `child-checkpoint.v1` JSON envelope used by Claude worker output
- recurrence routing (`recurrence_cause` branches)
- the refactor-child review-skip rule
- cross-orchestrator escalation rules
- writer ownership rules for `## Status`

Both orchestrators consume this file. Neither rewrites the other's
internal skills based on it. The wrappers and stage skills cite this
reference as the canonical contract source.

---

## 2. `family_status` Vocabulary (Closed Set)

`## Status` entries must use one of the values below. Any other value is
a closure violation, including phase-specific ad hoc markers (e.g.,
`child_<id>_implement_phase_a_completed`, `child_<id>_r12_blocked`).
Pre-existing ad hoc markers from legacy families are recognized as
read-only for backward compatibility, but no skill or runner may append
new ad hoc markers.

### 2.1 Family-level values

| value | writer | trigger |
|---|---|---|
| `parent_review_converged` | Claude `plan-reconcile` | parent review unresolved = 0 |
| `policy-locked` | Claude `plan-reconcile` | parent-lock 4 conditions met |
| `decision-blocked` | Claude `plan-reconcile` | family-level decision-needed raised |
| `decision-resolved` | Claude `plan-reconcile` | user response AND `D-NNN` closure registered (both) |
| `code-quality-ready` | Codex `exec-code-quality` | `## Code-quality result.status = code-quality-ready` |
| `refactor-needed` | Codex `exec-code-quality` | one or more accepted findings, no decision-needed, refactor children created |
| `code-quality-blocked` | Codex `exec-code-quality` | decision-needed or closure violation or plan-blocker — co-appended with Claude `plan-reconcile` `decision-blocked` |

### 2.2 Child-transition values

| value | writer | trigger |
|---|---|---|
| `child_<id>_draft_started` | Codex `exec-run` | child plan file created |
| `child_<id>_plan_locked` | Codex `exec-run` | `draft-review` verdict = `approve` |
| `child_<id>_plan_revision_required` | Claude `plan-reconcile` | child plan contract (acceptance / scope / source-of-truth) itself must change; **never** for test-only or manual-only revisions |
| `child_<id>_tests_started` | Codex `exec-run` | tests stage entered |
| `child_<id>_tests_written` | Codex `exec-run` | `test-review` verdict = `approve` |
| `child_<id>_implement_started` | Codex `exec-run` | implementation stage entered |
| `child_<id>_implement_completed` | Codex `exec-run` | approved tests/manual verification pass AND `over-satisfies` self-check passes (including silent narrow-back) |
| `child_<id>_blocked` | Codex `exec-run` | execution-local resumable stop only: expensive command, manual gate, external dependency, destructive action approval needed, unexpected dirty diff (user-owned), runtime prerequisite missing, `over-satisfies` narrow-back unsafe |
| `child_<id>_frozen` | Claude `plan-reconcile` | deferred; releases child concurrency |

### 2.3 Deprecated read-only compatibility

| legacy value | read-path equivalent |
|---|---|
| `child_<id>_ready` | `child_<id>_plan_locked` |
| `child_<id>_review_converged` | none (lifecycle recognizes as dangling entry) |

New runners must not append deprecated values. Existing families that
already contain them remain valid in read paths.

---

## 3. Query Rules

### 3.1 Q1 — Child Readiness

For a target child `<id>`, Q1 passes when the parent plan's `## Status`
contains a `child_<id>_plan_locked` entry that appears after the most
recent `child_<id>_draft_started` entry **and** after every
`child_<id>_plan_revision_required` entry, if any.

Legacy compatibility: a `child_<id>_ready` entry is accepted as the
read-path equivalent of `child_<id>_plan_locked` for families predating
this protocol. New writers must use `child_<id>_plan_locked`.

The `plan_locked` entry need not be the latest entry overall. Later
child-transition entries from other children do not invalidate Q1.

### 3.2 Q2 — Family-level Blocking

Filter `## Status` entries to the family-level namespace (the seven
values in § 2.1). Take the latest of those. Q2 fails if it is
`decision-blocked` or `code-quality-blocked`. Child-transition entries
are excluded from this latest determination.

---

## 4. Gates

### 4.1 parent-lock gate

Position: after Claude `plan-reconcile` closes a parent review, before
any child draft can enter.

Four pass conditions (all required):

1. unresolved blocking contradiction = 0
2. decision-needed = 0 (closed by user response + `D-NNN` registered)
3. parent's `## Closure map` core Decisions all have `source of truth` mapping
4. blocking L1 = 0 and decision-needed L1 = 0 (non-blocking L1 may go to backlog)

When all four hold, Claude `plan-reconcile` appends two entries to
`## Status` in time order:
1. `family_status: parent_review_converged`
2. `family_status: policy-locked`

These are recorded as separate entries, not collapsed. Routers and stage
skills are read-only for `## Status`; they consume `policy-locked` to
admit child draft entry but do not write it.

### 4.2 child-plan-locked gate

Position: after Codex `draft-review` (which invokes Claude
`draft-intent-worker`), before the child enters `exec-tests`.

Two pass conditions:

1. `draft-review` JSON verdict = `approve`
2. Q2 passes (family-level latest is not `decision-blocked` or `code-quality-blocked`)

When both hold, Codex `exec-run` appends
`family_status: child_<id>_plan_locked`. The child then becomes eligible
for `exec-tests` entry under Q1.

### 4.3 decision-blocked stage transition guard

When evaluating any stage transition into `exec-tests`, `exec-impl`,
`exec-code-quality`, `finalize-closeout`, or `finalize-archive`, run Q2.
If Q2 returns `decision-blocked` or `code-quality-blocked`, the
transition is blocked. The release marker is `family_status:
decision-resolved` for `decision-blocked`, or a fresh `code-quality-ready`
entry for `code-quality-blocked` after the underlying issue is closed.

### 4.4 child concurrency rule

Only one child may be in progress at a time. "In progress" means an
entry between `child_<id>_draft_started` (inclusive) and one of
`child_<id>_implement_completed` or `child_<id>_frozen` (exclusive).

`child_<id>_blocked` keeps the child in-progress — it does **not**
appear in the exclusion list above. A blocked child is a resumable
substate that still occupies the in-progress slot. Only
`child_<id>_implement_completed` (success) or `child_<id>_frozen`
(deferred) releases concurrency for the next child draft.

When a new child draft is requested, `exec-run` scans `## Status` for any
in-progress child; if one exists, the new draft is blocked with a
message naming the in-progress child.

---

## 5. `## Status` Invariants

- Append-only. Never edit or delete prior entries; corrections are made
  by appending a new entry.
- Single-writer per entry. Each value has exactly one writer per § 2.
- Closed-set vocabulary. Any value outside § 2 is a closure violation.
- Phase-specific ad hoc markers are forbidden for new appends.
- If `## Status` does not yet exist on a parent plan, the first writer
  appends a new `## Status` section to the end of the plan. Creating
  the section by appending is not a body contract modification.

---

## 6. `## Child Handoff Board` Contract

A dashboard rendered just before `## Status` in the parent plan.
Canonical gate source is always `## Status`. When the board and
`## Status` drift, `## Status` wins.

### 6.1 Columns

| column | content |
|---|---|
| `child` | child id (e.g., `55a`) |
| `responsibility` | one-line responsibility framing |
| `dependencies` | other child ids or `none` |
| `current gate` | the latest `family_status` value for this child |
| `next command` | the next Codex skill/runner to invoke (e.g., `exec-run 55`) |
| `Claude checkpoint` | `draft / test: pending | approved | revise | decision-needed | plan-defect` |
| `Codex checkpoint` | `draft / tests / impl: pending | in-progress | done | blocked` |
| `artifacts` | child plan path; `${current_check_root}/<child>/checkpoints/...` |

### 6.2 Surface-by-surface writer ownership

| surface | writer |
|---|---|
| `child` / `responsibility` / `dependencies` columns | Claude `plan-draft` and `plan-reconcile` |
| `current gate` / `next command` / `Claude checkpoint` / `Codex checkpoint` / `artifacts` columns | Codex `exec-run` runner |
| checkpoint verdict body | Claude `draft-intent-worker` / `test-intent-worker` JSON output only (no file write) |
| canonical transition | `## Status` single-writer marker per § 2 |

### 6.3 Drift policy

At every transition, Codex `exec-run` first reads `## Status` and
reconciles the board's `current gate` column to match. If `## Status` is
ahead of the board, the runner updates the board. If the board is ahead
of `## Status`, this is a closure-violation candidate and must be
escalated to the user.

The board may be created lazily by Codex `exec-run` when entering the
first v2 cycle on a pre-existing parent plan that has no board yet.
`plan-draft` seeds an empty board on every new parent plan.

---

## 7. `child-checkpoint.v1` JSON Envelope

Claude worker output (`draft-intent-worker` and `test-intent-worker`)
returns this envelope as stdout JSON. Workers must not write files.
Codex `exec-run` archives the JSON to
`${current_check_root}/<child>/checkpoints/<checkpoint>.json`.

### 7.1 Common envelope

```json
{
  "schema_version": "child-checkpoint.v1",
  "checkpoint": "plan_intent | test_intent",
  "verdict": "approve | revise | decision-needed | plan-defect",
  "revise_scope": "child-plan | tests-only | manual-verification-only | null",
  "child_id": "55a",
  "parent_plan_path": "<project-root>/plan/families/<parent>.md",
  "child_plan_path": "<project-root>/plan/families/<child>.md",
  "reviewed_inputs": { /* checkpoint-specific, see § 7.2 / § 7.3 */ },
  "<ledger>": [ /* checkpoint-specific: intent_map or acceptance_map */ ],
  "manual_verification_entries": [ /* test_intent only; [] for plan_intent */ ],
  "rebuttal_pass": "<one-line summary referencing governing_source>",
  "governing_source": ["parent §X.Y", "closure D-NNN", "tracked root doc", "user decision YYYY-MM-DD", "child §X acceptance row (test_intent only)"],
  "next_action": "continue | revise-child | revise-tests | revise-manual | ask-user | route-parent-reconcile | stop",
  "cycle_count": 1,
  "recheck_loop_signal": "first | recurrence-2nd",
  "recurrence_cause": "contract | tests-only | manual-only | null",
  "findings": [
    {
      "id": "CPI-001",
      "severity": "blocking | decision-needed | non-blocking",
      "evidence": ["file:line or plan §"],
      "issue": "...",
      "required_action": "...",
      "retryable": true
    }
  ]
}
```

`governing_source` enumerates citations from the planning / contract
domain only: parent §, closure `D-NNN`, tracked root doc, or explicit
prior user decision. **For `checkpoint = test_intent` only, child
acceptance rows (e.g., `child §3 R12`) are also valid governing
sources** because the executable test contract derives from the
child's acceptance contract. `draft-intent-worker`
(`checkpoint = plan_intent`) may NOT cite child sources — parent
intent is the only authority for plan-intent review. **`code-quality-worker
principle` is not a governing source for this envelope** — quality
principles govern `exec-code-quality` artifacts only.

`recurrence_cause` activates when `recheck_loop_signal = recurrence-2nd`.
See § 8.

### 7.2 `checkpoint = plan_intent` (`draft-intent-worker`)

- `reviewed_inputs`: `{ "git_head": "...", "parent_plan_sha256": "...", "child_plan_sha256": "...", "reviewed_files": ["..."] }`
- ledger key = `intent_map`:
  ```json
  "intent_map": [
    {
      "parent_anchor": "parent §3.2 or closure D-007",
      "child_anchor": "child §1 or §3 row",
      "intent_quote": "<verbatim parent intent>",
      "child_quote": "<verbatim child statement>",
      "audit_verdict": "match | mismatch | missing | out-of-scope | paraphrase-violation",
      "rebuttal_pass": "...",
      "next_action": "keep | revise-child | escalate plan defect"
    }
  ]
  ```
- `manual_verification_entries`: `[]`
- `revise_scope`: only `child-plan` is valid when `verdict = revise`
- `paraphrase-violation` appears only in this checkpoint's `audit_verdict`

### 7.3 `checkpoint = test_intent` (`test-intent-worker`)

- `reviewed_inputs`: `{ "git_head": "...", "child_plan_sha256": "...", "test_diff_sha256": "...", "manual_verification_sha256": "..." | null, "reviewed_files": ["..."] }`
- ledger key = `acceptance_map`:
  ```json
  "acceptance_map": [
    {
      "acceptance_row_id": "R12",
      "plan_intent_quote": "...",
      "verification_method": "unit-test | integration-test | manual-verification | hybrid",
      "verification_anchor": "tests/...:42 | manual: <child section> | scenario: <manual-scenario-path>",
      "assertion_quote": "<assertion code or manual procedure verbatim>",
      "audit_verdict": "match | mismatch | inverted | missing | out-of-scope | manual-verification-required",
      "rebuttal_pass": "...",
      "next_action": "keep | rewrite test (tests-only) | add manual verification entry | escalate plan defect | defer to other child"
    }
  ]
  ```
- `manual_verification_entries`: used. Lists acceptance rows that are
  verified by manual procedure (procedure / expected / owner).
- `revise_scope`: `tests-only` or `manual-verification-only` when
  `verdict = revise`
- `manual-verification-required` appears only in this checkpoint's
  `audit_verdict`

### 7.4 Verdict semantics

| verdict | meaning | follow-up |
|---|---|---|
| `approve` | all ledger rows pass; child proceeds | Codex `exec-run` appends the corresponding child-transition entry |
| `revise` | ledger rows need rework within the current scope | Codex re-invokes the same stage; bounded by `recheck_loop_signal` |
| `decision-needed` | the finding requires a user decision or policy lock | Codex stops; routes to Claude `plan-reconcile` for user-question artifact |
| `plan-defect` | the child plan itself is wrong; cannot be fixed by tests-only or impl-only rewrite | Codex stops; routes to Claude `plan-reconcile`; `child_<id>_plan_revision_required` follows |

---

## 8. Recurrence Routing

When the same audit-row finding recurs across two consecutive cycles
of the same checkpoint, the worker sets
`recheck_loop_signal = recurrence-2nd` and assigns `recurrence_cause`.

**Recurrence key (checkpoint-specific)**:

| checkpoint | recurrence key columns |
|---|---|
| `plan_intent` (`draft-intent-worker`) | `parent_anchor + child_anchor + audit_verdict + next_action` |
| `test_intent` (`test-intent-worker`) | `acceptance_row_id + verification_anchor + audit_verdict + next_action` |

The key differs because the two checkpoints carry different ledger
shapes: `plan_intent` uses `intent_map` rows anchored on parent / child
sections, while `test_intent` uses `acceptance_map` rows anchored on
acceptance row ids and verification anchors. Two findings are
considered "the same" only when every column of the checkpoint's key
matches between the prior and current cycle.

| recurrence_cause | route | marker |
|---|---|---|
| `contract` | Claude `plan-reconcile` escalation | `child_<id>_plan_revision_required` |
| `tests-only` | checkpoint verdict `revise`, `revise_scope = tests-only`, board stop, user escalation | none |
| `manual-only` | checkpoint verdict `revise`, `revise_scope = manual-verification-only`, board stop, user escalation | none |
| `null` | first cycle, or retryable non-recurrent state | none |

`child_<id>_plan_revision_required` is valid **only** when the child
plan contract itself must change — acceptance row, scope, or
source-of-truth. Test-only and manual-only recurrences must not write a
`## Status` marker; they stop on the board with a user escalation
message and are resumed by Codex re-invocation after user response.

---

## 9. Refactor Child Review-Skip Rule

A child plan with `origin: code-quality` may skip `draft-review` only
when **all four** of the following hold:

1. `origin: code-quality` frontmatter is present.
2. The child maps directly to a specific `F-NNN` finding id from the
   originating `## Code-quality result`.
3. There is no behavior, API, or source-of-truth change.
4. The existing test contract is preserved — no new acceptance row is
   added and no existing assertion is changed.

If any condition fails, `exec-run` must either:
- invoke a normal `draft-review` for the child, or
- escalate to Claude `plan-reconcile` if the issue requires a behavior
  or source-of-truth decision.

This rule prevents Codex from reviewing its own quality findings via
the Claude `draft-intent-worker` (which would be a self-loop on the
worker layer) while still requiring review whenever the refactor
exceeds the four conditions.

---

## 10. Cross-orchestrator Escalation Rules

| origin | trigger | route | marker |
|---|---|---|---|
| `exec-impl` | parent intent / policy / SoT conflict | Claude `plan-reconcile` | reconcile writes `decision-blocked` or `_plan_revision_required` |
| `exec-impl` | child acceptance / scope / SoT change needed | Claude `plan-reconcile` | `_plan_revision_required` |
| `exec-impl` | approved test assertion only is wrong (child contract unchanged) | `test-review` backtrack | verdict `revise`, `revise_scope = tests-only`, no marker |
| `exec-impl` | manual verification procedure boost needed | `test-review` backtrack | verdict `revise`, `revise_scope = manual-verification-only`, no marker |
| `exec-impl` | `over-satisfies` narrow-back safe (unrelated change + Codex unilateral revert + no regression risk) | Codex narrow-back and continue | no marker |
| `exec-impl` | `over-satisfies` narrow-back unsafe (user-owned dirty diff / regression risk / approval needed) | Codex stop | `child_<id>_blocked` |
| `exec-impl` | `over-satisfies` scope itself wrong | Claude `plan-reconcile` | `_plan_revision_required` |
| `exec-impl` | expensive runtime / manual gate / dirty diff / destructive / runtime prerequisite missing | Codex stop | `child_<id>_blocked` |
| `exec-impl` | `recheck_loop_signal = recurrence-2nd` with `recurrence_cause = contract` | Claude `plan-reconcile` | `_plan_revision_required` |
| `exec-impl` | `recheck_loop_signal = recurrence-2nd` with `recurrence_cause = tests-only` or `manual-only` | checkpoint verdict + board stop + user escalation | no marker |
| `exec-code-quality` | decision-needed / closure violation / `plan-blocker` 4-classification | Claude `plan-reconcile` | `code-quality-blocked` (Codex) + `decision-blocked` (reconcile) |
| `finalize-closeout` | root doc change → material change 7-area | Claude `plan-reconcile` material change → Delta review caller contract | (reconcile writes material-change result marker) |
| `finalize-closeout` | operating-policy / ADR locked decision change needed | Claude `plan-reconcile` updates `D-NNN` | (reconcile writer) |
| `finalize-archive` | explicit user approval | Codex directly or via Claude (either OK); invariant is approval itself | no marker (archive proceeds; family closes) |

Codex never writes `decision-blocked`, `decision-resolved`,
`parent_review_converged`, `policy-locked`,
`child_<id>_plan_revision_required`, or `child_<id>_frozen` — these are
Claude `plan-reconcile`'s domain. Claude never writes
`child_<id>_blocked`, `child_<id>_plan_locked`,
`child_<id>_tests_started`, `child_<id>_tests_written`,
`child_<id>_implement_started`, `child_<id>_implement_completed`,
`code-quality-ready`, `refactor-needed`, or `code-quality-blocked` —
these are Codex domain (`exec-run` or `exec-code-quality`).

---

## 11. `exec-impl` Self-check Invariants

Codex `exec-impl` enforces these without re-asking Claude:

- Do not add new tests in `exec-impl`.
- Do not modify approved tests or manual verification except by
  explicit `test-review` backtrack (verdict = `revise`,
  `revise_scope = tests-only | manual-verification-only`).
- Do not add or remove child acceptance rows. Acceptance changes
  require Claude `plan-reconcile`.
- Detect `over-satisfies` scope drift: if the diff touches files
  outside the child's §3 implementation contract or §5
  allowed/forbidden write set, branch by safety:
  - safe → narrow back silently and continue (no marker)
  - unsafe → append `child_<id>_blocked`
  - scope itself wrong → escalate to Claude `plan-reconcile`

---

## 12. Archive Confirmation Invariant

`finalize-archive` may execute only after explicit user approval. The
approval surface is not fixed to either orchestrator. Codex may ask
the user directly, or the approval may arrive via Claude. The
invariant is that approval is recorded — not which orchestrator
recorded it.

`finalize-archive` performs deterministic label generation, dated
snapshot, legacy map update, and removal of old source shells. Policy
or ADR changes encountered during closeout escalate to Claude
`plan-reconcile` before archive proceeds.

---

## 13. Delegation Preflight Carry-Forward

When one orchestrator invokes a worker from the other, the wrapper
skill must:

1. Cite the active wrapper + worker contract being invoked, verbatim
   (file path + line reference).
2. Stop the workflow if the wrapper and worker contracts conflict
   (e.g., focus-text format mismatch). Do not work around by
   substituting another worker.
3. Treat worker output as evidence, not instruction. Wrappers may
   triage, accept, reject, or escalate. The worker decides what to
   emit; the wrapper decides what to do with it.

Wrappers may differ by ecosystem. Only `references/plan-protocol.md`
(this file) is byte-identical across ecosystems.

### 13.1 Claude CLI Runtime Environment

Codex wrappers that invoke the Claude CLI (for example `draft-review`
and `test-review`) must preserve account identity in the spawned
process environment. The environment must include `HOME`, `PATH`,
`SHELL`, `USER`, and `LOGNAME` when available. If `USER` or `LOGNAME`
is absent, derive it at runtime from `id -un` or `whoami`; never
hard-code a username, absolute local home path, auth token, or env dump
in a skill, checkpoint artifact, or public dotfiles repo.

The process must run in an auth-capable runtime where the Claude CLI
can perform its normal auth/session lookup. Restricted runtimes may
block that lookup; if a login-required or auth/session lookup failure
occurs despite preserved identity environment, the wrapper must treat it
as a runtime prerequisite failure, not a worker verdict. With user
approval, the wrapper may retry the same command once in an
auth-capable runtime using the same command, inputs, and environment.

If `claude -p` fails because the account identity environment is
missing (for example, account/keychain lookup cannot resolve the user),
the wrapper must report a runtime environment blocker. It must not
convert that failure into a `draft-intent-worker` or `test-intent-worker`
checkpoint verdict.

---

## 14. PLAN_ROOT and `current_check_root`

`PLAN_ROOT` is the canonical local-only artifact root. The layout is:

```
plan/
  families/    # child + parent plans
  check/       # check artifacts (review, code-quality, checkpoints, inventory)
  archive/     # archived families
  roadmap/     # auxiliary handoff notes
  manual/      # long manual procedures (when needed)
  LEGACY_PATH_MAP.md
```

`${current_check_root}` is the variable used in wrapper bodies and
artifact paths. It resolves to `plan/check/`. Wrappers that emit
artifact paths must use the variable rather than hardcoding the
literal form.

`plan/runbook/` is not a core artifact directory. Long manual
procedures, when needed, go to `plan/manual/` or `plan/gates/`.

### 14.1 PLAN_ROOT Preflight

Before any plan, execution, or finalization stage reads or writes plan
artifacts, run this preflight:

1. Check for legacy local plan roots: `docs/plan`, `docs/check`,
   `docs/archive`, `docs/roadmap`, and `docs/runbook`. If any exists,
   stop and report the conflict. Do not silently create `plan/`, migrate
   content, or move artifacts.
2. Check the canonical root. If the `plan/` structure is absent, stop
   and report that PLAN_ROOT bootstrap is required.
3. If some canonical directories are missing but no legacy conflict is
   present and at least part of canonical `plan/` already exists, create
   only the missing directories idempotently: `plan/families`,
   `plan/check`, `plan/archive`, `plan/roadmap`, and `plan/manual`.
4. Never overwrite existing files. If `plan/LEGACY_PATH_MAP.md` is
   missing, report bootstrap need instead of inventing project history.
5. Migration or artifact moves require explicit user approval. Without
   that approval, stop after reporting the needed action.

---

## 15. Source Precedence Inside the Protocol

When this contract and a stage skill's wrapper disagree on a rule
defined here, this file wins. Stage skills must cite this file rather
than redefine vocabulary, gates, query rules, or the checkpoint
envelope. Drift between any two copies of this file (Claude-side and
Codex-side) is a closure violation and must be resolved before any
stage transition proceeds.

Project-local parent plans are the source of truth for future protocol
changes. If a project needs to diverge from this contract, register the
decision in that project's PLAN_ROOT before editing this reference body.
