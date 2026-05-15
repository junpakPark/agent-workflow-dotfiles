# Structured Output Probe Evidence

Captured on 2026-05-15 in `/Users/junpak/PycharmProjects/agent-plan-workflow`
while preparing the `child-checkpoint.v1` structured-output-only
transport.

## Baseline

- `git status -sb`: `main...origin/main [ahead 2]`; only `.idea/` was
  untracked.
- `git log --oneline --decorate --graph --max-count=12`: latest local
  commits were `e0ca5b0 Preserve identity env for Claude CLI skill
  wrappers` and `c4ead17 Update exec-run to continue selected child
  stages`.
- `claude --help` listed both `--json-schema <schema>` and
  `--output-format <format>` with `json` as a valid output format.

## Minimal Wrapper Shape Probe

Command:

```sh
claude -p --output-format json --json-schema '{"type":"object","properties":{"ok":{"type":"boolean"}},"required":["ok"],"additionalProperties":false}' --tools "" --no-session-persistence 'Return structured output with ok true.'
```

Observed relevant wrapper fields:

```json
{
  "type": "result",
  "subtype": "success",
  "is_error": false,
  "result": "",
  "structured_output": {
    "ok": true
  },
  "terminal_reason": "completed"
}
```

Conclusion: the checkpoint payload is exposed at top-level
`structured_output`. Wrapper `result`, stderr, and debug text are not
checkpoint artifacts.

## Schema Argument Form Probe

Follow-up captured on 2026-05-15 after a downstream run reported a
Claude result wrapper without `structured_output` when using a schema
file path.

File-path command shape:

```sh
claude -p --output-format json --json-schema /private/tmp/claude_json_schema_path_probe.json --tools "" --no-session-persistence 'Return structured output with ok true.'
```

Observed result: bounded with a 20-second `alarm`; no Claude result
wrapper was emitted before timeout and the process exited `142`.

Schema JSON string command shape:

```sh
schema_json="$(jq -c . /private/tmp/claude_json_schema_path_probe.json)"
claude -p --output-format json --json-schema "${schema_json}" --tools "" --no-session-persistence 'Return structured output with ok true.'
```

Observed relevant wrapper fields:

```json
{
  "type": "result",
  "subtype": "success",
  "is_error": false,
  "result": "ok",
  "structured_output": {
    "ok": true
  },
  "terminal_reason": "completed"
}
```

Conclusion: wrappers must pass the schema JSON content to
`--json-schema`, not the schema file path. Schema files remain the
canonical source of truth, but wrappers must load them with `jq -c`
before invoking Claude CLI.

## Schema Metadata Probe

Follow-up captured on 2026-05-15 after the schema JSON string invocation
still produced a Claude wrapper without `structured_output` for the full
`test_intent` schema.

Actual `test_intent` schema with top-level `$schema`:

```sh
schema_json="$(jq -c . codex/skills/plan-protocol/references/schemas/child-checkpoint.test_intent.schema.json)"
claude -p --output-format json --json-schema "${schema_json}" --tools "" --no-session-persistence '<minimal compliant test_intent payload prompt>'
```

Observed relevant wrapper fields:

```json
{
  "is_error": false,
  "terminal_reason": "completed",
  "result": "```json\n{ ... checkpoint JSON ... }\n```"
}
```

No top-level `structured_output` field was present.

The same actual schema with only top-level `$schema` removed:

```sh
schema_json="$(jq -c 'del(."$schema")' codex/skills/plan-protocol/references/schemas/child-checkpoint.test_intent.schema.json)"
claude -p --output-format json --json-schema "${schema_json}" --tools "" --no-session-persistence '<minimal compliant test_intent payload prompt>'
```

Observed relevant wrapper fields:

```json
{
  "is_error": false,
  "terminal_reason": "completed",
  "result": "Structured output submitted successfully.",
  "structured_output": {
    "schema_version": "child-checkpoint.v1",
    "checkpoint": "test_intent",
    "verdict": "approve"
  }
}
```

Targeted metadata probes:

| schema metadata | result |
|---|---|
| top-level `$schema` only | no top-level `structured_output`; wrapper `result` contained `{"ok": true}` |
| top-level `$id` only | top-level `structured_output` present |
| top-level `title` only | top-level `structured_output` present |
| `$defs` + `$ref` | top-level `structured_output` present |

Conclusion: the runtime schema files used with Claude CLI structured
output must omit top-level `$schema`. `$id`, `title`, `$defs`, and
`$ref` may remain.

## Schema Dialect Probe

Command:

```sh
claude -p --output-format json --json-schema '{"type":"object","properties":{"schema_version":{"const":"probe.v1"},"status":{"type":"string","enum":["ok"]},"row_id":{"type":"string","pattern":"^R[0-9]+$"},"rows":{"type":"array","minItems":1,"items":{"type":"object","properties":{"id":{"type":"string","pattern":"^R[0-9]+$"},"verdict":{"type":"string","enum":["match"]}},"required":["id","verdict"],"additionalProperties":false}},"maybe_oneof":{"oneOf":[{"type":"string"},{"type":"null"}]},"maybe_type_array":{"type":["string","null"]},"kind":{"type":"string","enum":["needs_value","none"]},"value":{"type":"string"},"blocked":{"not":{"const":"forbidden"}},"nested":{"type":"object","properties":{"flag":{"type":"boolean"}},"required":["flag"],"additionalProperties":false}},"required":["schema_version","status","row_id","rows","maybe_oneof","maybe_type_array","kind","blocked","nested"],"if":{"properties":{"kind":{"const":"needs_value"}},"required":["kind"]},"then":{"required":["value"]},"additionalProperties":false}' --tools "" --no-session-persistence --model sonnet 'Return structured output: schema_version probe.v1; status ok; row_id R12; rows one item id R1 verdict match; maybe_oneof null; maybe_type_array null; kind needs_value; value present; blocked allowed; nested flag true.'
```

Observed relevant wrapper fields:

```json
{
  "type": "result",
  "subtype": "success",
  "is_error": false,
  "structured_output": {
    "schema_version": "probe.v1",
    "status": "ok",
    "row_id": "R12",
    "rows": [
      {
        "id": "R1",
        "verdict": "match"
      }
    ],
    "maybe_oneof": null,
    "maybe_type_array": null,
    "kind": "needs_value",
    "value": "present",
    "blocked": "allowed",
    "nested": {
      "flag": true
    }
  },
  "terminal_reason": "completed"
}
```

Supported keywords confirmed by this probe:

| keyword / feature | result |
|---|---|
| `required` | supported |
| `enum` | supported |
| `const` | supported |
| nested objects | supported |
| arrays and item schemas | supported |
| array item `required` | supported |
| `additionalProperties: false` | supported |
| `minItems` | supported |
| nullable via `oneOf` | supported |
| nullable via `type: ["string", "null"]` | supported |
| `pattern` | supported |
| `not` | supported |
| `if` / `then` | supported |

Schema files may therefore use these shape and enum constraints. The
wrapper still owns invocation invariants and cross-field semantic checks
called out in the protocol.

Model note: the schema dialect probe above used `--model sonnet`.
Minimal wrapper, schema argument form, schema metadata, and actual
checkpoint schema probes used the default Claude CLI runtime. The
transport constraints in the protocol are based on the actual checkpoint
schema probes; the dialect probe records keyword support only.
