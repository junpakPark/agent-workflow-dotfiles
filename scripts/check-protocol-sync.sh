#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
claude_ref="${repo_root}/claude/skills/plan-protocol/references/plan-protocol.md"
codex_ref="${repo_root}/codex/skills/plan-protocol/references/plan-protocol.md"

if [[ ! -f "${claude_ref}" || ! -f "${codex_ref}" ]]; then
  echo "protocol sync mismatch:"
  [[ -f "${claude_ref}" ]] || echo "missing ${claude_ref}"
  [[ -f "${codex_ref}" ]] || echo "missing ${codex_ref}"
  exit 1
fi

claude_sha="$(shasum -a 256 "${claude_ref}" | awk '{print $1}')"
codex_sha="$(shasum -a 256 "${codex_ref}" | awk '{print $1}')"

if [[ "${claude_sha}" == "${codex_sha}" ]]; then
  echo "protocol sync OK"
  exit 0
fi

echo "protocol sync mismatch:"
echo "${claude_ref} ${claude_sha}"
echo "${codex_ref} ${codex_sha}"
exit 1
