# 0025 — Dozzle quick Kubernetes log viewer

- **Status:** Accepted
- **Date:** 2026-05-04

## Context

Loki and Grafana are the durable observability stack, but the cluster still
benefits from a fast live-tail UI for quick pod-log inspection. Dozzle has
native Kubernetes mode and can stream pod logs without storing them, which keeps
it small and disposable beside the durable Loki path.

Dozzle does not implement OIDC directly. It supports trusting identity headers
from a forward proxy, so Keycloak SSO needs a small auth proxy in front of it.

## Decision

Deploy Dozzle as a plain-manifest Argo CD app at `dozzle.joelmccoy.dev` using
`DOZZLE_MODE=k8s`. Grant it read-only cluster RBAC for pods, pod logs, nodes,
and pod metrics. Protect the UI with an oauth2-proxy sidecar using a
Crossplane-managed Keycloak confidential client and require the `admins` group.

Use an init container to generate oauth2-proxy's cookie secret into an in-memory
`emptyDir` on pod start. Dozzle itself gets a small Longhorn PVC for UI settings;
logs remain streamed only, not persisted.

## Consequences

- Provides quick cluster-wide log browsing without waiting for Loki/Grafana.
- Access is gated by Keycloak SSO and limited to the `admins` group.
- The app has broad read-only visibility into pod logs; keep it behind SSO and
  do not enable Dozzle shell/actions.
- OAuth sessions are invalidated on pod restart because the cookie secret is
  ephemeral; acceptable for this low-state utility and avoids committing another
  static secret.
