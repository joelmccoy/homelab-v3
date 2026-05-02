# 0005 — CNI: Cilium with kube-proxy replacement

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

Talos defaults to Flannel + kube-proxy. Flannel lacks NetworkPolicy and observability we want, and Istio Ambient interoperates better with Cilium than Flannel.

## Decision

Cilium with `kubeProxyReplacement: true` and Hubble enabled. Talos machine config disables Flannel and kube-proxy.

## Consequences

- eBPF datapath, native NetworkPolicy, Hubble for traffic visibility.
- ~200–400 MB RAM per node.
- Istio Ambient interop requires `socketLB.hostNamespaceOnly: true` on Cilium and `cni.exclude` configured on Istio (see ADR 0006).
- Cilium upgrades touch core networking — be deliberate, especially while only one cluster exists.
