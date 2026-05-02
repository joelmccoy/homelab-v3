# 0012 — Secrets: bootstrap via Tofu outputs; ESO deferred

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

cert-manager (Cloudflare API token), external-dns (Cloudflare API token), and cloudflared (tunnel credentials) need secrets to function. We don't want secrets in git and don't yet need a full secret manager.

## Decision

Tofu emits the values as outputs. `scripts/apply-secrets.sh` reads `tofu output -json` and `kubectl apply`s in-cluster Secrets in the relevant namespaces. External Secrets Operator + a secret manager (1Password Connect, Vault, AWS SM, etc.) are deferred to a later phase.

## Consequences

- No secrets in git, no extra control plane to run.
- Token rotation is manual: `tofu apply` regenerates, `mise run apply-secrets` re-applies.
- Migration to ESO later requires re-namespacing secrets but is straightforward.
