#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

files=(
  "plan-protocol/references/plan-protocol.md"
  "plan-protocol/references/probes.md"
  "plan-protocol/references/schemas/child-checkpoint.plan_intent.schema.json"
  "plan-protocol/references/schemas/child-checkpoint.test_intent.schema.json"
)

failed=0

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

worker_files=(
  "${repo_root}/claude/skills/draft-intent-worker/SKILL.md"
  "${repo_root}/claude/skills/test-intent-worker/SKILL.md"
)

for worker_file in "${worker_files[@]}"; do
  if rg -n \
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
  "cannot complete as requested"
  "schema limitation"
  "not in the schema"
  "forced by schema"
  "quote and evidence fields"
)

for wrapper_file in "${wrapper_files[@]}"; do
  for phrase in "${required_wrapper_phrases[@]}"; do
    if ! rg -q -F "${phrase}" "${wrapper_file}"; then
      echo "wrapper invariant phrase missing: ${wrapper_file}: ${phrase}"
      failed=1
    fi
  done
done

if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi

echo "protocol sync OK"
