---
name: plan-review
description: Delegate parent plan Full Panel review (CTO + 6 lenses) to the Codex `plan-review-worker` over the Codex CLI structured-output transport (`codex exec --sandbox read-only --output-schema <parent-plan-review.v1>`) and save the raw payload plus a deterministic F-NNN Markdown rendering as a check artifact for `/plan-reconcile`. Parent-only. Forbids `codex-adversarial` and `/codex:adversarial-review` as parent-review delivery channels. Child Full Panel review is out of scope in v2; child plan review goes through Codex `draft-review` + Claude `draft-intent-worker`.
---

# plan-review

## Purpose

Invoke the Codex `plan-review-worker` against a parent plan over the
Codex CLI structured-output transport, validate the returned
`parent-plan-review.v1` payload, and save a check artifact for
`/plan-reconcile` to triage. This skill is the Claude-side wrapper
of the Codex worker; it owns:

- the execution channel contract (`codex exec --output-schema`)
- the caller-side structured focus-text prefix
- schema validation and failure handling
- the structured-JSON → F-NNN Markdown rendering rule
- archive-on-replace policy for no-op / adversarial-pivoted artifacts
- handoff to `/plan-reconcile`

It does NOT perform semantic triage — that is `/plan-reconcile`'s job.
It does NOT review child plans — that is Codex `draft-review` + Claude
`draft-intent-worker` in v2.

## Read First

- The parent plan being reviewed and its `## Closure map` (if any).
- [plan-protocol reference](../plan-protocol/references/plan-protocol.md)
  for the `## Status` invariants the review must not violate.
- [parent-plan-review.v1 schema](../plan-protocol/references/schemas/parent-plan-review.v1.schema.json) —
  canonical shape of the structured output this wrapper validates.
- Codex `plan-review-worker` and its `references/review.md` for the
  worker-side lens definitions, severity rules, and prefix parser.

## Runtime Prerequisites

The Codex CLI invocation requires a runtime environment in which
`codex exec` can complete a session. Specifically:

- **Codex auth** — the runtime must have a valid Codex auth context
  (`codex login` or equivalent). Unauthenticated calls fail before
  reaching the worker.
- **Codex state DB write access** — `codex exec` writes a per-session
  state file under `~/.codex/state_*.sqlite` (path varies by version).
  Environments that block writes to `$HOME` (e.g., a more restrictive
  outer sandbox than the `--sandbox read-only` flag itself) will fail
  with a SQLite open error, even though `--sandbox read-only` says the
  *workspace* is read-only. The flag governs model-generated commands,
  not the CLI's own session-state persistence.
- **`--ephemeral` as an escape hatch** — `codex exec --ephemeral`
  disables session-file persistence and may unblock a restricted
  outer sandbox at the cost of resume support. The wrapper MAY add
  `--ephemeral` when the operator declares an ephemeral environment,
  but MUST NOT add it silently.

If any of the above is unmet, treat the call as a runtime
prerequisite blocker (per the failure handling table) and emit a
`.failed.md` debug artifact naming the missing prerequisite. Do not
fall back to any other review channel — the forbidden-channels rule
in § Forbidden Delivery Channels still applies.

## PLAN_ROOT Preflight

Before reading or writing review artifacts, apply plan-protocol § 14.1.
If canonical `plan/` is absent, report that PLAN_ROOT bootstrap is
required. If `docs/plan`, `docs/check`, `docs/archive`,
`docs/roadmap`, or `docs/runbook` exists, stop and report the legacy
conflict. If only some canonical directories are missing and no legacy
conflict exists, create the missing directories idempotently. Never
overwrite existing files, migrate artifacts, or move artifacts without
explicit user approval.

## Forbidden Delivery Channels

Parent Full Panel review **must not** be delivered through any of these
channels. These are hard rejections, enforced at the wrapper before any
invocation runs:

1. **`/codex:adversarial-review`** — this slash command is a code-diff
   runtime. It loads `prompts/adversarial-review.md` and a code-review
   JSON schema, and reviews `git diff main...HEAD`. A `<<<plan-review>>>`
   marker placed in `USER_FOCUS` does NOT pivot this runtime into a
   plan-review. With an empty diff (e.g., parent plan is `.gitignore`-d
   under `plan/`) it returns `Verdict: approve / no material findings`,
   which is **not** a canonical Full Panel review.
2. **`codex-adversarial` Claude Code subagent** — same underlying
   runtime, same rejection.
3. **`plan/` temp-unignore or diff coercion** — forcing the parent plan
   into a `git diff` so the adversarial runtime "sees" it does not turn
   that runtime into a plan-review. Reject this workaround.
4. **Reusing an existing `approve / no material findings` artifact as
   `/plan-reconcile` input.** Such artifacts are no-op adversarial
   outputs, not Full Panel review evidence. See § Bad Artifact
   Rejection (no-op adversarial + malformed v2) § Category A
   (no-op adversarial signatures) below.

If a caller (user, sub-agent, or upstream skill) requests parent
Full Panel review through any of the channels above, the wrapper stops,
explains the prohibition, and does not produce an artifact under that
channel.

## Parent-Only Canonical Path

In docs-plan v2, `/plan-review` is invoked only for the parent plan.
The Codex worker emits CTO + 6-lens findings against the parent's
intent, scope, source-of-truth, child responsibility boundaries,
acceptance criteria, and risk surface.

Child plan review uses a different cross-review pattern in v2:
- the wrapper is **Codex `draft-review`** (not `/plan-review`)
- the worker is **Claude `draft-intent-worker`** (not Codex
  `plan-review-worker`)
- the output is a `child-checkpoint.v1` JSON envelope, not an
  F-NNN Markdown artifact

Do not confuse the two paths. `/plan-review` does not call
`draft-intent-worker`. Codex `draft-review` does not call
`plan-review-worker`.

## Child Full Panel Path

Child Full Panel review is not available in canonical v2 routing. If a
user asks for a child Full Panel review anyway, stop and explain that
v2 removed the legacy path; do not route to deleted `docs-plan-*`
skills.

## Execution Channel — `codex exec --output-schema`

Parent Full Panel review is delivered through the Codex CLI
structured-output transport. The schema is the canonical decision
data; F-NNN Markdown is a deterministic rendering of that data.

### 1. Invocation contract

The wrapper invokes the Codex CLI with the exact flag set supported by
`codex exec` (verified against `codex exec --help`). `codex exec` does
**not** accept `--skill` or `--prompt-file`. Skill activation is
description-matched by Codex against the prompt body; prompt delivery
is stdin via the `-` positional placeholder.

```sh
# Schema lives in the shared plan-protocol schemas directory and is
# mirrored across Claude and Codex sides (see § Schema Ownership).
schema_path="claude/skills/plan-protocol/references/schemas/parent-plan-review.v1.schema.json"

# Prompt body is built by the wrapper into a temp file. Its first
# logical line under USER_FOCUS is the structured `<<<plan-review>>>`
# prefix (see § Focus Text Prefix Contract). The body MUST name the
# Codex `plan-review-worker` skill explicitly so Codex's skill
# registry activates it by description match.
prompt_path="${current_check_root}/<parent-basename>-review.prompt.txt"

# Capture path: -o writes the last assistant message (the schema-
# validated JSON) to a file. This is the canonical capture for Codex
# CLI; see § 2 below for why the Claude-CLI-style `.structured_output`
# envelope does NOT apply here.
out_path="${current_check_root}/<parent-basename>-review.codex.json"

codex exec \
  --sandbox read-only \
  --output-schema "${schema_path}" \
  -o "${out_path}" \
  - <"${prompt_path}"
```

Notes on each supported flag and why we use it:

- `--sandbox read-only` — the worker is read-only by contract (see
  Codex `plan-review-worker` § Boundaries). No file writes, no commits.
- `--output-schema <path-to-parent-plan-review.v1>` — enforces JSON
  output conforming to the schema. This is the only accepted
  structured-output route; bare stdout, free-form Markdown, or an
  ad hoc JSON shape is not a valid Full Panel review payload.
- `-o <output-file>` — writes the last assistant message (the
  schema-validated JSON) to a file. This is the wrapper's primary
  capture path. See § 2 below.
- `-` (positional prompt placeholder) — tells `codex exec` to read the
  prompt body from stdin. The wrapper pipes the prompt file in. An
  equivalent form is passing the prompt body as a positional argument
  string, but stdin is preferred because the prompt is multi-line.

Skill activation:

- Codex does NOT take a `--skill` flag. The Codex runtime selects the
  skill by description match against the prompt body and the available
  skill registry. The wrapper's prompt body therefore MUST:
  - explicitly request the `plan-review-worker` skill by name in the
    body text;
  - include the `<<<plan-review>>>` structured prefix on the
    USER_FOCUS first logical line (parsed by the worker via substring
    search, per `plan-review-worker/references/review.md`);
  - cite the parent plan path so the worker has a file to read.

Prompt file (no longer a flag):

- `codex exec` does NOT take a `--prompt-file` flag. The wrapper still
  builds the prompt body as a temp file (so the body is not buried in
  a nested shell heredoc and remains inspectable for audit), but the
  file is fed to `codex exec` via stdin redirection (`< "${prompt_path}"`)
  with `-` as the positional placeholder.

#### Prompt-body provenance block (wrapper-computed)

The structured prefix on the focus-text first line carries only
**directive routing values** (`review_scope`, `review_severity`,
conditional `delta_scope`, `closure_map_path`, `recovery_mode`). It
does **not** carry hash/path/git-head/reviewed-file evidence values.
Those are **provenance** values, and the wrapper computes them at
invocation time and injects them into the prompt body as a separate
provenance block that the worker echoes verbatim into
`reviewed_inputs`.

Before running `codex exec`, the wrapper MUST compute these expected
values and append them to the prompt body as a clearly-marked
provenance block, e.g. fenced as `<<<plan-review-provenance>>> … >>>`
or rendered as an explicit YAML/JSON block under a heading the worker
recognizes (see Codex `plan-review-worker` for the worker-side parse
expectation — the wrapper does not silently rely on the worker
inferring these values from the file system).

Required provenance fields and their sources:

| field | source / computation | used to validate JSON |
|---|---|---|
| `expected_schema_version` | constant `"parent-plan-review.v1"` | `schema_version` |
| `expected_git_head` | `git rev-parse HEAD` captured before dispatching the Codex call | `reviewed_inputs.git_head` |
| `expected_parent_plan_path` | absolute path of the parent plan being reviewed (same value the wrapper would pass as `closure_map_path` in canonical v2) | `reviewed_inputs.parent_plan_path` |
| `expected_parent_plan_sha256` | sha256 of the parent plan host file at invocation time | `reviewed_inputs.parent_plan_sha256` |
| `expected_closure_map_path` | same string value as `closure_map_path` in the structured prefix | (cross-check; see also `expected_closure_map_sha256`) |
| `expected_closure_map_sha256` | sha256 of the **closure-map host file** (see § Closure-map sha256 policy below); `null` only when no readable closure-map host exists | `reviewed_inputs.closure_map_sha256` |
| `expected_reviewed_files` | single-element array containing the absolute parent plan path. Canonical v2 parent Full Panel review hosts the closure map in the parent plan's `## Closure map` section, so the parent plan path is the only file read; separate closure-map host files are not supported (the Focus Text Prefix preflight rejects any `closure_map_path` that does not point at the parent plan) | `reviewed_inputs.reviewed_files` |

Worker contract for the provenance block:

- The worker echoes these expected values verbatim into the JSON's
  `schema_version` and `reviewed_inputs.*` fields. It MUST NOT guess,
  fabricate, recompute, or "correct" any of them.
- If the worker disagrees with a provenance value (e.g., the parent
  plan it actually read does not match the path the wrapper supplied),
  the correct response is to emit a finding describing the disagreement
  in `findings[].evidence` — not to substitute an alternate value into
  `reviewed_inputs`.
- The wrapper rejects any review payload whose `reviewed_inputs`
  values diverge from the provenance block. See § 4 invariant #6
  (directive vs provenance echo split) and § 5 failure table.

Separation of concerns:

- **Directive prefix** (`<<<plan-review>>>` line) — review routing only;
  echoed against the corresponding JSON top-level fields (see § 4
  invariant #6, directive half).
- **Provenance block** (`<<<plan-review-provenance>>>` or equivalent
  heading) — wrapper-computed evidence values; echoed against
  `schema_version` and `reviewed_inputs.*` (see § 4 invariant #6,
  provenance half).
- The two are disjoint sets of fields; the worker does not move
  values from one to the other.

The wrapper MUST NOT shell out to `claude` (the Claude CLI) for this
review; the Codex CLI is the transport, the Codex worker is the
producer. The Claude CLI structured-output transport described in
plan-protocol § 7.1.a is for `child-checkpoint.v1` (Claude workers
called by Codex wrappers), which is the symmetric — and disjoint —
counterpart.

### 2. Structured output is canonical (Codex CLI capture path)

The JSON payload validated against `parent-plan-review.v1` is the
canonical decision data. The artifact also stores a deterministic
F-NNN Markdown rendering, but reconcile's contract still reads
`## Codex output`. The rendering is generated from the JSON by the
wrapper; if the rendering disagrees with the JSON, the JSON wins and
the rendering is regenerated, never the other way around.

**Capture mechanism (Codex CLI specific).** Unlike the Claude CLI
(`claude -p --output-format json`) — which wraps the final message in
a `.structured_output` field of a JSON envelope — `codex exec` does
**not** emit a `.structured_output` wrapper. The structured payload is
the final assistant message itself, and the safest capture is the
`-o <output-file>` flag:

```sh
out_path="${current_check_root}/<parent-basename>-review.codex.json"

codex exec \
  --sandbox read-only \
  --output-schema "${schema_path}" \
  -o "${out_path}" \
  - <"${prompt_path}"
```

`-o <file>` writes the last assistant message (the schema-validated
JSON) to `${out_path}` as plain JSON. The wrapper then reads
`${out_path}` and validates it against `parent-plan-review.v1`. Any
references to `.structured_output` in earlier drafts of this skill
were carried over from the Claude CLI transport contract and are
incorrect for the Codex CLI; the canonical capture is the file
written by `-o`.

`-o <output-file>` is the **only** canonical capture path. The
wrapper does NOT fall back to scraping stdout — stdout may contain
Codex's banner / progress lines mixed with the final JSON, and any
extraction heuristic is fragile. If `-o` is unavailable or unusable
(e.g., the running `codex exec` build does not support it, or the
file cannot be written), the wrapper treats this as a **runtime
prerequisite failure** per § Runtime Prerequisites and emits a
`.failed.md` debug artifact naming the missing prerequisite. It does
not attempt a second capture path under this contract.

### 3. Schema Ownership

`parent-plan-review.v1.schema.json` is a **shared protocol schema**.
The wrapper (Claude `plan-review`) consumes it; the worker (Codex
`plan-review-worker`) produces output against it. Both sides MUST see
byte-identical copies.

Canonical locations:

- `claude/skills/plan-protocol/references/schemas/parent-plan-review.v1.schema.json`
- `codex/skills/plan-protocol/references/schemas/parent-plan-review.v1.schema.json`

`scripts/check-protocol-sync.sh` is the cross-side sync gate. Its
`files=( … )` and `schema_files=( … )` arrays MUST include
`parent-plan-review.v1.schema.json` on both sides. A change to one
side without the matching change on the other is a sync failure.

#### Closure-map sha256 policy (host-file hash, NOT extracted-section hash)

`reviewed_inputs.closure_map_sha256` is defined as the sha256 of the
**closure-map host file** — i.e., the file referenced by
`closure_map_path` in the structured prefix and by
`expected_closure_map_path` in the provenance block. It is **not**
the hash of the extracted `## Closure map` section text.

Canonical v2 hosting (the only supported hosting):

- In docs-plan v2, parent Full Panel review uses **parent-plan-only**
  closure-map hosting. The closure map is the parent plan's
  `## Closure map` section; the closure-map host file IS the parent
  plan host file. There is no separate-file closure-map override for
  this review path — the Focus Text Prefix Contract preflight
  rejects any `closure_map_path` that does not point at the parent
  plan (see § Focus Text Prefix Contract). The wrapper-computed
  provenance values therefore always satisfy:
  - `closure_map_path == expected_parent_plan_path`
  - `expected_closure_map_path == expected_parent_plan_path`
  - `expected_closure_map_sha256 == expected_parent_plan_sha256` when
    the parent plan host file is readable
  These equalities are not coincidences — both fields name the same
  file and hash the same bytes at the same instant.

`expected_closure_map_sha256 = null` is reserved for the case in
which the closure-map host file itself is **unreadable or absent**
(e.g., the path does not exist or the wrapper has no permission to
read it). It is **not** triggered by the parent plan host file being
readable but lacking a `## Closure map` section: missing-section is a
**semantic closure-context concern**, not a provenance concern, and
it does not change the provenance hash. Specifically:

- If the parent plan host file is readable, `expected_closure_map_sha256`
  equals `sha256(host file bytes)`, which under canonical v2
  parent-plan-only hosting equals `expected_parent_plan_sha256`. This
  holds regardless of whether the file contains a `## Closure map`
  section.
- If the worker, after reading the host file, finds no `## Closure
  map` section, the worker handles that as a semantic warning per the
  Codex worker's "missing / unreadable error handling — no silent
  ignore" obligation (it emits a missing-section warning finding and
  proceeds without closure context). The wrapper does **not** flip
  `expected_closure_map_sha256` to `null` to reflect that semantic
  absence.
- `expected_closure_map_sha256 = null` **only** when the host file is
  unreadable or absent — i.e., when there is genuinely no file to
  hash. A missing-but-expected closure-map host file is a wrapper
  preflight error, surfaced before any Codex call runs; it is not
  silently nulled.

This split keeps provenance (host-file bytes hash) decoupled from
semantic context (presence of the `## Closure map` section inside
those bytes).

Separation of concerns:

- **Semantic review context (worker reads)** — the Codex worker
  reads `closure_map_path` and extracts only the `## Closure map`
  section as closure context for finding emission. The worker MUST
  NOT compute the closure-map sha256 itself; it echoes the
  wrapper-supplied `expected_closure_map_sha256` verbatim.
- **Provenance validation (wrapper checks)** — the wrapper validates
  `reviewed_inputs.closure_map_sha256` against the host-file hash
  it computed before dispatch, never against the extracted-section
  text.

This split prevents two failure modes:

- The worker fabricating or guessing a sha256 from the section text
  it happens to read.
- The wrapper accidentally validating against a section-text hash
  (which would change every time the section is edited even though
  the host file's other content stays stable, and would fail every
  time the host file has edits outside the section even though the
  section is unchanged).

### 4. Wrapper Invariants (post-schema-validation)

The `codex exec --output-schema` runtime enforces the OpenAI Structured
Outputs subset, not full JSON Schema. That subset:

- **does NOT support** `allOf`, `anyOf`, `oneOf`, `not`, `if`, `then`,
  `else`, `uniqueItems` over object properties, or external-data
  comparison;
- **requires every declared property to appear in `required`** (there
  are no optional properties; conditional presence is expressed by
  declaring the field as nullable in `type` and treating `null` as the
  "absent" value).

Consequently the schema cannot express:

- conditional shape constraints such as "`status = "findings"` implies
  `finding_ids` non-null and `reason` null" — these become wrapper
  invariants;
- conditional presence of `delta_scope` keyed on `review_scope` — this
  becomes a wrapper invariant;
- conditional presence of `closure_map_sha256` keyed on closure-map
  existence — this becomes a wrapper invariant;
- uniqueness of `lens` token across `lens_results[]` — this becomes a
  wrapper invariant.

#### Required-nullable fields in the schema

The following fields appear in the schema's top-level `required` array
**and** accept `null` as a valid value. Their semantic constraints
(when null is allowed, when it is forbidden) are enforced by the
wrapper, not the schema:

| field | nullable when | non-null required when (wrapper-enforced) |
|---|---|---|
| `delta_scope` (top-level) | `review_scope = "full"` | `review_scope = "delta"` |
| `closure_map_sha256` (under `reviewed_inputs`) | the closure map file is absent | the closure map file exists at `closure_map_path` |
| `finding_ids` (per `lens_results[]` entry) | `status ∈ {"no_findings", "n_a"}` | `status = "findings"` (and length ≥ 1) |
| `reason` (per `lens_results[]` entry) | `status ∈ {"findings", "no_findings"}` | `status = "n_a"` |

Wrappers MUST NOT treat presence-of-field as semantic evidence; under
Structured Outputs subset rules, the field is **always present** — the
distinction is null vs non-null.

#### Wrapper invariant list

The wrapper applies these invariants in code AFTER `--output-schema`
validation passes; any invariant failure is treated identically to a
schema validation failure (stop, `.failed.md`, no reconcile input):

1. **Lens uniqueness** — `lens_results[*].lens` MUST be the canonical
   seven-element set: `cto-problem-definition`, `implementer`,
   `operator`, `qa`, `maintainer`, `docs-usability`, `risk-rollout`,
   each appearing exactly once. Duplicates or missing lenses fail.
2. **Finding-lens membership** — every `findings[*].lens` MUST appear
   in `lens_results[*].lens`.
3. **Status ↔ field nullability** — per the required-nullable table
   above, enforce these per-lens conditions:
   - `status = "findings"` → `finding_ids` non-null, length ≥ 1,
     `reason` null;
   - `status = "no_findings"` → `finding_ids` null, `reason` null;
   - `status = "n_a"` → `finding_ids` null, `reason` non-null.
4. **Empty-lens has no findings** — for entries where
   `lens_results[*].status ∈ {"no_findings", "n_a"}`, no element in
   `findings[*].lens` may reference that lens token. For
   `status = "findings"` entries, the multiset of
   `findings[*].lens == this_lens` MUST equal `finding_ids` exactly
   (each id matches a `findings[*].id` and counts agree).
5. **Finding-id format and uniqueness** — `findings[*].id` MUST match
   `^F-[0-9]{3}$` (the `pattern` keyword is supported by the
   Structured Outputs subset, so this is schema-enforced) AND be
   unique across the array (wrapper-enforced — `uniqueItems` over
   derived keys is not supported).
6. **Echoed-field consistency (directive vs provenance split)** — the
   wrapper compares JSON payload fields against **two disjoint
   sources** depending on which field is being checked:
   - **Directive half (from the structured prefix on the focus-text
     line)** — the JSON top-level fields `review_scope`,
     `review_severity`, `delta_scope`, `closure_map_path`, and
     `recovery_mode` MUST equal the directive routing values the
     wrapper emitted in the `<<<plan-review>>>` prefix.
   - **Provenance half (from the wrapper-computed provenance block in
     the prompt body)** — the JSON `schema_version` field and the
     `reviewed_inputs.*` fields (`git_head`, `parent_plan_path`,
     `parent_plan_sha256`, `closure_map_sha256`, `reviewed_files`)
     MUST equal the `expected_*` values the wrapper computed and
     injected into the prompt-body provenance block. These values are
     **not** carried in the structured prefix; the worker MUST NOT
     infer them from the prefix.
   **Wire-form ↔ JSON-null normalization (directive half)**: the
   focus-text prefix uses conditional key emission for `delta_scope`
   (the key is omitted when `review_scope = "full"`; the key is
   emitted as `delta_scope=<canonical encoding>` when
   `review_scope = "delta"`), while the JSON payload uses
   required-nullable representation (`delta_scope` is always present,
   `null` for `full`, the canonical encoding string for `delta`). The
   wrapper compares the two layers AFTER normalizing the wire form
   into expected-JSON form:
   - wire-form `delta_scope` omitted (full case) ⇒ expected JSON
     `delta_scope == null`
   - wire-form `delta_scope=<value>` (delta case) ⇒ expected JSON
     `delta_scope == "<value>"`
   Do **not** compare raw key-presence between the prefix and the
   JSON; presence diverges by design and is not an echo violation on
   its own.
7. **`delta_scope` nullability** — in the JSON payload (not the
   wire form), `delta_scope` is `null` iff `review_scope = "full"`,
   and non-null iff `review_scope = "delta"`.
8. **Reviewed-inputs hashes (against provenance block)** —
   - `reviewed_inputs.parent_plan_sha256` MUST equal
     `expected_parent_plan_sha256` from the provenance block
     (computed by the wrapper as the sha256 of the parent plan host
     file at invocation time).
   - `reviewed_inputs.closure_map_sha256` MUST equal
     `expected_closure_map_sha256` from the provenance block
     (the sha256 of the **closure-map host file**, per § 3 Closure-map
     sha256 policy — NOT the hash of the extracted `## Closure map`
     section). It is `null` iff the provenance block declares
     `expected_closure_map_sha256 = null`, which happens only when no
     readable closure-map host file exists.
9. **Reviewed-inputs `git_head` (against provenance block)** —
   `reviewed_inputs.git_head` MUST equal `expected_git_head` from the
   provenance block (the wrapper-computed `git rev-parse HEAD`
   captured before the Codex call is dispatched). A different value
   is treated as a stale or fabricated echo and fails. `git_head` is
   a **validated** field, not informational; the worker MUST NOT
   recompute it.
10. **Reviewed-inputs `reviewed_files` (against provenance block)** —
    `reviewed_inputs.reviewed_files` MUST equal `expected_reviewed_files`
    from the provenance block as an **unordered set**. Under canonical
    v2 parent-plan-only closure-map hosting (the only supported
    hosting for parent Full Panel review — see § Closure-map sha256
    policy and § Focus Text Prefix Contract preflight):
    - `expected_reviewed_files` is a **single-element array** holding
      the parent plan absolute path; the parent plan host file is the
      only file the worker reads, because the closure map IS the
      parent plan's `## Closure map` section.
    - `reviewed_inputs.reviewed_files` MUST equal that single-element
      set exactly. Any additional path (anything outside the parent
      plan) is a contract violation surfaced as a wrapper-invariant
      failure, not silently accepted as evidence.
    `reviewed_files` is a **validated** field, not informational;
    the worker MUST NOT expand or substitute paths.
11. **Schema-version echo (against provenance block)** —
    `schema_version` MUST equal `expected_schema_version` from the
    provenance block (always the constant `"parent-plan-review.v1"`
    for this wrapper). This duplicates the schema-side **singleton
    `enum` enforcement** — both copies of `parent-plan-review.v1.schema.json`
    define `schema_version` as `{"type": "string", "enum":
    ["parent-plan-review.v1"]}` (the OpenAI Structured Outputs subset
    permits `enum` but does not include `const`, so a singleton enum
    is the structured-output-compatible shape and MUST be preserved
    when the schema is edited) — but is included here so the
    directive-vs-provenance split is exhaustive.

These invariants are deliberately wrapper-side because the OpenAI
Structured Outputs subset cannot express them. The schema captures
the always-present shape; the wrapper captures the conditional
semantics.

### 5. Schema validation and failure handling

After Codex returns, the wrapper applies these checks in order and
treats any failure as a wrapper-level failure. Failed reviews never
produce a success artifact and are never handed to `/plan-reconcile`.

**Coverage statement.** All wrapper invariants listed in § 4 are
failure conditions handled by this table — the rows below call out
common and user-locked failure modes explicitly but do **not** limit
the invariant set. Any § 4 invariant failure stops the call, writes
`.failed.md`, and never produces reconcile input, with or without a
dedicated row below.

| failure | retry | result |
|---|---|---|
| `codex exec` non-zero exit, missing `--output-schema` support, or sandbox refusal | no | stop as runtime prerequisite blocker; write `.failed.md` debug artifact |
| `-o <output-file>` is missing, empty, or not valid JSON (the sole canonical capture path; stdout-only fallback is **not** supported — see § 2 Structured output is canonical) | no | stop/escalate; write `.failed.md` |
| structured payload is not valid against `parent-plan-review.v1` | no | stop/escalate; write `.failed.md` |
| `schema_version` ≠ `expected_schema_version` from the provenance block (always the constant `"parent-plan-review.v1"`) — § 4 invariant #11 | no | stop/escalate; write `.failed.md` |
| `reviewed_inputs.parent_plan_path` ≠ `expected_parent_plan_path` from the provenance block — § 4 invariant #6 (provenance half) | no | stop/escalate; write `.failed.md` |
| `reviewed_inputs.parent_plan_sha256` ≠ `expected_parent_plan_sha256` from the provenance block (wrapper-computed sha256 of the parent plan host file at invocation time) — § 4 invariant #8 | no | stop/escalate; write `.failed.md` |
| `reviewed_inputs.closure_map_sha256` ≠ `expected_closure_map_sha256` from the provenance block, **including the expected-null case** (the JSON value MUST be `null` iff the provenance block declares `expected_closure_map_sha256 = null`; any other mismatch — wrong hash, non-null when null was expected, null when non-null was expected — fails). Note: `expected_closure_map_sha256` is the host-file sha256 per § 3 Closure-map sha256 policy, NOT the extracted `## Closure map` section hash. — § 4 invariant #8 | no | stop/escalate; write `.failed.md` |
| `reviewed_inputs.git_head` ≠ `expected_git_head` from the provenance block (wrapper-computed `git rev-parse HEAD` captured before dispatch) — § 4 invariant #9; `git_head` is a validated field, not informational | no | stop/escalate; write `.failed.md` |
| `reviewed_inputs.reviewed_files` ≠ `expected_reviewed_files` from the provenance block as an unordered set — under canonical v2 parent-plan-only hosting, `expected_reviewed_files` is the single-element array containing the parent plan absolute path; this row fails on missing parent plan path, or any extra path outside that single-element set — § 4 invariant #10; `reviewed_files` is a validated field, not informational | no | stop/escalate; write `.failed.md` |
| `review_scope`, `review_severity`, `closure_map_path`, or `recovery_mode` in the JSON payload ≠ the directive routing value the wrapper sent in the `<<<plan-review>>>` structured prefix on the focus-text first line (directive half of § 4 invariant #6) | no | stop/escalate; write `.failed.md` |
| `delta_scope` in the JSON payload fails the directive-half echo for **any** of these three reasons: (a) `delta_scope != null` when `review_scope = "full"` (nullability mismatch); (b) `delta_scope == null` when `review_scope = "delta"` (nullability mismatch); (c) `delta_scope` is non-null when `review_scope = "delta"` **but its value differs from the canonical encoding the wrapper sent in the focus-text prefix** (value mismatch, per § 4 invariant #6 directive-half wire-form ↔ JSON-null normalization: `wire-form delta_scope=<value> ⇒ expected JSON delta_scope == "<value>"`). Note: `delta_scope` is always **present** in JSON under the required-nullable schema; the failure is on null-vs-non-null and on value equality, not on key presence. | no | stop/escalate; write `.failed.md` |
| Any free-text field (other than `findings[].evidence`) contains schema-coercion or contradiction phrases such as `cannot complete as requested`, `schema limitation`, `not in the schema`, `forced by schema`, `Verdict: approve / no material findings`, or `code diff` | no | stop/escalate; write `.failed.md` (an adversarial-runtime pivot signature) |
| `lens_results` does not contain exactly the seven canonical lenses, or contains duplicates (§ 4 invariant #1 — wrapper-enforced) | no | stop/escalate; write `.failed.md` |
| any `findings[*].lens` does not appear in `lens_results[*].lens` (§ 4 invariant #2, finding-lens membership) | no | stop/escalate; write `.failed.md` |
| `lens_results[*].status = "findings"` paired with `finding_ids == null` or `reason != null`, OR `status = "no_findings"` paired with `finding_ids != null` or `reason != null`, OR `status = "n_a"` paired with `finding_ids != null` or `reason == null` (§ 4 invariant #3, status ↔ field nullability) | no | stop/escalate; write `.failed.md` |
| for any `lens_results[*]` entry with `status = "findings"`: the multiset `{f ∈ findings[*] : f.lens == this_lens.lens}.id` does not equal the set in `this_lens.finding_ids` (count mismatch, missing id, or extra id); OR for any entry with `status ∈ {"no_findings", "n_a"}` there exists a `findings[*]` element whose `lens` matches this lens (§ 4 invariant #4, empty-lens / finding_ids agreement) | no | stop/escalate; write `.failed.md` |
| `findings[*].id` values are not unique across the array (§ 4 invariant #5, wrapper-enforced uniqueness — the `^F-[0-9]{3}$` pattern itself is schema-enforced) | no | stop/escalate; write `.failed.md` |

`schema-invalid output`, `missing structured output`, `reviewed
path/hash mismatch`, and `schema coercion` are explicit failure modes
per the user-locked contract. None of them produce a reconcile input.

The `.failed.md` debug artifact lives at
`${current_check_root}/<parent-basename>-review.failed.md` and may
contain the `codex exec` exit code, the captured `-o` output file
contents (the sole canonical capture path), the schema validation
error output, and the wrapper invariant that failed. If `-o` was
unusable and the call failed as a runtime prerequisite blocker,
`.failed.md` records that prerequisite by name; raw stdout is not a
fallback capture. Redact auth tokens, secrets, and environment dumps.

## Focus Text Prefix Contract

Every Codex `plan-review-worker` invocation passes a structured
prefix on the focus-text first line. The Codex worker parses this
v2 marker (renamed from the Phase 1 bridge marker
`<<<docs-plan-review>>>` during Phase 2 cleanup; the worker now
parses `<<<plan-review>>>` only):

```
<<<plan-review>>> review_scope=<full|delta> review_severity=<full-panel|blocking-only> [delta_scope=<canonical encoding>] closure_map_path=<project-root>/plan/families/<parent>.md recovery_mode=<auto|manual>
```

Five-key contract: 4 mandatory keys plus conditional `delta_scope`.
The four always-mandatory keys (`review_scope`, `review_severity`,
`closure_map_path`, `recovery_mode`) are emitted on every call.
`delta_scope` is conditional — emitted only when `review_scope=delta`,
forbidden (key omitted from the wire form) when `review_scope=full`.
A full-scope call therefore emits exactly 4 actual keys on the wire,
not 5; "five-key contract" refers to the schema of the contract, not
the per-call key count.

Caller-side preflight rejects malformed invocations before any Codex
call runs:

- `full` + `delta_scope` combination → reject.
- missing any always-mandatory key → reject.
- missing `delta_scope` when `review_scope=delta` → reject.
- silent normalization of any key to its spec default → forbidden.
- `closure_map_path` not absolute or not pointing at the parent plan
  → reject.

The structured-prefix values (4 mandatory keys plus conditional
`delta_scope`) MUST equal the values the wrapper expects to see
echoed in the `parent-plan-review.v1` top-level fields; any drift
between sent and returned values is a failure (see § Schema
validation and failure handling above).

**Wire-form ↔ JSON-null normalization (echo comparison).** The wire
form uses conditional key emission for `delta_scope`, while the JSON
payload uses required-nullable representation. The echo check is
performed **after** the wrapper normalizes the wire form into
expected-JSON form:

- wire-form `delta_scope` omitted (full case) ⇒ expected JSON
  `delta_scope == null`
- wire-form `delta_scope=<canonical encoding>` (delta case) ⇒
  expected JSON `delta_scope == "<canonical encoding>"`

The wrapper MUST NOT compare raw key-presence across the two layers;
presence diverges by design (wire form is conditional, JSON is
required-nullable) and is not an echo violation on its own. The four
always-mandatory keys (`review_scope`, `review_severity`,
`closure_map_path`, `recovery_mode`) are present in both the wire
form and the JSON; their echo check is a straightforward string
equality.

See Codex `plan-review-worker/references/review.md` for the worker-side
parser details.

## Structured-JSON → F-NNN Markdown Rendering

The wrapper deterministically renders the structured payload into the
`## Codex output` Markdown so reconcile's existing F-NNN reader (see
`plan-reconcile/SKILL.md` step 2) keeps working.

Rendering rules:

1. Emit the seven lens sections in the canonical order:
   1. CTO / Problem-Definition
   2. Implementer
   3. Operator
   4. QA
   5. Maintainer
   6. Docs Usability
   7. Risk / Rollout
2. The lens display name is mapped from the schema lens token:
   - `cto-problem-definition` → `CTO / Problem-Definition`
   - `implementer` → `Implementer`
   - `operator` → `Operator`
   - `qa` → `QA`
   - `maintainer` → `Maintainer`
   - `docs-usability` → `Docs Usability`
   - `risk-rollout` → `Risk / Rollout`
3. Under each lens heading, render based on `lens_results[].status`:
   - `findings` → list every finding whose `lens` matches this heading,
     in ascending `id` order, using the per-finding block in rule 4.
     The id list MUST equal the lens entry's `finding_ids`.
   - `no_findings` → render exactly `_(no material findings)_` on a
     single line and emit no finding block.
   - `n_a` → render exactly `_N/A - <reason>` on a single line and
     emit no finding block.
4. Each finding renders as:

   ```markdown
   #### F-NNN [severity] <title>
   - source lens: <display name>
   - issue: <issue>
   - why it matters: <why_it_matters>
   - evidence: <evidence joined by "; ">
   - suggested action: <suggested_action>
   ```

5. Finding `id`s are taken verbatim from the JSON. The wrapper does
   not renumber; the worker is responsible for source-doc order
   numbering starting at `F-001` (per the worker's output contract).
6. The rendering does NOT merge across lenses. Post-processing (merge
   exact duplicates, split independent risks, parent-escalate
   conversion, related-closure annotation) is the legacy
   `## Normalized findings` advisory section described below — it is
   display-only and not reconcile input.

## Artifact Layout

Saved to `${current_check_root}/<parent-basename>-review.md` per the
plan-protocol § 14 `current_check_root` variable. Canonical resolved
path: `plan/check/<parent-basename>-review.md`.

The artifact contains, in order:

1. `# <Parent basename> review` — top-level title.
2. `## Invocation` — structured prefix as sent (4 mandatory keys plus conditional `delta_scope`; full-scope calls show 4 keys, delta-scope calls show 5), schema path, wrapper
   git head, parent plan sha256, closure map sha256.
3. `## Structured output` — the raw `parent-plan-review.v1` JSON
   payload. Single fenced ```json block. **Canonical decision data.**
4. `## Codex output` — the deterministic F-NNN Markdown rendering of
   the JSON above. **The sole canonical reconcile input.**
5. `## Normalized findings` — optional display-only summary after
   post-processing (merge / split / parent-escalate / closure-related
   annotation). Reconcile MUST NOT consume this section; if it
   disagrees with `## Codex output`, the rendering wins and
   `## Normalized findings` is regenerated.

Sidecar files:

- `${current_check_root}/<parent-basename>-review.failed.md` —
  failure debug artifact (informational, never reconcile input).
- `${current_check_root}/<parent-basename>-review.md.pending` —
  pending sidecar while the call is in flight.

## Bad Artifact Rejection (no-op adversarial + malformed v2)

Some artifacts found under `plan/check/*-review.md` are not canonical
Full Panel review evidence and MUST be rejected before reconcile
consumes them. Two disjoint signature categories trigger rejection;
both share the same atomic-archive-then-rerun recovery procedure
defined at the end of this section. (The section title retains the
historical phrase "no-op adversarial" because the adversarial-runtime
category was the original concern; the second category — malformed
v2 — was added when v2 structured-output rendering introduced shape
contracts the wrapper itself enforces.)

### Category A — No-op adversarial signatures

Artifacts produced by a previous (now-forbidden) routing through
`/codex:adversarial-review` or its `codex-adversarial` subagent.
Signatures (any single one is sufficient to reject; the wrapper does
not require all simultaneously):

- a `Verdict: approve / no material findings` banner.
- missing `## Structured output` JSON section, or a malformed
  `## Structured output` section that cannot be validated as
  `parent-plan-review.v1`. (Standalone reject — independent of the
  no-FNNN signature below.)
- missing `## Codex output` section.
- a `## Invocation` block whose channel is `codex-adversarial`,
  `/codex:adversarial-review`, or the `prompts/adversarial-review.md`
  prompt. (Standalone reject — adversarial invocation channel.)
- `reviewed_inputs.git_head` absent, fabricated, or obviously stale
  (validated via § 4 invariant #9); or `reviewed_inputs.parent_plan_sha256`
  absent or stale.
- no F-NNN entries under `## Codex output` **only when coupled with**
  an adversarial invocation channel (see the row above) or a
  `Verdict: approve / no material findings` banner. A schema-backed
  review with seven `no_findings` lens results is **valid** even
  though it has zero F-NNN entries, and is NOT a no-op signature on
  its own — the coupling clause exists to distinguish the legitimate
  empty-findings case from an adversarial-runtime pivot. (Missing /
  invalid `## Structured output` is not needed as a coupling
  condition here because it is already a standalone reject above.)

### Category B — Malformed v2 `## Codex output` shape signatures (non-adversarial)

Artifacts whose `## Structured output` is **otherwise valid** (i.e.,
present and validates as `parent-plan-review.v1`) but whose
`## Codex output` Markdown does not satisfy the v2
deterministic-rendering contract in § Structured-JSON → F-NNN Markdown
Rendering. These are NOT adversarial-runtime outputs; they are
wrapper-rendering or post-edit failures that violate the per-entry
shape the wrapper guarantees.

Scope boundary: missing or schema-invalid `## Structured output` is
NOT a Category B signature — that case is handled either by
Category A (when it is an adversarial-runtime artifact, e.g., a
`/codex:adversarial-review` output with no structured JSON section)
or by the § 5 schema-validation failure handling (when the wrapper
ran the canonical Codex call but the returned payload failed schema
validation). Category B presumes a structurally valid
`## Structured output` and an inconsistent / shape-violating
`## Codex output` Markdown — i.e., the JSON is fine but the Markdown
rendering of it is not.

Signatures (any single one is sufficient to reject):

- any F-NNN entry under `## Codex output` containing a `contributing
  lenses:` line (or any other multi-lens aggregator field) instead of
  exactly one `source lens:` line. The v2 rendering rule guarantees
  one `source lens:` line per F-NNN block; merged / normalized shapes
  belong in the **separate** optional `## Normalized findings`
  section, not in `## Codex output`. See
  `plan-reconcile/references/plan-review-closure.md` § "Triage Input
  Forms".
- any F-NNN entry under `## Codex output` missing the mandatory
  per-finding sub-fields (`source lens:`, `issue:`, `why it matters:`,
  `evidence:`, `suggested action:`) prescribed by the rendering rule.
- F-NNN ids under `## Codex output` that do not match `^F-[0-9]{3}$`,
  are duplicated within the section, or do not correspond 1:1 with
  entries in `## Structured output`'s `findings[]` array.
- `## Codex output` lens section ordering / lens display names that
  do not match the canonical mapping in § Structured-JSON → F-NNN
  Markdown Rendering rule 2.
- `## Normalized findings` content has been placed under the
  `## Codex output` heading (or the two sections have been merged).

A Category-B signature indicates the v2 deterministic-rendering
contract is broken for this artifact. Treat it as a wrapper-output
integrity failure: reconcile MUST NOT consume the artifact.

### Rejection rule (both categories)

Artifacts matching any signature in either Category A or Category B
are not canonical Full Panel reviews. They MUST NEVER be promoted
into `/plan-reconcile` input.

### Recovery rule — atomic-archive-then-rerun (both categories)

When a bad artifact (Category A or Category B) is detected at
`${current_check_root}/<parent-basename>-review.md`:

1. Identify the trio:
   - `<parent-basename>-review.md`
   - `<parent-basename>-review.md.pending` (if it exists)
   - `<parent-basename>-review.failed.md` (if it exists)
2. Move all existing members of the trio to
   `${current_check_root}/archive/<cycle-id>/` as a single batch.
   `<cycle-id>` is an ISO-8601 UTC timestamp + short random suffix,
   chosen by the wrapper.
3. If any move fails, restore any partial moves and stop — do **not**
   re-run the review. Partial archive is forbidden.
4. Only after the archive batch succeeds, re-invoke the canonical
   `codex exec --output-schema parent-plan-review.v1` flow.

The wrapper does not silently overwrite an existing
`<parent-basename>-review.md`. Every replacement goes through the
archive batch above. The recovery procedure is identical for both
categories — adversarial no-op and malformed v2 both require the
same atomic-archive-then-rerun primitive; the distinction is
classification (and what counts as "fixed" on rerun), not recovery
mechanics.

## Caller-side Scope-aware Contract

Reconcile (not this skill) decides whether a re-review is needed
after material change. When reconcile triggers a re-review, it
derives `delta_scope` itself and emits the structured prefix; the
worker only parses what reconcile sends. This skill enforces preflight
on the caller side per the prefix contract above and the schema
contract in § Execution Channel.

## Stop Gate

- Stop after the success artifact is saved. The next stage is
  `/plan-reconcile`.
- Do not triage findings in this skill.
- Do not append any `family_status` entry (single-writer rule —
  reconcile owns `parent_review_converged` and `policy-locked`).
- Schema-invalid, missing-structured-output, path/hash mismatch, and
  schema-coercion outcomes never produce a success artifact and never
  flow to `/plan-reconcile` — they end at `.failed.md` and stop.

## Removed Legacy Path

`docs-plan-review` was a Phase 1 to Phase 2 bridge and is removed
after Phase 2 cleanup. New work must use `plan-review`; child plan
review must use Codex `draft-review`.

## Cross-References

- [plan-protocol § 5](../plan-protocol/references/plan-protocol.md) — `## Status` invariants (this skill does not write here)
- [plan-protocol § 14](../plan-protocol/references/plan-protocol.md) — `current_check_root` and PLAN_ROOT
- [parent-plan-review.v1 schema](../plan-protocol/references/schemas/parent-plan-review.v1.schema.json) — canonical structured-output shape
- `plan-reconcile` — next stage; triages `## Codex output` F-NNN entries
- Codex `plan-review-worker` — the worker invoked behind this wrapper
- Codex `draft-review` + Claude `draft-intent-worker` — the v2 child plan review path (separate from this skill)
