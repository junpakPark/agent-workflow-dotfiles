---
name: finalize-archive
description: Archive a completed docs-plan v2 family after finalize-closeout returns archive-ready and the user explicitly approves. Use to snapshot/move local planning artifacts, update legacy path maps, and report archived paths safely.
---

# Finalize Archive

## Overview

Prepare and execute archive for a completed docs-plan v2 family. Archive execution requires explicit user approval in the current turn or an immediately preceding approval that clearly names this archive action.

Read `../plan-protocol/references/plan-protocol.md` before entering.

## PLAN_ROOT Preflight

Before archive preparation or execution, apply plan-protocol § 14.1. If
canonical `plan/` is absent, report that PLAN_ROOT bootstrap is
required. If `docs/plan`, `docs/check`, `docs/archive`,
`docs/roadmap`, or `docs/runbook` exists, stop and report the legacy
conflict. If only some canonical directories are missing and no legacy
conflict exists, create the missing directories idempotently. Never
overwrite existing files, migrate artifacts, or move artifacts without
explicit user approval.

## Workflow

1. Confirm `code-quality-ready`, closeout result `archive-ready`, and no unresolved blocker.
2. If explicit user approval is absent, stop with an `archive-ready` report and ask for approval. Do not archive.
3. If approved, snapshot parent/child/check artifacts under the canonical archive root `plan/archive/`.
4. Update legacy/path mapping artifacts required by the current layout.
5. Preserve tracked root docs and current operating-policy docs in their canonical locations; archive only local planning artifacts.
6. Report archived paths and any follow-up.

## Safety

Do not delete runtime state, artifacts outside the family, or generated operator state. Do not run destructive cleanup beyond the named archive move/copy without explicit user approval.
