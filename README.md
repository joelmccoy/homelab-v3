# homelab-v3

![Kubernetes](https://img.shields.io/badge/Kubernetes-Talos-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![GitOps](https://img.shields.io/badge/GitOps-Argo%20CD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Infrastructure](https://img.shields.io/badge/IaC-OpenTofu-FFDA18?style=for-the-badge&logo=opentofu&logoColor=black)
![Edge](https://img.shields.io/badge/Edge-Cloudflare-F38020?style=for-the-badge&logo=cloudflare&logoColor=white)

Joel's production-lite homelab: Talos Kubernetes on Proxmox, reconciled by Argo CD,
fronted by Cloudflare Tunnel, and managed through small GitOps changes.

## Quick links

| Thing | Link |
| --- | --- |
| GitOps root app | [`k8s/apps/_apps.yaml`](k8s/apps/_apps.yaml) |
| Bootstrap notes | [`docs/bootstrap.md`](docs/bootstrap.md) |
| Architecture decisions | [`docs/adr/`](docs/adr/) |
| Current phase docs | [`docs/superpowers/`](docs/superpowers/) |
| Terraform/OpenTofu | [`tofu/`](tofu/) |
| Argo CD UI | [`argo.joelmccoy.dev`](https://argo.joelmccoy.dev) |
| Mealie | [`mealie.joelmccoy.dev`](https://mealie.joelmccoy.dev) |
| Kaneo | [`kaneo.joelmccoy.dev`](https://kaneo.joelmccoy.dev) |

## Architecture at a glance

```text
Internet
  │
  ▼
Cloudflare DNS + Tunnel
  │
  ▼
cloudflared → Istio Gateway API HTTPS listener
  │
  ▼
Argo CD-managed Kubernetes apps on Talos VMs
  │
  ├─ Cilium networking + Hubble visibility
  ├─ Istio Ambient service mesh
  ├─ Longhorn persistent storage
  ├─ cert-manager wildcard TLS
  └─ kube-prometheus-stack monitoring foundation
```

## Platform building blocks

| SVG | Component | What it is used for | Repo | Upstream |
| --- | --- | --- | --- | --- |
| ![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=flat-square&logo=proxmox&logoColor=white) | Proxmox VE | Hypervisor for the Talos Kubernetes VMs. | [`tofu/proxmox.tf`](tofu/proxmox.tf) | [Website](https://www.proxmox.com/en/proxmox-virtual-environment/overview) |
| ![Talos](https://img.shields.io/badge/Talos-Linux-FF7300?style=flat-square) | Talos Linux | Immutable Kubernetes node OS. OpenTofu renders and applies machine config. | [`tofu/talos.tf`](tofu/talos.tf) | [Docs](https://www.talos.dev/) |
| ![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat-square&logo=kubernetes&logoColor=white) | Kubernetes | Three combined control-plane/worker nodes for homelab services. | [`tofu/talos.tf`](tofu/talos.tf) | [Docs](https://kubernetes.io/docs/) |
| ![OpenTofu](https://img.shields.io/badge/OpenTofu-FFDA18?style=flat-square&logo=opentofu&logoColor=black) | OpenTofu | Provisions Proxmox VMs, Talos bootstrap material, and Cloudflare resources. | [`tofu/`](tofu/) | [Docs](https://opentofu.org/docs/) |
| ![Cloudflare R2](https://img.shields.io/badge/Cloudflare%20R2-F38020?style=flat-square&logo=cloudflare&logoColor=white) | Cloudflare R2 | Remote OpenTofu state backend. | [`tofu/backend.tf`](tofu/backend.tf) | [Docs](https://developers.cloudflare.com/r2/) |

## GitOps apps

The table below inventories GitOps-managed platform components. Some rows are
direct Argo CD child apps discovered by
[`k8s/apps/_apps.yaml`](k8s/apps/_apps.yaml), while others are notable
subcomponents or features configured within those apps via Helm values,
plain manifests, or both.

| SVG | App | What it is used for | Repo | Upstream |
| --- | --- | --- | --- | --- |
| ![Argo CD](https://img.shields.io/badge/Argo%20CD-EF7B4D?style=flat-square&logo=argo&logoColor=white) | Argo CD | GitOps controller and UI. Reconciles everything after bootstrap. | [`k8s/apps/argo-cd/`](k8s/apps/argo-cd/) | [Docs](https://argo-cd.readthedocs.io/) |
| ![Cilium](https://img.shields.io/badge/Cilium-F8C517?style=flat-square&logo=cilium&logoColor=black) | Cilium | CNI, eBPF datapath, kube-proxy replacement, NetworkPolicy base, and Hubble. | [`k8s/apps/cilium/`](k8s/apps/cilium/) | [Docs](https://docs.cilium.io/) |
| ![Hubble](https://img.shields.io/badge/Hubble-Cilium-F8C517?style=flat-square&logo=cilium&logoColor=black) | Hubble | Network flow observability from Cilium. Relay and UI are enabled. | [`k8s/apps/cilium/values.yaml`](k8s/apps/cilium/values.yaml) | [Docs](https://docs.cilium.io/en/stable/observability/hubble/) |
| ![Gateway API](https://img.shields.io/badge/Gateway%20API-7B42BC?style=flat-square&logo=kubernetes&logoColor=white) | Gateway API | Kubernetes-native ingress API used by the Istio gateway and HTTPRoutes. | [`k8s/apps/gateway-api/`](k8s/apps/gateway-api/) | [Docs](https://gateway-api.sigs.k8s.io/) |
| ![Istio](https://img.shields.io/badge/Istio-466BB0?style=flat-square&logo=istio&logoColor=white) | Istio base | Installs Istio CRDs and shared control-plane resources. | [`k8s/apps/istio-base/`](k8s/apps/istio-base/) | [Docs](https://istio.io/latest/docs/) |
| ![Istio CNI](https://img.shields.io/badge/Istio%20CNI-466BB0?style=flat-square&logo=istio&logoColor=white) | Istio CNI | Node-level CNI plugin required for Ambient mesh traffic redirection. | [`k8s/apps/istio-cni/`](k8s/apps/istio-cni/) | [Docs](https://istio.io/latest/docs/ambient/install/platform-prerequisites/) |
| ![istiod](https://img.shields.io/badge/istiod-466BB0?style=flat-square&logo=istio&logoColor=white) | istiod | Istio control plane for xDS, certificates, and mesh configuration. | [`k8s/apps/istiod/`](k8s/apps/istiod/) | [Docs](https://istio.io/latest/docs/ops/deployment/architecture/) |
| ![ztunnel](https://img.shields.io/badge/ztunnel-466BB0?style=flat-square&logo=istio&logoColor=white) | ztunnel | Istio Ambient node proxy that provides L4 mTLS for meshed namespaces. | [`k8s/apps/istio-ztunnel/`](k8s/apps/istio-ztunnel/) | [Docs](https://istio.io/latest/docs/ambient/architecture/data-plane/) |
| ![Istio Gateway](https://img.shields.io/badge/Istio%20Gateway-466BB0?style=flat-square&logo=istio&logoColor=white) | Istio Gateway | Internal ClusterIP HTTPS gateway that Cloudflare Tunnel reaches in-cluster. | [`k8s/apps/istio-gateway/`](k8s/apps/istio-gateway/) | [Docs](https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/) |
| ![cert-manager](https://img.shields.io/badge/cert--manager-CB3837?style=flat-square&logo=letsencrypt&logoColor=white) | cert-manager | Issues and renews wildcard TLS certificates with Let's Encrypt DNS01. | [`k8s/apps/cert-manager/`](k8s/apps/cert-manager/) | [Docs](https://cert-manager.io/docs/) |
| ![Let's Encrypt](https://img.shields.io/badge/Let%27s%20Encrypt-003A70?style=flat-square&logo=letsencrypt&logoColor=white) | Let's Encrypt | Public certificate authority for `joelmccoy.dev` and `*.joelmccoy.dev`. | [`k8s/apps/cert-manager/manifests/`](k8s/apps/cert-manager/manifests/) | [Website](https://letsencrypt.org/) |
| ![cloudflared](https://img.shields.io/badge/cloudflared-F38020?style=flat-square&logo=cloudflare&logoColor=white) | cloudflared | Outbound-only tunnel from the cluster to Cloudflare's edge. | [`k8s/apps/cloudflared/`](k8s/apps/cloudflared/) | [Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) |
| ![external-dns](https://img.shields.io/badge/external--dns-326CE5?style=flat-square&logo=kubernetes&logoColor=white) | external-dns | Watches Gateway API routes and manages Cloudflare DNS records. | [`k8s/apps/external-dns/`](k8s/apps/external-dns/) | [Docs](https://github.com/kubernetes-sigs/external-dns) |
| ![Longhorn](https://img.shields.io/badge/Longhorn-6D4AFF?style=flat-square) | Longhorn | Distributed Kubernetes block storage and default StorageClass. | [`k8s/apps/longhorn/`](k8s/apps/longhorn/) | [Docs](https://longhorn.io/docs/) |
| ![RustFS](https://img.shields.io/badge/RustFS-CE422B?style=flat-square&logo=rust&logoColor=white) | RustFS | In-cluster S3-compatible object storage (Rust). Backs Loki and future Velero, with built-in admin console + Keycloak SSO. | [`k8s/apps/rustfs/`](k8s/apps/rustfs/) | [Docs](https://docs.rustfs.com/) |
| ![Sealed Secrets](https://img.shields.io/badge/Sealed%20Secrets-326CE5?style=flat-square&logo=kubernetes&logoColor=white) | Sealed Secrets | Stores encrypted Kubernetes Secrets safely in git. | [`k8s/apps/sealed-secrets/`](k8s/apps/sealed-secrets/) | [Docs](https://github.com/bitnami-labs/sealed-secrets) |
| ![Prometheus](https://img.shields.io/badge/kube--prometheus--stack-E6522C?style=flat-square&logo=prometheus&logoColor=white) | kube-prometheus-stack | Monitoring foundation chart for Prometheus Operator and its standard Kubernetes exporters. | [`k8s/apps/monitoring/`](k8s/apps/monitoring/) | [Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) |
| ![Prometheus Operator](https://img.shields.io/badge/Prometheus%20Operator-E6522C?style=flat-square&logo=prometheus&logoColor=white) | Prometheus Operator | Manages Prometheus, Alertmanager, ServiceMonitor, and PrometheusRule custom resources. | [`k8s/apps/monitoring/values.yaml`](k8s/apps/monitoring/values.yaml) | [Docs](https://prometheus-operator.dev/) |
| ![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=flat-square&logo=prometheus&logoColor=white) | Prometheus | Scrapes and stores cluster/app metrics. Configured with modest homelab retention. | [`k8s/apps/monitoring/values.yaml`](k8s/apps/monitoring/values.yaml) | [Docs](https://prometheus.io/docs/introduction/overview/) |
| ![Alertmanager](https://img.shields.io/badge/Alertmanager-E6522C?style=flat-square&logo=prometheus&logoColor=white) | Alertmanager | Alert routing and notification engine, installed by kube-prometheus-stack. | [`k8s/apps/monitoring/values.yaml`](k8s/apps/monitoring/values.yaml) | [Docs](https://prometheus.io/docs/alerting/latest/alertmanager/) |
| ![node-exporter](https://img.shields.io/badge/node--exporter-E6522C?style=flat-square&logo=prometheus&logoColor=white) | node-exporter | Exposes Linux node CPU, memory, filesystem, and network metrics. | [`k8s/apps/monitoring/values.yaml`](k8s/apps/monitoring/values.yaml) | [Docs](https://github.com/prometheus/node_exporter) |
| ![kube-state-metrics](https://img.shields.io/badge/kube--state--metrics-326CE5?style=flat-square&logo=kubernetes&logoColor=white) | kube-state-metrics | Converts Kubernetes object state into Prometheus metrics. | [`k8s/apps/monitoring/values.yaml`](k8s/apps/monitoring/values.yaml) | [Docs](https://github.com/kubernetes/kube-state-metrics) |
| ![metrics-server](https://img.shields.io/badge/metrics--server-326CE5?style=flat-square&logo=kubernetes&logoColor=white) | metrics-server | Provides the `metrics.k8s.io` API for `kubectl top` and HPA. | [`k8s/apps/metrics-server/`](k8s/apps/metrics-server/) | [Docs](https://kubernetes-sigs.github.io/metrics-server/) |
| ![CloudNativePG](https://img.shields.io/badge/CloudNativePG-336791?style=flat-square&logo=postgresql&logoColor=white) | CloudNativePG | Postgres operator. Each app declares its own `Cluster` CR; DBs live in app namespaces. | [`k8s/apps/cnpg-operator/`](k8s/apps/cnpg-operator/) | [Docs](https://cloudnative-pg.io/) |
| ![Crossplane](https://img.shields.io/badge/Crossplane-7F7FFF?style=flat-square&logo=crossplane&logoColor=white) | Crossplane | Universal control plane. Hosts provider-keycloak for declarative SSO clients per app. | [`k8s/apps/crossplane/`](k8s/apps/crossplane/) | [Docs](https://docs.crossplane.io/) |
| ![Keycloak](https://img.shields.io/badge/Keycloak%20Operator-EA002C?style=flat-square&logo=keycloak&logoColor=white) | Keycloak operator | Manages Keycloak instance lifecycle via the `Keycloak` CR. | [`k8s/apps/keycloak-operator/`](k8s/apps/keycloak-operator/) | [Docs](https://www.keycloak.org/operator/installation) |
| ![Keycloak](https://img.shields.io/badge/Keycloak-EA002C?style=flat-square&logo=keycloak&logoColor=white) | Keycloak | OIDC identity provider for cluster apps. Realm-level config via `keycloak-config-cli` PostSync hook; per-app clients via Crossplane `Client` CRs. | [`k8s/apps/keycloak/`](k8s/apps/keycloak/) | [Docs](https://www.keycloak.org/documentation) |
| ![provider-keycloak](https://img.shields.io/badge/provider--keycloak-7F7FFF?style=flat-square) | provider-keycloak | Crossplane provider that reconciles Keycloak realms, clients, users via admin API. | [`k8s/apps/crossplane-providers/`](k8s/apps/crossplane-providers/) | [Docs](https://github.com/crossplane-contrib/provider-keycloak) |
| ![Mealie](https://img.shields.io/badge/Mealie-Recipe%20Manager-E58325?style=flat-square) | Mealie | Recipe manager, meal planner, and shopping list app with Keycloak SSO. | [`k8s/apps/mealie/`](k8s/apps/mealie/) | [Docs](https://docs.mealie.io/) |
| ![Kaneo](https://img.shields.io/badge/Kaneo-Project%20Management-4F46E5?style=flat-square) | Kaneo | Project management and ticket tracking app with Keycloak SSO and API/MCP-friendly auth. | [`k8s/apps/kaneo/`](k8s/apps/kaneo/) | [Docs](https://kaneo.app/docs) |

## Public routes

| Hostname | Owner | Purpose |
| --- | --- | --- |
| [`argo.joelmccoy.dev`](https://argo.joelmccoy.dev) | Argo CD | GitOps UI and operational dashboard. |
| [`sso.joelmccoy.dev`](https://sso.joelmccoy.dev) | Keycloak | OIDC identity provider; serves the `homelab` realm. |
| [`mealie.joelmccoy.dev`](https://mealie.joelmccoy.dev) | Mealie | Recipe manager, meal planner, and shopping list app. |
| [`kaneo.joelmccoy.dev`](https://kaneo.joelmccoy.dev) | Kaneo | Project management and ticket tracking. |
| [`s3.joelmccoy.dev`](https://s3.joelmccoy.dev) | RustFS | S3 API at `/`, admin console UI at `/rustfs/console/`. |
| `*.joelmccoy.dev` | Istio Gateway + cert-manager | Wildcard HTTPS listener for future homelab services. |

## Operating model

- **Git is source of truth.** Runtime changes should land in this repository and
  flow through Argo CD.
- **OpenTofu owns infrastructure.** Proxmox, Talos bootstrap, Cloudflare tunnel,
  and remote state are described in [`tofu/`](tofu/).
- **Argo CD owns cluster apps.** The app-of-apps discovers every
  `k8s/apps/<app>/application.yaml`.
- **Secrets stay encrypted.** Commit SealedSecrets, never plaintext credentials.
- **Small PRs beat big-bang changes.** Architecture decisions live in
  [`docs/adr/`](docs/adr/).

## Validation

The repo's pinned toolchain lives in [`.mise.toml`](.mise.toml). Typical checks:

```bash
mise install
mise run lint
mise run fmt
```

PRs run the same pre-commit path in GitHub Actions and render an Argo CD diff
preview for app changes.
