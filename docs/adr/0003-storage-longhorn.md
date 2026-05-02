# 0003 — Storage: Longhorn

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

We want distributed block storage that scales from one node now to several, without re-provisioning when peers arrive. Rook-Ceph is heavier than warranted on a single node; Mayastor's value lights up only on homogeneous NVMe; LocalPV abandons distribution.

## Decision

Use Longhorn. Start `defaultClassReplicaCount: 1`; bump to 2–3 once additional nodes/disks come online. Talos image schematic includes `iscsi-tools` and `util-linux-tools` extensions.

## Consequences

- Tiny footprint and simple mental model.
- iSCSI overhead and per-volume engine pods cost some IOPS and latency; fine for homelab workloads.
- Heavy-DB-on-PV scenarios may warrant Longhorn Data Engine v2 or a side-car LocalPV later.
- No object store; Velero / Loki / app buckets will need a separate component (MinIO/Garage) — out of scope for phase 1.
