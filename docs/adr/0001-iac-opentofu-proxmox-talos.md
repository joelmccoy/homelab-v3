# 0001 — IaC: OpenTofu with bpg/proxmox and siderolabs/talos providers

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

We need declarative, repeatable provisioning of Proxmox VMs and the Talos machine configs that run on them. We expect to grow from a single Proxmox host to several, and we want re-creating the cluster from scratch to be a single command.

## Decision

Use OpenTofu with the `bpg/proxmox` provider for VMs and the `siderolabs/talos` provider for image schematics, machine configs, and cluster bootstrap. OpenTofu over Terraform to avoid HashiCorp's BSL.

## Consequences

- Single source of truth for cluster lifecycle; tooling familiar.
- Both providers are well-maintained and homelab-tested.
- Tofu must be run from a machine that can reach the Proxmox API (private network).
- State backend choice matters — see ADR 0002.
