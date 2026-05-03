# 0019 — Mealie recipe manager

- **Status:** Accepted
- **Date:** 2026-05-03

## Context

Joel wants a self-hosted recipe manager available externally from the homelab. Mealie is a good fit because it provides recipes, meal planning, shopping lists, an API, PostgreSQL support, and native OIDC authentication. The app stores mutable recipe/media data, so it needs persistent storage and a database rather than a stateless-only deployment.

## Decision

Deploy Mealie as plain Kubernetes manifests in `k8s/apps/mealie/` instead of introducing an extra Helm chart dependency. Run one Mealie pod with a Longhorn-backed `/app/data` PVC and a dedicated single-instance CloudNativePG cluster. Publish it at `https://mealie.joelmccoy.dev` through the existing Istio Gateway / Cloudflare Tunnel path, and configure a Crossplane-managed public Keycloak OIDC client using Authorization Code + PKCE.

## Consequences

- Mealie is externally reachable but password login and public signup are disabled; Keycloak SSO is the only intended login path.
- Initial access is limited to the existing Keycloak `admins` group, which also grants Mealie admin rights. A separate recipe/user group can be added later if non-admin users need access.
- Data lives in Longhorn volumes (`mealie-data` and `mealie-pg`); backup/restore policy is not solved by this PR and should be addressed before treating Mealie as durable family-critical data.
- Plain manifests make the deployment easy to inspect, but Renovate will update the container image directly rather than through a chart release.
