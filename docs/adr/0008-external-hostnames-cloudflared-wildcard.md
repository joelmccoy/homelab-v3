# 0008 — External hostnames: wildcard cloudflared rule + external-dns

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

We need a cheap, declarative way to expose new apps publicly without editing tunnel config per app.

## Decision

Run cloudflared as an in-cluster Deployment with a single ingress rule: `* → istio-gateway:443`. Istio Gateway routes by Host header. external-dns watches Gateway listeners and writes CNAMEs to `<tunnel>.cfargotunnel.com`. The public Gateway only accepts routes from namespaces explicitly labeled `gateway.joelmccoy.dev/public-routes=true`.

## Consequences

- Adding an app = adding an HTTPRoute in an explicitly labeled public-route namespace; no tunnel config changes.
- Unlabeled namespaces cannot bind arbitrary HTTPRoutes to the internet-facing wildcard Gateway.
- Single failure surface (one cloudflared Deployment) — acceptable for homelab; can scale replicas later.
- Tunnel-scoped credential and a separate scoped DNS-edit token; both narrow.
