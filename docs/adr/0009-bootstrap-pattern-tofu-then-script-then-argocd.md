# 0009 — Bootstrap pattern: Tofu → bootstrap script → ArgoCD

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

Tofu cannot install Kubernetes workloads on a cluster that doesn't have a CNI yet, and using Tofu to manage Helm releases creates a parallel reconciliation system alongside ArgoCD.

## Decision

Tofu provisions infra (VMs, Talos machine config, Cloudflare tunnel + tokens) and outputs secrets. A minimal `scripts/bootstrap.sh` Helm-installs Cilium and ArgoCD, then applies the root `Application`. ArgoCD owns everything thereafter and adopts the Cilium and ArgoCD Helm releases via Applications matching the bootstrap `releaseName` and `namespace`.

## Consequences

- Tofu stays focused on infra; no `helm_release` resources in Tofu.
- Bootstrap script is small, idempotent, and re-runnable.
- ArgoCD self-management means brief reconcile pauses during ArgoCD upgrades; acceptable.
- Cilium upgrades via ArgoCD touch networking — handle with care.
