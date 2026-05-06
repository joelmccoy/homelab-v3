# 0019 — RustFS for in-cluster S3-compatible storage

- **Status:** Accepted
- **Date:** 2026-05-03

## Context

Loki, Velero, and several other future workloads expect S3-compatible object storage. Cloudflare R2 would work but adds a paid external dependency. We want object storage in-cluster, free, and ideally aligned with the homelab's "self-host everything reasonable" stance. MinIO's community edition lost features in the 2025 license shake-up; SeaweedFS is Go and adds layers; Garage is Rust+S3 but the UI is sparse.

## Decision

Adopt RustFS (chart `rustfs/rustfs` v0.1.0, app v1.0.0-beta.1) in **standalone** mode on Longhorn-backed PVCs. Storage durability comes from Longhorn's cross-node replication; the single rustfs pod is sufficient for homelab S3 throughput. Distributed mode is "under testing" upstream and stays off until RustFS GAs it.

## Consequences

- One in-cluster S3 endpoint at `s3.joelmccoy.dev` plus a built-in admin console at `s3-console.joelmccoy.dev`. Console SSO via Keycloak (RustFS native OIDC, blanket `consoleAdmin` policy since the homelab realm only contains the admins group).
- Beta software with ~70 open issues — acceptable for homelab use cases (Loki chunks, future Velero target). Anything truly critical should still go off-cluster.
- Chicken-and-egg: when the cluster is unhealthy, neither RustFS nor the logs of why it failed are reachable. `kubectl logs` and Longhorn snapshots remain the bring-up safety net.
- Migration path to distributed mode (when GA) is a redeploy + restore from Longhorn snapshot — disruptive but tractable.
- Bucket bootstrapping is currently app-local: S3 consumers add a small Argo CD PreSync Job that runs `head-bucket || create-bucket` against RustFS. This avoids the current Crossplane AWS S3 provider compatibility problems with RustFS while keeping bucket creation ordered and GitOps-managed.
