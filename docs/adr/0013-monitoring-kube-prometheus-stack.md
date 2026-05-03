# 0013 — Monitoring foundation with kube-prometheus-stack

- **Status:** Accepted
- **Date:** 2026-05-03

## Context

The cluster needs a basic metrics and alerting foundation before adding app-specific observability. The homelab is small, GitOps-managed, and already has Longhorn available for persistent volumes.

## Decision

Use `kube-prometheus-stack` as the first monitoring foundation, installed by ArgoCD into a dedicated `monitoring` namespace. Start with one Prometheus and one Alertmanager replica, persistent storage, default Kubernetes/node dashboards disabled until Grafana has a deliberate auth/secret plan, and defer logs/traces/Proxmox exporters to later focused PRs.

## Consequences

- Gives the cluster Prometheus Operator CRDs, Prometheus, Alertmanager, kube-state-metrics, and node-exporter through a well-known chart.
- Keeps the first monitoring change small enough to validate and roll back cleanly.
- Disables kube-proxy and Talos control-plane component scraping/rules initially to avoid false alerts while scrape endpoints and certificates are made explicit.
- Defers Grafana, Loki, tracing, and advanced external exporters until their access, retention, and secret handling choices are explicit.
