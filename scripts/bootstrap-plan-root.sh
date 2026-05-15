#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/bootstrap-plan-root.sh <project-root>

Creates a local PLAN_ROOT skeleton under <project-root>/plan and appends
plan/ to <project-root>/.gitignore when that ignore entry is absent.
Existing files are not overwritten.
Stops if legacy docs-based plan roots are present.
USAGE
}

if [[ $# -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  usage
  if [[ $# -eq 1 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then
    exit 0
  fi
  exit 2
fi

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
template_root="${repo_root}/templates/plan-root"
target_root="$(CDPATH= cd -- "$1" && pwd)"
plan_root="${target_root}/plan"

legacy_found=0
for legacy in docs/plan docs/check docs/archive docs/roadmap docs/runbook; do
  if [[ -e "${target_root}/${legacy}" ]]; then
    if [[ "${legacy_found}" -eq 0 ]]; then
      echo "legacy PLAN_ROOT conflict found:" >&2
    fi
    echo "${target_root}/${legacy}" >&2
    legacy_found=1
  fi
done

if [[ "${legacy_found}" -ne 0 ]]; then
  echo "stop: resolve or explicitly approve migration before bootstrapping canonical plan/." >&2
  exit 1
fi

for dir in families check archive roadmap manual; do
  mkdir -p "${plan_root}/${dir}"
  if [[ ! -e "${plan_root}/${dir}/.gitkeep" ]]; then
    if [[ -f "${template_root}/${dir}/.gitkeep" ]]; then
      cp "${template_root}/${dir}/.gitkeep" "${plan_root}/${dir}/.gitkeep"
    else
      : > "${plan_root}/${dir}/.gitkeep"
    fi
  fi
done

if [[ ! -e "${plan_root}/LEGACY_PATH_MAP.md" ]]; then
  cp "${template_root}/LEGACY_PATH_MAP.md" "${plan_root}/LEGACY_PATH_MAP.md"
fi

gitignore="${target_root}/.gitignore"
if [[ -f "${gitignore}" ]]; then
  if ! grep -qxF "plan/" "${gitignore}"; then
    printf '\nplan/\n' >> "${gitignore}"
  fi
else
  printf 'plan/\n' > "${gitignore}"
fi

echo "PLAN_ROOT bootstrap complete: ${plan_root}"
