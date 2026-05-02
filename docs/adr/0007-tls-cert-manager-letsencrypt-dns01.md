# 0007 — TLS: cert-manager + Let's Encrypt DNS01 over Cloudflare

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

We want valid public certs at the cluster gateway, even though traffic enters via Cloudflare Tunnel. The same cert should be valid for split-horizon LAN access. HTTP01 won't work behind a tunnel without exposing port 80.

## Decision

cert-manager with two ClusterIssuers (LE staging, LE prod), DNS01 challenge against Cloudflare via a scoped API token (DNS edit on target zones only). Default to staging during initial verification, switch the Gateway to prod once issuance works.

## Consequences

- Real certs everywhere, no per-app cert plumbing.
- Token scope minimized; no Global API Key.
- Wildcard certs available if desired (DNS01 supports them).
- LE prod rate-limit risk handled by staging-first pattern.
