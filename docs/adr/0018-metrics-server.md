# 0018 — metrics-server

- **Status:** Accepted
- **Date:** 2026-05-03

## Context

`kubectl top` and HPA need a Resource Metrics API source. kube-prometheus-stack scrapes node-exporter for long-horizon storage but doesn't satisfy the `metrics.k8s.io` aggregated API. Talos serves kubelet `/metrics/resource` over TLS with self-signed serving certs — the cluster doesn't yet run kubelet-csr-approver, so cert verification has to be relaxed for now.

## Decision

Install the upstream `metrics-server` chart (v3.13.0, app v0.8.0) into a dedicated `metrics-server` namespace with `--kubelet-insecure-tls`. Single replica (homelab, not HA). Mesh the namespace ambient — kube-apiserver is unmeshed and ambient only intercepts traffic from meshed sources, so the aggregated API path is unaffected.

## Consequences

- `kubectl top nodes/pods` and HPA work out of the box.
- `--kubelet-insecure-tls` skips kubelet cert verification — acceptable in a homelab but a real audit gap. Backlog: install kubelet-csr-approver and drop the flag.
- One more aggregated APIService (`v1beta1.metrics.k8s.io`); if metrics-server is unhealthy, `kubectl top` and HPA fail but no cascading impact on other workloads.
