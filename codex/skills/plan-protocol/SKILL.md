---
name: plan-protocol
description: Shared docs-plan v2 protocol for Codex-side execution/finalization skills. Use when checking family_status vocabulary, Q1/Q2, gates, writer ownership, Child Handoff Board rules, child-checkpoint JSON schema, recurrence routing, refactor-child skip rules, or PLAN_ROOT/current_check_root behavior.
---

# Plan Protocol

## Overview

Use this skill when you need the shared docs-plan v2 protocol from the Codex side. The protocol body is intentionally stored in `references/plan-protocol.md`; it must stay byte-identical with the Claude-side counterpart.

## Workflow

1. Read `references/plan-protocol.md` before making or judging docs-plan v2 status, gate, board, checkpoint, or cross-orchestrator decisions.
2. Treat this `SKILL.md` as Codex-local wrapper text only. Do not sync this wrapper byte-for-byte with Claude.
3. Sync only `references/plan-protocol.md`. A reference drift is a closure violation; wrapper wording drift is not.
4. Prefer the protocol over older `docs-plan-*` legacy wording whenever they conflict.
5. Apply the PLAN_ROOT preflight from `references/plan-protocol.md` § 14.1 before plan, execution, or finalization stages read or write artifacts.

## PLAN_ROOT Preflight

Stages must report bootstrap need when canonical `plan/` is absent,
stop on legacy `docs/plan`, `docs/check`, `docs/archive`,
`docs/roadmap`, or `docs/runbook`, create only missing canonical
directories when partial canonical structure exists without legacy
conflict, and never overwrite, migrate, or move artifacts without
explicit user approval.

## Scope

This skill defines the contract. It does not implement `exec-run`, `finalize-run`, or any stage work by itself.
