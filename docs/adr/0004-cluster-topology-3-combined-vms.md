# 0004 — Cluster topology: 3 combined CP+worker VMs

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

A single VM avoids quorum but makes 1→3 etcd migration painful later. Splitting CP and worker roles is YAGNI at homelab scale.

## Decision

Three Talos VMs, each control-plane + worker (`allowSchedulingOnControlPlanes: true`). Three-member etcd from day 1.

## Consequences

- Survives a single VM crash.
- VMs initially share one Proxmox host — host failure still loses the cluster (acceptable; resolved as hosts are added).
- ~6–9 GB RAM total for control-plane overhead; trivial on any reasonable Proxmox host.
- Adding a Proxmox host = migrate one or two VMs over and quorum becomes real.
