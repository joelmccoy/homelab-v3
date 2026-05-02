# 0011 — Toolchain: mise + hk + mise tasks

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

We need pinned tool versions, a pre-commit hook runner, and a task runner that is not Make.

## Decision

`mise` for tool version pinning and env, `hk` for pre-commit hooks (jdx ecosystem coherent with mise), `mise-tasks/` shell scripts as the task runner. Tools and tasks are added incrementally — only what is currently used.

## Consequences

- One vendor for toolchain, hooks, and tasks; less plumbing.
- Each task is a standalone shell file — easy to read and shellcheck.
- New contributors install via `mise install`; nothing else.
- `pkl` is required because hk uses Pkl for its config; pinned in `.mise.toml`.
