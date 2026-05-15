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
