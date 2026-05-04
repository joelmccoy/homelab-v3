# 0020 — Kaneo project management

- **Status:** Accepted
- **Date:** 2026-05-04

## Context

Joel wants a self-hosted project management and ticket system for humans and AI workers, not a CRM. Kaneo is a lightweight MIT-licensed project management app with a documented API, API-key auth, device-flow support for CLI/MCP-style clients, PostgreSQL support, and custom OAuth/OIDC sign-in.

## Decision

Deploy Kaneo as plain Kubernetes manifests in `k8s/apps/kaneo/` using the upstream combined image, a dedicated single-instance CloudNativePG cluster, and the existing Istio Gateway / Cloudflare Tunnel external route at `https://kaneo.joelmccoy.dev`. Configure Keycloak SSO through a Crossplane-managed confidential OIDC client using Kaneo's custom OAuth provider.

## Consequences

- Kaneo becomes the homelab project/ticketing system with a small operational footprint and GitOps-owned deployment.
- Keycloak is the intended sign-in path; guest access and password registration are disabled while SSO registration remains available for homelab users.
- Mutable application data lives in the Kaneo PostgreSQL cluster; attachment/object-storage integration is deferred until there is a deliberate RustFS bucket/credential pattern for apps.
- Kaneo's `AUTH_SECRET` currently reuses the Crossplane-generated Keycloak client secret to avoid committing a static secret. Replace this with a dedicated generated/sealed app secret once the repo has a general app-secret workflow.
