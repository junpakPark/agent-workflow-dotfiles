# Agent Workflow Dotfiles

한국어: [README.ko.md](README.ko.md)

This repo manages project-neutral agent workflow assets:

- Claude and Codex skills in dotfiles form.
- A shared protocol reference that must stay byte-identical across both ecosystems.
- A reusable PLAN_ROOT skeleton for bootstrapping new projects.

## Project Neutrality Rule

Git-managed files in this repo must stay project-neutral. Do not commit specific project names, customer names, absolute local repo paths, runtime artifact identifiers, auth files, logs, history files, local databases, caches, plugin caches, or project-specific `plan/` artifacts. Acceptable placeholders are `<repo-root>`, `<project-root>`, and `${HOME}`.

## Repo Structure

- `claude/skills/` - Claude planning and intent-review skills.
- `codex/skills/` - Codex execution, review, quality, and finalization skills.
- `templates/plan-root/` - empty PLAN_ROOT skeleton and generic `LEGACY_PATH_MAP.md`.
- `scripts/install-skills.sh` - installs skills to Claude and Codex homes.
- `scripts/bootstrap-plan-root.sh` - creates `plan/` skeleton in a target project.
- `scripts/check-protocol-sync.sh` - compares Claude/Codex protocol reference SHA256 values.

## Prerequisites

- Claude home is `${HOME}/.claude`.
- Codex home is `${HOME}/.codex`.
- Symlink install is the default.
- If an installed target skill path already exists as a real directory, the install script stops instead of overwriting it.
- If an installed target skill path is already a symlink, the install script may replace that symlink.

## First Install Runbook

1. Clone this repo by your standard Git remote into `<repo-root>` if needed, then confirm and enter it:

```bash
test -d "<repo-root>/.git"
cd "<repo-root>"
```

2. Verify protocol sync:

```bash
scripts/check-protocol-sync.sh
```

3. Preview skill installation:

```bash
scripts/install-skills.sh --dry-run
```

4. Install skills with symlinks:

```bash
scripts/install-skills.sh
```

5. Confirm installed targets:

```bash
ls -la "${HOME}/.claude/skills"
ls -la "${HOME}/.codex/skills"
```

## Copy Install

Use copy mode only when symlinks are not appropriate for the machine:

```bash
cd "<repo-root>"
scripts/install-skills.sh --copy
```

Symlink mode reflects future repo changes immediately after `git pull`. Copy mode creates independent directories under `${HOME}/.claude/skills` and `${HOME}/.codex/skills`; after `git pull`, move stale copied skill directories aside and rerun `scripts/install-skills.sh --copy`.

## Bootstrap A Project PLAN_ROOT

Run this from the dotfiles repo:

```bash
cd "<repo-root>"
scripts/bootstrap-plan-root.sh "<project-root>"
```

The script creates:

- `<project-root>/plan/families`
- `<project-root>/plan/check`
- `<project-root>/plan/archive`
- `<project-root>/plan/roadmap`
- `<project-root>/plan/manual`
- `<project-root>/plan/LEGACY_PATH_MAP.md`

Each empty directory receives `.gitkeep`. Existing files are not overwritten. If `<project-root>/.gitignore` does not contain `plan/`, the script appends it. If `<project-root>/.gitignore` does not exist, the script creates it with `plan/`.

The bootstrap script stops instead of creating canonical `plan/` if any
legacy docs-based plan root exists:

- `<project-root>/docs/plan`
- `<project-root>/docs/check`
- `<project-root>/docs/archive`
- `<project-root>/docs/roadmap`
- `<project-root>/docs/runbook`

Migration or artifact moves require explicit user approval outside this
script.

## PLAN_ROOT Preflight In Skills

Each `plan-*`, `exec-*`, and `finalize-*` stage skill must apply the
PLAN_ROOT preflight before reading or writing plan artifacts:

- If canonical `plan/` is absent, report that bootstrap is required.
- If `docs/plan`, `docs/check`, `docs/archive`, `docs/roadmap`, or
  `docs/runbook` exists, stop and report the legacy conflict.
- If only some canonical directories are missing and no legacy conflict
  exists, create the missing directories idempotently.
- Never overwrite existing files.
- Never migrate or move artifacts without explicit user approval.

## Update Procedure

For symlink installs:

```bash
cd "<repo-root>"
git pull
scripts/check-protocol-sync.sh
```

For copy installs:

```bash
cd "<repo-root>"
git pull
scripts/check-protocol-sync.sh
scripts/install-skills.sh --copy
```

If copy install stops because a target is a real directory, move that target aside first and rerun the copy install.

## Validation

Run these checks from `<repo-root>`:

```bash
scripts/check-protocol-sync.sh
bash -n scripts/install-skills.sh
bash -n scripts/bootstrap-plan-root.sh
bash -n scripts/check-protocol-sync.sh
find . -type f | sort
```

Check for project-specific strings by setting the terms for the project being audited:

```bash
PROJECT_TERMS='project-name|customer-name|domain-name|absolute-local-repo-path|runtime-artifact-name'
rg -n "${PROJECT_TERMS}" .
```

Run Codex skill validation when the local system validator exists:

```bash
for skill in \
  plan-protocol \
  exec-run \
  exec-draft \
  draft-review \
  exec-tests \
  test-review \
  exec-impl \
  exec-code-quality \
  finalize-run \
  finalize-closeout \
  finalize-archive \
  plan-review-worker \
  code-quality-worker
do
  python "${HOME}/.codex/skills/.system/skill-creator/scripts/quick_validate.py" "codex/skills/${skill}"
done
```

Validate a target project after bootstrap:

```bash
test -d "<project-root>/plan/families"
test -d "<project-root>/plan/check"
test -d "<project-root>/plan/archive"
test -d "<project-root>/plan/roadmap"
test -d "<project-root>/plan/manual"
test -f "<project-root>/plan/LEGACY_PATH_MAP.md"
grep -qxF "plan/" "<project-root>/.gitignore"
```

## Troubleshooting

Existing target skill is a real directory:
Move it aside or inspect it manually. The install script will not overwrite non-symlink skill directories.

Protocol sync mismatch:
Edit one protocol reference, copy the exact final bytes to the other side, then rerun `scripts/check-protocol-sync.sh`.

Target project has no `.gitignore`:
`scripts/bootstrap-plan-root.sh` creates `<project-root>/.gitignore` with `plan/`.

Copy install has stale skills:
Move stale copied skill directories out of `${HOME}/.claude/skills` or `${HOME}/.codex/skills`, then rerun `scripts/install-skills.sh --copy`.

## Security And Privacy

Do not commit:

- `.system` skills.
- Claude or Codex auth files.
- Logs, history, sessions, cache, or local database files.
- Plugin cache or runtime generated files.
- Project-specific `plan/` artifacts.
- Customer, domain, or machine-specific identifiers.
