# Homelab Phase 1 — Foundation (Design Spec)

- **Date:** 2026-05-02
- **Status:** Approved (pending implementation plan)
- **Scope:** Phase 1 of a multi-phase homelab build. Subsequent phases (Identity / Keycloak SSO; GitOps tooling / Renovate + ArgoCD PR-diff) live in their own spec/plan cycles.

## Goals

1. Stand up a Talos Kubernetes cluster on a single Proxmox host, declared as code, that can absorb additional Proxmox hosts later by VM migration.
2. Bootstrap GitOps with ArgoCD as the single reconciler past initial cluster bring-up.
3. Provide distributed block storage (Longhorn) with a path to grow replica count as nodes are added.
4. Provide public-facing TLS-protected ingress via Cloudflare Tunnel + Istio Ambient + cert-manager (Let's Encrypt DNS01 over Cloudflare), with hostnames managed by external-dns.
5. Capture every non-trivial decision as a brief ADR and provide AI guidance for future work in this repo.

## Non-goals (deferred to later phases)

- Identity / SSO (Keycloak + operator) — phase 2.
- Renovate, ArgoCD GitHub App, ArgoCD PR-diff bot — phase 3.
- Backup tooling (Velero), observability stack (Prometheus/Loki/Grafana), secret management beyond bootstrap — out of phase 1; called out as next steps.

## Architecture

### High-level traffic path

```
client → Cloudflare edge (TLS) → CF Tunnel → cloudflared (in-cluster Deployment)
       → Istio Gateway (HTTPS, real LE cert via cert-manager)
       → HTTPRoute → app pod (Istio Ambient ztunnel handles in-cluster mTLS)
```

### Cluster shape

- **Hypervisor:** existing Proxmox host (single, more to be added later).
- **OS:** Talos Linux on each VM. Image built via Talos Image Factory schematic that includes the system extensions required by chosen components: `iscsi-tools` and `util-linux-tools` (Longhorn), `qemu-guest-agent` (Proxmox).
- **Topology:** 3 VMs, all combined control-plane + worker (`allowSchedulingOnControlPlanes: true`). 3-member etcd quorum from day 1, surviving a single VM crash. The three VMs initially share one physical host (quorum is "fake" against host failure until additional Proxmox hosts arrive); planned migration spreads them as hardware grows.
- **CNI:** Cilium with `kubeProxyReplacement: true`. Hubble enabled for in-cluster traffic observability. Talos machine config disables Flannel and kube-proxy.
- **Service mesh:** Istio Ambient (ztunnels per node, no sidecars) + Gateway API. Istio Gateway replaces a separate ingress controller.
- **Storage:** Longhorn. Initial `defaultClassReplicaCount: 1` (single-node cluster cannot replicate); intent is to bump to 2–3 once additional nodes/disks come online. `dataLocality: best-effort` for default class; `strict-local` reserved for performance-sensitive PVCs.
- **TLS:** cert-manager with two ClusterIssuers — Let's Encrypt staging (default while validating) and production. DNS01 challenge against Cloudflare via a scoped API token. Same certs used whether traffic enters via CF Tunnel or directly on LAN (split-horizon).
- **External DNS:** external-dns (Cloudflare provider) watches Gateway listeners and creates CNAMEs to `<tunnel-id>.cfargotunnel.com`.
- **Tunnel routing:** cloudflared in-cluster Deployment with a single wildcard ingress rule (`* → istio-gateway:443`); Istio routes by Host header. Adding an app = adding a Gateway listener; no per-app tunnel config edits.

### Failure modes (homelab-grade, accepted)

- **Single Proxmox host loss** → cluster lost until another host or restore. Acceptable for personal homelab; addressed by adding hosts.
- **ArgoCD self-upgrade** → momentary reconcile pause when argocd-server restarts; recovers automatically.
- **Cilium misconfig** → cluster networking dead. Mitigation: deliberate, infrequent Cilium upgrades; staging issuer used during initial verification.
- **LE rate-limit on prod issuer** → ClusterIssuer for staging always present; switch to prod after validation.

## Component ownership

| Component | Owner | Notes |
|-----------|-------|-------|
| Proxmox VMs (3× Talos) | OpenTofu (`bpg/proxmox` provider) | Cluster lifecycle |
| Talos image schematic + machine config | OpenTofu (`siderolabs/talos` provider) | Bakes required system extensions; outputs kubeconfig |
| Cloudflare Tunnel + scoped API tokens | OpenTofu (Cloudflare provider) | Tunnel for cloudflared; tokens for cert-manager + external-dns |
| Cilium | `scripts/bootstrap.sh` (Helm) → ArgoCD adopts | CNI required before any pod schedules |
| ArgoCD | `scripts/bootstrap.sh` (Helm) → self-managed | Hand-off to GitOps |
| Bootstrap secrets (CF tunnel token, CF API token) | `scripts/apply-secrets.sh` (separate from bootstrap) | Sourced from `tofu output -json`, applied via `kubectl create secret --dry-run=client -o yaml \| kubectl apply -f -`. Never committed. |
| Root `Application` (app-of-apps) | `scripts/bootstrap.sh` (`kubectl apply`) | Points ArgoCD at `k8s/apps/` |
| cert-manager + ClusterIssuers | ArgoCD | Sync waves order CRDs → controller → ClusterIssuers |
| Longhorn | ArgoCD | Requires Talos `iscsi-tools` + `util-linux-tools` extensions baked in image |
| Istio (base, CNI, istiod, ztunnel, Gateway API CRDs, Gateway) | ArgoCD | Multiple Applications, sync-wave ordered |
| cloudflared | ArgoCD | Single Deployment, single wildcard ingress rule, consumes bootstrap tunnel-token Secret |
| external-dns | ArgoCD | Cloudflare provider; consumes bootstrap CF API token Secret |

## Bootstrap flow

### One-time manual prerequisites (documented in repo README + ADRs)

1. Cloudflare account with at least one zone (apex domain) delegated to Cloudflare and managed by this user. The zone name is supplied as a Tofu variable (e.g. `var.cloudflare_zone`); all hostnames in phase 1 live under it.
2. Cloudflare R2 bucket + API token created out-of-band (chicken-egg with Tofu state).
3. Proxmox API endpoint reachable from the workstation running Tofu, with API credentials supplied via Tofu variables.
4. `mise install` to materialize toolchain.

### Tofu apply

Provisions: 3× Talos VMs on Proxmox, Talos machine config + bootstrap, Cloudflare tunnel, scoped Cloudflare API tokens. Outputs: kubeconfig, tunnel ID, tunnel token, CF API token (for cert-manager + external-dns).

### `mise run apply-secrets`

Reads `tofu output -json`, applies in-cluster Secrets:
- `cloudflare-tunnel-credentials` (cloudflared)
- `cloudflare-api-token-cert-manager`
- `cloudflare-api-token-external-dns`

Idempotent. Run before `bootstrap` (so apps don't CrashLoopBackOff during their first sync) and re-run if tokens rotate.

### `mise run bootstrap` → `scripts/bootstrap.sh`

Minimal, idempotent:

1. Pre-flight check (toolchain present).
2. `talosctl bootstrap` if etcd not yet initialized.
3. Wait nodes Ready=False (CNI pending).
4. `helm upgrade --install cilium cilium/cilium -n kube-system -f k8s/bootstrap/cilium-values.yaml` and wait for Ready.
5. `helm upgrade --install argo-cd argo/argo-cd -n argocd --create-namespace -f k8s/bootstrap/argocd-values.yaml` and wait for `argocd-server` Ready.
6. `kubectl apply -f k8s/bootstrap/root-app.yaml` (the root `Application` pointing at `k8s/apps/`).

### ArgoCD reconciles `k8s/apps/` with sync waves

- **Wave -10:** namespaces, Gateway API CRDs, cert-manager CRDs, Longhorn CRDs, Istio base.
- **Wave -5:** cert-manager controller, Longhorn manager, istiod, Istio CNI, ztunnel.
- **Wave 0:** ClusterIssuers (staging + prod), Longhorn StorageClasses.
- **Wave 5:** cloudflared, external-dns, Istio Gateway resource (with HTTPS listener referencing cert-manager-issued cert).
- **Wave 10:** workload apps (later phases).

ArgoCD additionally manages its own and Cilium's helm Applications (self-management) so chart bumps land via PR.

### Self-management adoption

The two helm releases installed by `scripts/bootstrap.sh` (Cilium in `kube-system`, argo-cd in `argocd`) are adopted in-place by ArgoCD `Application`s in `k8s/apps/cilium/` and `k8s/apps/argo-cd/`. Each Application uses an `helm` source with `releaseName` and `namespace` matching the bootstrap install, so ArgoCD reconciles the existing release rather than creating a duplicate. Initial chart versions and values in those Applications must match the values used by `scripts/bootstrap.sh` to avoid an unintended diff on first sync.

## Repo layout

```
.
├── README.md
├── CLAUDE.md
├── .mise.toml
├── hk.pkl
├── .gitignore
├── .gitleaks.toml
├── mise-tasks/
│   ├── bootstrap
│   ├── apply-secrets
│   ├── lint
│   ├── fmt
│   ├── tf-plan
│   ├── tf-apply
│   ├── kubeconfig
│   ├── hk-install
│   ├── hubble
│   ├── argocd-ui
│   └── adr-new
├── tofu/
│   ├── versions.tf
│   ├── backend.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── proxmox.tf
│   ├── talos.tf
│   ├── cloudflare.tf
│   └── modules/
├── scripts/
│   ├── bootstrap.sh
│   └── apply-secrets.sh
├── k8s/
│   ├── bootstrap/
│   │   ├── cilium-values.yaml
│   │   ├── argocd-values.yaml
│   │   └── root-app.yaml
│   └── apps/
│       ├── argo-cd/
│       ├── cilium/
│       ├── cert-manager/
│       ├── longhorn/
│       ├── istio-base/
│       ├── istio-cni/
│       ├── istiod/
│       ├── istio-ztunnel/
│       ├── istio-gateway/
│       ├── cloudflared/
│       └── external-dns/
└── docs/
    ├── adr/
    │   ├── README.md
    │   ├── template.md
    │   └── NNNN-*.md
    └── superpowers/
        └── specs/
            └── 2026-05-02-homelab-phase1-foundation-design.md
```

## Toolchain

- **`mise`** — pins versions of opentofu, kubectl, talosctl, helm, kustomize, jq, yq, hk, kubeconform, gitleaks, shellcheck, markdownlint-cli2, prettier, tflint.
- **`hk`** — pre-commit hook runner. Initial hooks:
  - `tofu fmt -check`
  - `tflint`
  - `yamllint`
  - `markdownlint`
  - `shellcheck` (scripts/, mise-tasks/)
  - `gitleaks` (secret scan)
  - `kubeconform` (k8s/**/*.yaml)
  - end-of-file-fixer, trailing-whitespace, check-merge-conflict, check-yaml, check-json
  - `prettier` (yaml/json/md)
- **`mise-tasks/`** — task runner. Each task is a shebang script in `mise-tasks/`.

## ADRs to write

Brief format: status, date, context (2–3 sentences), decision (1–2 sentences), consequences (bulleted pros/tradeoffs).

1. `0001-iac-opentofu-proxmox-talos.md`
2. `0002-state-backend-cloudflare-r2.md`
3. `0003-storage-longhorn.md`
4. `0004-cluster-topology-3-combined-vms.md`
5. `0005-cni-cilium-with-kube-proxy-replacement.md`
6. `0006-service-mesh-istio-ambient-gateway-api.md`
7. `0007-tls-cert-manager-letsencrypt-dns01.md`
8. `0008-external-hostnames-cloudflared-wildcard.md`
9. `0009-bootstrap-pattern-tofu-then-script-then-argocd.md`
10. `0010-repo-layout-flat-by-purpose.md`
11. `0011-toolchain-mise-hk-mise-tasks.md`
12. `0012-secrets-bootstrap-deferred-eso.md`

## CLAUDE.md (AI guidance, brief)

Lives at repo root. Summarizes:

- What the repo is.
- Layout (one-liners per top-level dir).
- Conventions: tool versions via mise; pre-commit hooks must pass (no bypass); no secrets in git (`mise run apply-secrets` route only); big decisions get an ADR; post-bootstrap state owned by ArgoCD (don't `kubectl apply` to live cluster — change git).
- Common commands (`mise run …`).
- Pointer to current phase spec under `docs/superpowers/specs/`.

## Risks & open items

- **Talos image schematic drift:** any system extension change triggers a rolling node reboot. Mitigation: schematic versioned in Tofu; reboots are automated by talos provider but staged.
- **R2 backend pre-creation:** the bucket + API token must exist before `tofu init`. Documented manual step in README + ADR 0002.
- **Self-management cycles:** ArgoCD's and Cilium's self-management can briefly stall during their own upgrades; acceptable for homelab; flagged in ADR 0009.
- **Single-host quorum illusion:** etcd quorum across 3 VMs on one Proxmox host does not survive host failure. Resolved as additional Proxmox hosts arrive.
- **Cloudflare scope creep:** scoped API tokens only — no Global API Key. cert-manager token = DNS edit on target zone(s) only; external-dns token = same; tunnel credentials = tunnel-scoped.

## Success criteria

Phase 1 is "done" when:

1. `mise run tf-apply && mise run apply-secrets && mise run bootstrap` produces a healthy 3-node Talos cluster with Cilium + ArgoCD running.
2. ArgoCD has reconciled `k8s/apps/` to green state for: cert-manager, Longhorn, all Istio components, cloudflared, external-dns, plus self-managed Cilium and ArgoCD.
3. A test HTTPRoute exposed via Istio Gateway is reachable from the public internet, served on a hostname under the Cloudflare zone, with a valid Let's Encrypt certificate.
4. `mise run lint` passes against the repo on a clean checkout.
5. ADRs 0001–0012 are present and approved.
6. `CLAUDE.md` exists and reflects the conventions above.

## Out of scope (next phases)

- Phase 2: Keycloak + Keycloak operator + SSO client patterns; ingress integration.
- Phase 3: Renovate; ArgoCD GitHub App; ArgoCD PR-diff preview.
- Cross-cutting later: Velero (backups → S3 / R2), observability stack (Prom/Loki/Grafana/Hubble UI exposure), External Secrets Operator + vault, multi-cluster ApplicationSets if a second cluster is added.
