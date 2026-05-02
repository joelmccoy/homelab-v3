# 0006 — Service mesh: Istio Ambient + Gateway API

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

We want zero-touch in-cluster mTLS, an L7 gateway, and no per-pod sidecar overhead. A separate ingress controller (e.g. ingress-nginx) plus a service mesh would be two systems where one suffices.

## Decision

Istio Ambient (ztunnels per node, no sidecars) plus Gateway API. Istio Gateway is the cluster's only ingress; no ingress-nginx. Cilium tuned for Ambient compatibility.

## Consequences

- Single L7 control plane for ingress and east-west traffic.
- Apps don't need any in-pod injection to get mTLS.
- Ambient + Cilium has known knobs that must be set correctly (`socketLB.hostNamespaceOnly`, Istio `cni.exclude`).
- Waypoint proxies (per-namespace L7 enforcement) are opt-in per workload as needs arise.
