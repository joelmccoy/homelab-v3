# 0014 — IdP: Keycloak via the Quarkus operator

- **Status:** Accepted
- **Date:** 2026-05-03

## Context

Phase 2 introduces SSO for cluster apps. We want one OIDC provider, declarative cluster-managed install, and a path to per-app SSO clients managed in git. Authentik and Authelia were considered.

## Decision

Use Keycloak (upstream, Red Hat / Quarkus build) deployed via the official Keycloak Operator (`k8s.keycloak.org/v2alpha1` `Keycloak` CR). The instance lives in the `keycloak` namespace and is fronted by Istio Gateway at `sso.joelmccoy.dev`.

## Consequences

- Mature OIDC + OAuth2 + SAML feature set; widest ecosystem support.
- Operator handles instance lifecycle (pod, hostname, db wiring) declaratively.
- Operator does **not** manage clients or users — that's covered by separate decisions (0016, 0017).
- One more controller pod (~50–100 MB RAM) vs running Keycloak from a helm chart.
