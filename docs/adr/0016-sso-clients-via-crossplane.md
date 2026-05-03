# 0016 — SSO clients via Crossplane provider-keycloak

- **Status:** Accepted
- **Date:** 2026-05-03

## Context

Each app that wants SSO needs an OIDC client in Keycloak plus the same client secret available as a Kubernetes Secret in the consuming app's namespace. The Keycloak operator stopped shipping `KeycloakClient` CRDs in v22+; declarative client management has no first-party CRD path.

## Decision

Install Crossplane and the `crossplane-contrib/provider-keycloak` provider. Define one `Client` CR per app — alongside that app's other manifests — with `writeConnectionSecretToRef` pointing into the app's own namespace. Crossplane reconciles the client into Keycloak via admin API and writes the connection Secret automatically.

## Consequences

- Per-app SSO is one CR + one secret reference; no duplicate-sealed-secrets pattern.
- Crossplane reconciles continuously — client drift is auto-corrected.
- Adds Crossplane core + the provider; reusable for other declarative external resources later (Cloudflare DNS, etc.) instead of bolting on more bespoke tools.
- ProviderConfig needs a JSON-formatted credentials Secret pointing at a Keycloak admin user — we seal that under `k8s/apps/keycloak/manifests/`.
