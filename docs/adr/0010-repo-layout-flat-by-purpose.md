# 0010 — Repo layout: flat by purpose

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

ArgoCD app-of-apps repos commonly use either `clusters/<name>/` per-cluster or a flat `tofu|scripts|k8s|docs` structure. We have one cluster planned.

## Decision

Flat layout by purpose: `tofu/`, `scripts/`, `k8s/{bootstrap,apps}/`, `docs/{adr,superpowers}/`, `mise-tasks/`. If a second cluster appears, evolve to `clusters/<name>/` with an ADR.

## Consequences

- Less nesting now, fewer per-cluster knobs.
- Refactor cost when scaling to multi-cluster — accept the hit if/when needed.
