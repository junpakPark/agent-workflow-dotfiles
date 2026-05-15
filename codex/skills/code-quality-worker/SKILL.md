---
name: code-quality-worker
description: Given a caller-provided code/test change surface, emit quality-only findings against references/code-quality.md in strict F-NNN + severity format. Use as the findings engine for exec-code-quality. Do not modify code, do not decide a result, do not triage, do not create plan docs, and do not emit intent/acceptance/source-of-truth findings.
---

# Code Quality Worker

## Overview

Review a caller-provided code/test change surface against the local quality principles. Produce raw quality findings only. The caller (`exec-code-quality` in docs-plan v2) owns artifact storage, evidence validation, triage, routing, result status, and any follow-up plan creation.

Read [references/code-quality.md](references/code-quality.md) before reviewing.

## Workflow

1. Inspect only the files and diffs in the caller-provided change surface.
2. Apply the quality principles in `references/code-quality.md`.
3. Emit only material quality/maintainability findings in the strict `F-NNN + severity` format from the reference.
4. If the provided scope is unclear, emit a `decision-needed` finding that names the missing scope evidence.

## Boundaries

- Do not edit files.
- Do not write `plan/check/*` artifacts.
- Do not decide a pass/fail or `code-quality-ready` result.
- Do not create or update plan documents.
- Do not classify findings as resolved or unresolved.
- Do not include remediation patches.
- Do not emit findings about child intent, acceptance row coverage, source-of-truth correctness, or parent policy fit. Those belong to `draft-review`, `test-review`, or Claude `plan-reconcile`, not code quality.
