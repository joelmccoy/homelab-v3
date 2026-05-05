# 0024 — Grafana OIDC via Keycloak, no local admin password

- **Status:** Accepted
- **Date:** 2026-05-04

## Context

Grafana shipped with a local admin password (SealedSecret). The rest of the homelab (ArgoCD, Mealie, Kaneo) authenticates through Keycloak using the same pattern — Crossplane `Client` CR writes the `client_secret` to a namespace Secret, which the app consumes. A separate local password creates an inconsistency and a credential that never rotates.

## Decision

Deploy Grafana with `auth.basic.enabled = false` and `auth.disable_login_form = true`. OIDC via `auth.generic_oauth` pointing at the `homelab` Keycloak realm. The `Client` CR (`grafana`) lives in `k8s/apps/monitoring/manifests/keycloak-client.yaml`; Crossplane writes the connection Secret (`grafana-keycloak-client`) to the `monitoring` namespace. Grafana reads `attribute.client_secret` from that Secret via `envValueFrom`.

Role mapping: `role_attribute_path = contains(groups[*], '/admins') && 'Admin' || 'Viewer'` — members of the `admins` Keycloak group get Grafana Admin; everyone else gets Viewer.

## Consequences

- Single login path: Keycloak. No local credentials to rotate or leak.
- `admins` group membership controls Grafana Admin role automatically.
- On first sync, Grafana pod may start before Crossplane has written the client Secret — a pod restart after Secret creation resolves it (same timing as ArgoCD OIDC setup).
- No break-glass local admin. If Keycloak is down, Grafana is inaccessible — acceptable for homelab where Keycloak runs in-cluster.
