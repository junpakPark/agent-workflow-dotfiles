#!/usr/bin/env bash
set -euo pipefail

mode="symlink"
dry_run=0

usage() {
  cat <<'USAGE'
Usage: scripts/install-skills.sh [--copy] [--dry-run]

Installs repo-managed Claude and Codex skills.

Default:
  symlink claude/skills/* to ${HOME}/.claude/skills/*
  symlink codex/skills/* to ${HOME}/.codex/skills/*

Options:
  --copy     copy skill directories instead of symlinking
  --dry-run  print planned actions without changing files
  -h, --help show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --copy)
      mode="copy"
      ;;
    --dry-run)
      dry_run=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

run() {
  if [[ "${dry_run}" -eq 1 ]]; then
    printf 'dry-run:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

install_one() {
  local src="$1"
  local dest_dir="$2"
  local name
  local dest

  name="$(basename "${src}")"
  dest="${dest_dir}/${name}"

  if [[ ! -d "${src}" ]]; then
    return
  fi

  if [[ "${dry_run}" -eq 1 ]]; then
    echo "dry-run: ensure directory ${dest_dir}"
  else
    mkdir -p "${dest_dir}"
  fi

  if [[ -L "${dest}" ]]; then
    run rm "${dest}"
  elif [[ -e "${dest}" ]]; then
    echo "refusing to overwrite non-symlink target: ${dest}" >&2
    echo "move or remove that directory manually, then rerun this script." >&2
    exit 1
  fi

  if [[ "${mode}" == "copy" ]]; then
    run cp -R "${src}" "${dest}"
  else
    run ln -s "${src}" "${dest}"
  fi
}

install_group() {
  local src_dir="$1"
  local dest_dir="$2"
  local src

  for src in "${src_dir}"/*; do
    [[ -d "${src}" ]] || continue
    install_one "${src}" "${dest_dir}"
  done
}

install_group "${repo_root}/claude/skills" "${HOME}/.claude/skills"
install_group "${repo_root}/codex/skills" "${HOME}/.codex/skills"

if [[ "${mode}" == "copy" ]]; then
  echo "skill install complete (copy)"
else
  echo "skill install complete (symlink)"
fi
