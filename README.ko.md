# Agent Workflow Dotfiles

English: [README.md](README.md)

이 repo는 프로젝트에 종속되지 않는 agent workflow 자산을 관리합니다:

- Claude와 Codex skills를 dotfiles 방식으로 관리합니다.
- 두 생태계가 공유하는 protocol reference를 byte-identical 상태로 유지합니다.
- 새 프로젝트에 재사용 가능한 PLAN_ROOT skeleton을 bootstrap합니다.

## Project Neutrality Rule

이 repo의 git-managed 파일은 프로젝트 중립성을 유지해야 합니다. 특정 프로젝트명, customer명, 절대 로컬 repo path, runtime artifact 식별자, auth 파일, logs, history 파일, local database, cache, plugin cache, project-specific `plan/` artifact를 커밋하지 않습니다. 허용되는 placeholder는 `<repo-root>`, `<project-root>`, `${HOME}`입니다.

## Repo Structure

- `claude/skills/` - Claude planning 및 intent-review skills.
- `codex/skills/` - Codex execution, review, quality, finalization skills.
- `templates/plan-root/` - 빈 PLAN_ROOT skeleton과 generic `LEGACY_PATH_MAP.md`.
- `scripts/install-skills.sh` - Claude/Codex home에 skills를 설치합니다.
- `scripts/bootstrap-plan-root.sh` - target project에 `plan/` skeleton을 생성합니다.
- `scripts/check-protocol-sync.sh` - Claude/Codex protocol bundle mirror와 structured-output checkpoint 회귀 guard를 검증합니다.

## Prerequisites

- Claude home은 `${HOME}/.claude`입니다.
- Codex home은 `${HOME}/.codex`입니다.
- 기본 설치 방식은 symlink입니다.
- 설치 대상 skill path가 symlink가 아닌 실제 디렉터리로 이미 존재하면 install script는 overwrite하지 않고 멈춥니다.
- 설치 대상 skill path가 이미 symlink이면 install script가 해당 symlink를 교체할 수 있습니다.

## First Install Runbook

1. 필요하면 표준 Git remote로 이 repo를 `<repo-root>`에 clone한 뒤, repo 존재를 확인하고 진입합니다:

```bash
test -d "<repo-root>/.git"
cd "<repo-root>"
```

2. protocol sync를 확인합니다:

```bash
scripts/check-protocol-sync.sh
```

3. skill 설치를 미리 확인합니다:

```bash
scripts/install-skills.sh --dry-run
```

4. symlink 방식으로 skills를 설치합니다:

```bash
scripts/install-skills.sh
```

5. 설치 대상을 확인합니다:

```bash
ls -la "${HOME}/.claude/skills"
ls -la "${HOME}/.codex/skills"
```

## Copy Install

symlink가 적합하지 않은 machine에서만 copy mode를 사용합니다:

```bash
cd "<repo-root>"
scripts/install-skills.sh --copy
```

Symlink mode는 이후 `git pull`만 해도 repo 변경이 즉시 반영됩니다. Copy mode는 `${HOME}/.claude/skills`, `${HOME}/.codex/skills` 아래에 독립적인 디렉터리를 만듭니다. Copy mode에서는 `git pull` 후 stale copied skill directory를 옮긴 뒤 `scripts/install-skills.sh --copy`를 다시 실행합니다.

## Bootstrap A Project PLAN_ROOT

dotfiles repo에서 실행합니다:

```bash
cd "<repo-root>"
scripts/bootstrap-plan-root.sh "<project-root>"
```

script는 다음을 생성합니다:

- `<project-root>/plan/families`
- `<project-root>/plan/check`
- `<project-root>/plan/archive`
- `<project-root>/plan/roadmap`
- `<project-root>/plan/manual`
- `<project-root>/plan/LEGACY_PATH_MAP.md`

각 빈 디렉터리에는 `.gitkeep`이 들어갑니다. 기존 파일은 overwrite하지 않습니다. `<project-root>/.gitignore`에 `plan/`이 없으면 추가합니다. `<project-root>/.gitignore`가 없으면 `plan/`만 포함한 파일을 생성합니다.

bootstrap script는 legacy docs-based plan root가 하나라도 있으면 canonical `plan/`을 만들지 않고 멈춥니다:

- `<project-root>/docs/plan`
- `<project-root>/docs/check`
- `<project-root>/docs/archive`
- `<project-root>/docs/roadmap`
- `<project-root>/docs/runbook`

Migration 또는 artifact move는 이 script 밖에서 사용자 명시 승인이 필요합니다.

## PLAN_ROOT Preflight In Skills

각 `plan-*`, `exec-*`, `finalize-*` stage skill은 plan artifact를 읽거나 쓰기 전에 PLAN_ROOT preflight를 적용해야 합니다:

- canonical `plan/`이 없으면 bootstrap이 필요하다고 보고합니다.
- `docs/plan`, `docs/check`, `docs/archive`, `docs/roadmap`, `docs/runbook`이 있으면 멈추고 legacy conflict를 보고합니다.
- 일부 canonical directory만 없고 legacy conflict가 없으면 missing directory만 idempotent하게 생성합니다.
- 기존 파일은 절대 overwrite하지 않습니다.
- 사용자 명시 승인 없이 artifact를 migrate하거나 move하지 않습니다.

## Update Procedure

Symlink install:

```bash
cd "<repo-root>"
git pull
scripts/check-protocol-sync.sh
```

Copy install:

```bash
cd "<repo-root>"
git pull
scripts/check-protocol-sync.sh
scripts/install-skills.sh --copy
```

Copy install이 target이 실제 디렉터리라는 이유로 멈추면, 해당 target을 먼저 옮긴 뒤 copy install을 다시 실행합니다.

## Validation

`<repo-root>`에서 다음을 실행합니다:

```bash
scripts/check-protocol-sync.sh
bash -n scripts/install-skills.sh
bash -n scripts/bootstrap-plan-root.sh
bash -n scripts/check-protocol-sync.sh
find . -type f | sort
```

감사할 프로젝트에 맞는 project-specific term을 설정한 뒤 검색합니다:

```bash
PROJECT_TERMS='project-name|customer-name|domain-name|absolute-local-repo-path|runtime-artifact-name'
rg -n "${PROJECT_TERMS}" .
```

local system validator가 있을 때 Codex skill validation을 실행합니다:

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

bootstrap 후 target project를 확인합니다:

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
직접 내용을 확인하거나 다른 위치로 옮깁니다. install script는 symlink가 아닌 skill directory를 overwrite하지 않습니다.

Protocol sync mismatch:
Claude/Codex 양쪽의 mirrored protocol bundle을 byte-identical 상태로 유지해야 합니다: `plan-protocol.md`, `probes.md`, `references/schemas/` 아래 checkpoint schema 파일들. sync check는 structured-output checkpoint transport 회귀도 실패 처리합니다. 예: 오래된 bare-stdout 문구, 누락된 wrapper invariant 문구, schema path invocation 문구, `failed-2` debug artifact 문구, checkpoint schema의 top-level `$schema`. 보고된 파일이나 문구를 고치고, mirror가 필요한 파일은 최종 bytes를 반대쪽에 그대로 복사한 뒤 `scripts/check-protocol-sync.sh`를 다시 실행합니다.

Target project has no `.gitignore`:
`scripts/bootstrap-plan-root.sh`가 `<project-root>/.gitignore`를 만들고 `plan/`을 넣습니다.

Copy install has stale skills:
stale copied skill directory를 `${HOME}/.claude/skills` 또는 `${HOME}/.codex/skills` 밖으로 옮긴 뒤 `scripts/install-skills.sh --copy`를 다시 실행합니다.

## Security And Privacy

커밋하지 말아야 할 것:

- `.system` skills.
- Claude 또는 Codex auth files.
- Logs, history, sessions, cache, local database files.
- Plugin cache 또는 runtime generated files.
- Project-specific `plan/` artifacts.
- Customer, domain, machine-specific identifiers.
