# 0017 — Realm config via keycloak-config-cli (PostSync hook)

- **Status:** Accepted
- **Date:** 2026-05-03

## Context

We need realm-level Keycloak config (display name, login theme, password policy, session timeouts, identity providers, user federation) declared in git and re-applied on drift. The Keycloak operator's `KeycloakRealmImport` is a one-shot bootstrap, not for ongoing config. Per-app SSO clients are managed elsewhere (see ADR 0016).

## Decision

Run `keycloak-config-cli` as an ArgoCD `PostSync` hook on the `keycloak` Application. Realm config lives in a `ConfigMap` (inline YAML) under `k8s/apps/keycloak/manifests/realm-config.yaml`. The hook re-runs on every sync and is idempotent. Set `IMPORT_MANAGED_CLIENT=no-delete` and `IMPORT_MANAGED_GROUP=no-delete` so config-cli never touches Crossplane-managed clients/groups.

## Consequences

- Realm-level settings are GitOps-managed; drift auto-corrected on next sync.
- Hybrid model: config-cli owns the realm; Crossplane owns clients (and eventually groups/users). The two never fight because of the `no-delete` knobs.
- One more transient Job per sync (auto-cleaned via `hook-delete-policy`).
- Realm secrets (e.g. SMTP creds, identity provider client secrets) substitute via env at hook runtime — we'll seal those when needed.
