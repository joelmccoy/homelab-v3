# 0002 — State backend: Cloudflare R2

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

OpenTofu state must live somewhere durable, off the workstation, and with locking. We already use Cloudflare for DNS and tunnel; reusing the vendor minimizes account sprawl.

## Decision

Use the OpenTofu `s3` backend pointed at a Cloudflare R2 bucket (S3-compatible). Locking via R2's conditional writes (Tofu 1.10+ native lock support); no separate DynamoDB-equivalent needed.

## Consequences

- Free tier covers homelab state easily.
- Bucket and API token must be created out-of-band before `tofu init` (chicken-egg with Tofu state).
- Token has scoped object read/write on the single bucket only.
- Outage of R2 blocks Tofu operations; acceptable for homelab.
