#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

files=(
  "plan-protocol/references/plan-protocol.md"
  "plan-protocol/references/probes.md"
  "plan-protocol/references/schemas/child-checkpoint.plan_intent.schema.json"
  "plan-protocol/references/schemas/child-checkpoint.test_intent.schema.json"
  "plan-protocol/references/schemas/parent-plan-review.v1.schema.json"
)

failed=0

if ! command -v jq >/dev/null 2>&1; then
  echo "protocol sync mismatch: missing jq"
  exit 1
fi

for file in "${files[@]}"; do
  claude_ref="${repo_root}/claude/skills/${file}"
  codex_ref="${repo_root}/codex/skills/${file}"

  if [[ ! -f "${claude_ref}" || ! -f "${codex_ref}" ]]; then
    echo "protocol sync mismatch:"
    [[ -f "${claude_ref}" ]] || echo "missing ${claude_ref}"
    [[ -f "${codex_ref}" ]] || echo "missing ${codex_ref}"
    failed=1
    continue
  fi

  claude_sha="$(shasum -a 256 "${claude_ref}" | awk '{print $1}')"
  codex_sha="$(shasum -a 256 "${codex_ref}" | awk '{print $1}')"

  if [[ "${claude_sha}" != "${codex_sha}" ]]; then
    echo "protocol sync mismatch:"
    echo "${claude_ref} ${claude_sha}"
    echo "${codex_ref} ${codex_sha}"
    failed=1
  fi
done

schema_files=(
  "${repo_root}/claude/skills/plan-protocol/references/schemas/child-checkpoint.plan_intent.schema.json"
  "${repo_root}/claude/skills/plan-protocol/references/schemas/child-checkpoint.test_intent.schema.json"
  "${repo_root}/claude/skills/plan-protocol/references/schemas/parent-plan-review.v1.schema.json"
  "${repo_root}/codex/skills/plan-protocol/references/schemas/child-checkpoint.plan_intent.schema.json"
  "${repo_root}/codex/skills/plan-protocol/references/schemas/child-checkpoint.test_intent.schema.json"
  "${repo_root}/codex/skills/plan-protocol/references/schemas/parent-plan-review.v1.schema.json"
)

for schema_file in "${schema_files[@]}"; do
  if ! jq empty "${schema_file}" >/dev/null; then
    echo "schema parse failure: ${schema_file}"
    failed=1
    continue
  fi

  if jq -e 'has("$schema")' "${schema_file}" >/dev/null; then
    echo "schema metadata regression: ${schema_file}: top-level \$schema"
    failed=1
  fi
done

parent_review_schema_files=(
  "${repo_root}/claude/skills/plan-protocol/references/schemas/parent-plan-review.v1.schema.json"
  "${repo_root}/codex/skills/plan-protocol/references/schemas/parent-plan-review.v1.schema.json"
)

parent_review_forbidden_keywords=(
  "allOf"
  "anyOf"
  "oneOf"
  "not"
  "if"
  "then"
  "else"
  "const"
)

for schema_file in "${parent_review_schema_files[@]}"; do
  for keyword in "${parent_review_forbidden_keywords[@]}"; do
    if jq -e --arg keyword "${keyword}" 'any(.. | objects; has($keyword))' "${schema_file}" >/dev/null; then
      echo "parent review schema structured-output keyword regression: ${schema_file}: ${keyword}"
      failed=1
    fi
  done

  if ! jq -e '
    (.properties.schema_version? // null) as $schema_version
    | ($schema_version | type == "object")
    and (($schema_version | keys) == ["enum", "type"])
    and ($schema_version.type == "string")
    and ($schema_version.enum == ["parent-plan-review.v1"])
    and ($schema_version | has("const") | not)
  ' "${schema_file}" >/dev/null; then
    echo "parent review schema_version singleton enum regression: ${schema_file}"
    failed=1
  fi

  missing_required="$(
    jq -r '
      def property_object_paths:
        [], paths(objects | select(has("properties")));

      property_object_paths as $path
      | getpath($path) as $object
      | select(($object | type) == "object" and ($object | has("properties")))
      | (($object.properties | keys_unsorted) - ($object.required // [])) as $missing
      | select(($missing | length) > 0)
      | "\((if ($path | length) == 0 then "." else ($path | map(tostring) | join(".")) end)): \($missing | join(","))"
    ' "${schema_file}"
  )"
  if [[ -n "${missing_required}" ]]; then
    echo "parent review schema structured-output required regression: ${schema_file}"
    echo "${missing_required}"
    failed=1
  fi
done

worker_files=(
  "${repo_root}/claude/skills/draft-intent-worker/SKILL.md"
  "${repo_root}/claude/skills/test-intent-worker/SKILL.md"
)

for worker_file in "${worker_files[@]}"; do
  if grep -E -n \
    -e 'Returns a `child-checkpoint' \
    -e 'Print the `child-checkpoint' \
    -e 'Nothing else is printed' \
    -e 'Closed envelope' \
    -e 'stdout-only JSON' \
    -e 'JSON\.parse\(stdout' \
    -e 'Bare JSON' \
    -e 'bare JSON' \
    -e 'Markdown fence' \
    -e 'Markdown code fence' \
    "${worker_file}"; then
    echo "worker transport regression: ${worker_file}"
    failed=1
  fi
done

wrapper_files=(
  "${repo_root}/codex/skills/draft-review/SKILL.md"
  "${repo_root}/codex/skills/test-review/SKILL.md"
)

required_wrapper_phrases=(
  ".structured_output"
  "schema-coercion"
  "schema_json"
  "prompt file"
  "nested shell heredoc"
  "schema path is the source file only"
  "cannot complete as requested"
  "schema limitation"
  "not in the schema"
  "forced by schema"
  "quote and evidence field paths"
)

for wrapper_file in "${wrapper_files[@]}"; do
  for phrase in "${required_wrapper_phrases[@]}"; do
    if ! grep -F -q -- "${phrase}" "${wrapper_file}"; then
      echo "wrapper invariant phrase missing: ${wrapper_file}: ${phrase}"
      failed=1
    fi
  done
done

schema_invocation_files=(
  "${repo_root}/codex/skills/draft-review/SKILL.md"
  "${repo_root}/codex/skills/test-review/SKILL.md"
  "${repo_root}/claude/skills/draft-intent-worker/SKILL.md"
  "${repo_root}/claude/skills/test-intent-worker/SKILL.md"
  "${repo_root}/codex/skills/plan-protocol/references/plan-protocol.md"
  "${repo_root}/claude/skills/plan-protocol/references/plan-protocol.md"
)

for schema_invocation_file in "${schema_invocation_files[@]}"; do
  if grep -E -n \
    -e '--json-schema[[:space:]]+references/schemas/' \
    -e '--json-schema[[:space:]]+\.\./plan-protocol/references/schemas/' \
    "${schema_invocation_file}"; then
    echo "schema path invocation regression: ${schema_invocation_file}"
    failed=1
  fi
done

failed_artifact_files=(
  "${repo_root}/codex/skills/draft-review/SKILL.md"
  "${repo_root}/codex/skills/test-review/SKILL.md"
  "${repo_root}/codex/skills/plan-protocol/references/plan-protocol.md"
  "${repo_root}/claude/skills/plan-protocol/references/plan-protocol.md"
)

for failed_artifact_file in "${failed_artifact_files[@]}"; do
  if grep -F -n -- 'failed-2' "${failed_artifact_file}"; then
    echo "failed artifact retry regression: ${failed_artifact_file}"
    failed=1
  fi
done

if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi

echo "protocol sync OK"
