# 0022 — Loki in Monolithic mode for log aggregation

- **Status:** Accepted
- **Date:** 2026-05-04

## Context

We have metrics (kube-prometheus-stack) but no log aggregation — debugging means SSH-and-grep across nodes. Loki is the natural fit alongside Grafana, but the deployment-mode choice matters: SimpleScalable (the chart's historical default) is being removed in Loki 4, and Distributed/microservices is overkill for homelab volume. The OSS chart also moved from `grafana/loki` to `grafana-community/loki` in March 2026.

## Decision

Deploy Loki via the new `grafana-community/loki` chart in **Monolithic** mode (`deploymentMode: Monolithic`, `singleBinary.replicas: 1`). TSDB index and chunks are stored in RustFS; an Argo CD Sync hook Job creates the `loki-chunks` bucket idempotently before Loki starts. Credentials are sealed and projected via `extraEnvFrom` + `-config.expand-env=true` so no keys land in the rendered config.

## Consequences

- Single Loki pod handles ingest + query for ~20 GB/day — comfortably above any homelab volume we'll hit.
- WAL on a 10 GiB Longhorn PVC for durability across pod restarts; chunks live in RustFS where they enjoy 3-replica redundancy.
- Switching to SimpleScalable later means flipping a single `deploymentMode` value — but per upstream that mode is being removed, so the realistic upgrade path is Monolithic → Distributed if we ever outgrow this.
- No bundled Memcached / no Loki gateway / no self-monitoring agent — keeping the stack thin. kube-prometheus-stack scrapes Loki's own `/metrics` separately.
- 7-day retention by default, set in `limits_config.retention_period`, with Loki compactor deletion enabled via `loki.compactor.retention_enabled` and `delete_request_store: s3`. Bumping it just means more S3 storage on RustFS.
- Bucket provisioning is intentionally narrow: the Sync hook Job only ensures the bucket exists and does not manage lifecycle, policies, or contents.
