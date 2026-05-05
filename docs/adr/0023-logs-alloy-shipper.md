# 0023 — Alloy as the log shipper to Loki

- **Status:** Accepted
- **Date:** 2026-05-04

## Context

Loki needs a per-node agent that tails container logs and pushes them. Promtail filled this role for years but Grafana deprecated it in 2024 in favour of Alloy — Promtail still gets security/bug fixes but no new features. Vector is a strong alternative when shipping to multiple backends, but for a single-backend Loki+Grafana stack it adds complexity without payoff.

## Decision

Deploy `grafana/alloy` as a DaemonSet, configured with a small inline Alloy file: `discovery.kubernetes` → `discovery.relabel` (namespace/pod/container/node/app labels) → `loki.source.kubernetes` → `loki.write` to the in-cluster Loki Service. Single-component config — no metrics scraping, no traces, no profiling — so the surface area stays minimal.

## Consequences

- One agent per node, scrapes every pod's logs cluster-wide. Same coverage Promtail would have provided.
- Alloy is the same binary that handles metrics/traces/profiling — if we ever want to consolidate node-exporter, Tempo, Pyroscope agents, we extend this config rather than adding more agents.
- River-style HCL-ish config sits in our `values.yaml` — searchable in git, no separate ConfigMap manifest.
- Promtail's pipeline_stages aren't 1:1 mapped; if we ever need fancy log parsing we'll write the equivalent in `loki.process` components instead.
