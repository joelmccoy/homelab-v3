# Homelab Phase 1 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up a 3-VM Talos Kubernetes cluster on Proxmox provisioned by OpenTofu, bootstrapped with Cilium + ArgoCD via a one-shot script, and reconciled via ArgoCD app-of-apps for cert-manager, Longhorn, Istio Ambient + Gateway API, cloudflared, and external-dns — including full repo scaffolding, ADRs, AI guidance, and a mise/hk toolchain.

**Architecture:** OpenTofu owns Proxmox VMs, Talos machine config, and Cloudflare tunnel/tokens; state lives in Cloudflare R2. A minimal `scripts/bootstrap.sh` installs Cilium + ArgoCD via Helm and applies the root `Application`. Everything past that point is GitOps via ArgoCD with sync waves; ArgoCD adopts the bootstrap-installed Cilium and ArgoCD helm releases for self-management. `mise` pins the toolchain and provides task runner; `hk` runs pre-commit hooks (fmt/lint/secret-scan/manifest-validate).

**Tech Stack:** OpenTofu (`bpg/proxmox`, `siderolabs/talos`, `cloudflare/cloudflare`), Talos Linux, Cilium, ArgoCD, Helm, Kustomize, cert-manager, Longhorn, Istio Ambient + Gateway API, cloudflared, external-dns, mise (toolchain + tasks), hk (pre-commit), kubeconform, gitleaks, shellcheck, tflint, markdownlint, yamllint, prettier.

**Spec reference:** `docs/superpowers/specs/2026-05-02-homelab-phase1-foundation-design.md`.

**Operator note:** This is an IaC + GitOps project, not a code-with-unit-tests project. The "test" gate per task is the appropriate validator (`tofu validate`, `tofu fmt -check`, `helm template | kubeconform`, `kubectl --dry-run=server apply`, `hk run`, `shellcheck`). End-to-end validation in the final task brings the cluster up and verifies success criteria from the spec.

**Commit policy:** The repo owner does the actual `git commit` at their own cadence. Each task's "commit" step lists the files to stage and a suggested commit message; treat them as suggested commit boundaries. Do not bypass hooks (`--no-verify` is forbidden).

---

## File Structure

| Group | Path | Responsibility |
|-------|------|----------------|
| Repo metadata | `README.md` | Top-level overview, prereqs, common commands |
| Repo metadata | `CLAUDE.md` | AI guidance for working in this repo |
| Repo metadata | `.gitignore`, `.editorconfig`, `.gitleaks.toml` | Repo hygiene |
| Toolchain | `.mise.toml` | Pinned tool versions + env |
| Toolchain | `hk.pkl` | Pre-commit hook configuration |
| Toolchain | `mise-tasks/*` | Task runner scripts (bootstrap, lint, fmt, tf-plan, etc.) |
| ADRs | `docs/adr/README.md`, `docs/adr/template.md` | ADR index + template |
| ADRs | `docs/adr/0001-…0012.md` | One ADR per locked decision from spec |
| Tofu | `tofu/versions.tf` | OpenTofu + provider version pins |
| Tofu | `tofu/backend.tf` | Cloudflare R2 (s3-compatible) state backend |
| Tofu | `tofu/providers.tf` | Provider configuration |
| Tofu | `tofu/variables.tf` | Inputs (CF zone, Proxmox endpoint, VM specs, etc.) |
| Tofu | `tofu/outputs.tf` | kubeconfig, tunnel ID, scoped tokens |
| Tofu | `tofu/proxmox.tf` | 3× Talos VMs |
| Tofu | `tofu/talos.tf` | Image factory schematic, machine configs, bootstrap |
| Tofu | `tofu/cloudflare.tf` | Tunnel + scoped API tokens |
| Bootstrap | `scripts/bootstrap.sh` | Cilium + ArgoCD helm install + root app apply |
| Bootstrap | `scripts/apply-secrets.sh` | Tofu outputs → in-cluster Secrets |
| Bootstrap | `k8s/bootstrap/cilium-values.yaml` | Cilium values consumed by bootstrap.sh |
| Bootstrap | `k8s/bootstrap/argocd-values.yaml` | ArgoCD values consumed by bootstrap.sh |
| Bootstrap | `k8s/bootstrap/root-app.yaml` | Root `Application` → `k8s/apps/` |
| ArgoCD apps | `k8s/apps/argo-cd/` | Self-management of ArgoCD |
| ArgoCD apps | `k8s/apps/cilium/` | Self-management of Cilium |
| ArgoCD apps | `k8s/apps/cert-manager/` | cert-manager + ClusterIssuers |
| ArgoCD apps | `k8s/apps/longhorn/` | Longhorn + StorageClasses |
| ArgoCD apps | `k8s/apps/istio-base/`, `istio-cni/`, `istiod/`, `istio-ztunnel/`, `istio-gateway/` | Istio Ambient stack + Gateway resource |
| ArgoCD apps | `k8s/apps/cloudflared/` | cloudflared Deployment with wildcard rule |
| ArgoCD apps | `k8s/apps/external-dns/` | external-dns Cloudflare provider |
| Specs/plans | `docs/superpowers/specs/` | Phase design specs (already written) |
| Specs/plans | `docs/superpowers/plans/` | This plan |

Boundaries: Tofu owns infra lifecycle and outputs secrets only; never installs runtime workloads. The bootstrap script is a sealed seam that exists only to break the chicken-egg between CNI and GitOps. Everything past bootstrap is ArgoCD-owned, file boundaries follow component boundaries, and per-app dirs each contain one Application + supporting raw manifests.

---

## Task 1: Initialize repo metadata

**Files:**
- Modify: `README.md`
- Create: `.gitignore`
- Create: `.editorconfig`
- Create: `.gitleaks.toml`

- [ ] **Step 1: Replace `README.md` with foundation overview**

```markdown
# homelab-v3

Personal homelab built on Talos Kubernetes running on Proxmox, with GitOps reconciliation via ArgoCD.

## Phase 1 — Foundation

See [`docs/superpowers/specs/2026-05-02-homelab-phase1-foundation-design.md`](docs/superpowers/specs/2026-05-02-homelab-phase1-foundation-design.md) for the design and [`docs/superpowers/plans/2026-05-02-homelab-phase1-foundation.md`](docs/superpowers/plans/2026-05-02-homelab-phase1-foundation.md) for the implementation plan.

## Prerequisites

- Cloudflare account with a delegated zone you own.
- A Cloudflare R2 bucket plus an R2 API token (used as the OpenTofu state backend). Create out-of-band before the first `tofu init`.
- A Proxmox host reachable from the workstation, with API token credentials.
- [`mise`](https://mise.jdx.dev) installed (everything else is pinned in `.mise.toml`).

## Getting started

```bash
mise install                # install pinned tools
mise run hk-install         # install pre-commit hook
cp tofu/example.tfvars tofu/terraform.tfvars   # fill in values (do NOT commit)
mise run tf-apply           # provision VMs, Talos, Cloudflare tunnel
mise run apply-secrets      # land tofu outputs as in-cluster Secrets
mise run bootstrap          # Cilium + ArgoCD + root Application
```

## Layout

| Path | Purpose |
|------|---------|
| `tofu/` | OpenTofu — Proxmox VMs, Talos, Cloudflare tunnel/tokens. State on R2. |
| `scripts/` | One-shot bootstrap and helper scripts. |
| `k8s/bootstrap/` | Helm values + root Application consumed by `scripts/bootstrap.sh`. |
| `k8s/apps/` | ArgoCD app-of-apps — every component past bootstrap. |
| `mise-tasks/` | Task runner scripts (`mise run …`). |
| `docs/adr/` | Architecture Decision Records. |
| `docs/superpowers/` | Design specs and implementation plans. |

## Conventions

See [`CLAUDE.md`](CLAUDE.md).
```

- [ ] **Step 2: Create `.gitignore`**

```gitignore
# OpenTofu / Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
!*.example.tfvars
.terraform.lock.hcl.bak
crash.log
crash.*.log

# Local kubeconfigs and secrets
kubeconfig
kubeconfig.*
*.kubeconfig
talosconfig
*.talosconfig
*.pem
*.key

# OS / editor
.DS_Store
.idea/
.vscode/
*.swp

# mise / direnv
.envrc.local
.mise.local.toml
```

- [ ] **Step 3: Create `.editorconfig`**

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.{tf,tfvars}]
indent_size = 2

[*.sh]
indent_size = 2

[Makefile]
indent_style = tab

[*.md]
trim_trailing_whitespace = false
```

- [ ] **Step 4: Create `.gitleaks.toml`**

```toml
title = "homelab-v3 gitleaks config"

[extend]
useDefault = true

[allowlist]
description = "Paths and patterns allowed despite default rules"
paths = [
  '''(.*?)\.example\.tfvars$''',
  '''(.*?)\.tflint\.hcl$''',
  '''docs/.*''',
]
```

- [ ] **Step 5: Verify and stage**

Run: `git status && git diff README.md`
Expected: README.md replaced, three new dotfiles staged, nothing else.

- [ ] **Step 6: Commit (suggested)**

```bash
git add README.md .gitignore .editorconfig .gitleaks.toml
git commit -m "chore: initialize repo metadata and ignore rules"
```

---

## Task 2: Pin toolchain with mise

**Files:**
- Create: `.mise.toml`

- [ ] **Step 1: Create `.mise.toml`**

```toml
# Toolchain pins for homelab-v3.
# Run `mise install` to materialize. CI and pre-commit run against these versions.

[tools]
opentofu = "1.8.5"
kubectl = "1.31.4"
helm = "3.16.3"
kustomize = "5.5.0"
talosctl = "1.9.1"
jq = "1.7.1"
yq = "4.44.5"
hk = "1.0.0"
kubeconform = "0.6.7"
gitleaks = "8.21.2"
shellcheck = "0.10.0"
tflint = "0.55.1"
"npm:markdownlint-cli2" = "0.15.0"
"npm:prettier" = "3.4.2"
"pipx:yamllint" = "1.35.1"

[env]
KUBECONFIG = "{{config_root}}/kubeconfig"
TALOSCONFIG = "{{config_root}}/talosconfig"
TF_CLI_ARGS_init = "-upgrade"
```

- [ ] **Step 2: Verify mise picks up versions**

Run: `mise install && mise ls`
Expected: every tool listed above shows an installed version. No errors.

- [ ] **Step 3: Commit (suggested)**

```bash
git add .mise.toml
git commit -m "chore: pin toolchain with mise"
```

---

## Task 3: Configure pre-commit hooks (`hk.pkl`)

**Files:**
- Create: `hk.pkl`

- [ ] **Step 1: Create `hk.pkl`**

```pkl
amends "package://github.com/jdx/hk/releases/download/v1.0.0/hk@1.0.0#/Config.pkl"

import "package://github.com/jdx/hk/releases/download/v1.0.0/hk@1.0.0#/Builtins.pkl"

local builtins = Builtins

linters {
  ["tofu-fmt"] {
    glob = List("tofu/**/*.tf", "tofu/**/*.tfvars")
    check = "tofu fmt -check -diff {{files}}"
    fix = "tofu fmt {{files}}"
    workspace_indicator = "versions.tf"
  }
  ["tflint"] = builtins.tflint
  ["yamllint"] {
    glob = List("**/*.yaml", "**/*.yml")
    check = "yamllint -s {{files}}"
  }
  ["markdownlint"] {
    glob = List("**/*.md")
    check = "markdownlint-cli2 {{files}}"
    fix = "markdownlint-cli2 --fix {{files}}"
  }
  ["shellcheck"] {
    glob = List("scripts/**/*.sh", "mise-tasks/*")
    check = "shellcheck {{files}}"
  }
  ["gitleaks"] {
    glob = List("**/*")
    check = "gitleaks protect --staged --redact --no-banner"
    workspace_indicator = ".gitleaks.toml"
  }
  ["kubeconform"] {
    glob = List("k8s/**/*.yaml")
    check = """
      kubeconform -strict -ignore-missing-schemas \
        -schema-location default \
        -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{`{{.Group}}`}}/{{`{{.ResourceKind}}`}}_{{`{{.ResourceAPIVersion}}`}}.json' \
        {{files}}
    """
  }
  ["prettier"] {
    glob = List("**/*.json", "**/*.md")
    check = "prettier --check {{files}}"
    fix = "prettier --write {{files}}"
  }
}

hooks {
  ["pre-commit"] {
    stash = "git"
    fix = true
    steps {
      ["lint"] {
        run = "hk run --linter all --staged"
      }
    }
  }
  ["pre-push"] {
    steps {
      ["lint"] {
        run = "hk run --linter all"
      }
    }
  }
}
```

- [ ] **Step 2: Verify config parses**

Run: `hk validate`
Expected: no errors. (If `hk validate` is not available in the installed version, run `hk run --help` instead — should return without error.)

- [ ] **Step 3: Commit (suggested)**

```bash
git add hk.pkl
git commit -m "chore: configure hk pre-commit linters"
```

---

## Task 4: Author mise tasks

**Files:**
- Create: `mise-tasks/hk-install`
- Create: `mise-tasks/lint`
- Create: `mise-tasks/fmt`
- Create: `mise-tasks/tf-plan`
- Create: `mise-tasks/tf-apply`
- Create: `mise-tasks/kubeconfig`
- Create: `mise-tasks/apply-secrets`
- Create: `mise-tasks/bootstrap`
- Create: `mise-tasks/hubble`
- Create: `mise-tasks/argocd-ui`
- Create: `mise-tasks/adr-new`

Each task is a shebang script. Mark all executable.

- [ ] **Step 1: Create `mise-tasks/hk-install`**

```bash
#!/usr/bin/env bash
#MISE description="Install hk pre-commit hook into .git/hooks/"
set -euo pipefail
hk install
echo "hk pre-commit hook installed."
```

- [ ] **Step 2: Create `mise-tasks/lint`**

```bash
#!/usr/bin/env bash
#MISE description="Run all linters against the repo (hk run)"
set -euo pipefail
hk run --linter all
```

- [ ] **Step 3: Create `mise-tasks/fmt`**

```bash
#!/usr/bin/env bash
#MISE description="Auto-fix formatting (tofu fmt, prettier, etc.)"
set -euo pipefail
hk run --linter all --fix
```

- [ ] **Step 4: Create `mise-tasks/tf-plan`**

```bash
#!/usr/bin/env bash
#MISE description="OpenTofu plan against tofu/ workspace"
set -euo pipefail
cd "$(dirname "$0")/../tofu"
tofu init -input=false -upgrade
tofu plan -out=tfplan
```

- [ ] **Step 5: Create `mise-tasks/tf-apply`**

```bash
#!/usr/bin/env bash
#MISE description="OpenTofu apply against tofu/ workspace"
set -euo pipefail
cd "$(dirname "$0")/../tofu"
tofu init -input=false -upgrade
tofu apply -auto-approve
```

- [ ] **Step 6: Create `mise-tasks/kubeconfig`**

```bash
#!/usr/bin/env bash
#MISE description="Write kubeconfig from Tofu output to ./kubeconfig"
set -euo pipefail
cd "$(dirname "$0")/.."
tofu -chdir=tofu output -raw kubeconfig > kubeconfig
chmod 600 kubeconfig
echo "Wrote kubeconfig (set KUBECONFIG=$(pwd)/kubeconfig)"
```

- [ ] **Step 7: Create `mise-tasks/apply-secrets`**

```bash
#!/usr/bin/env bash
#MISE description="Apply bootstrap secrets (cf tunnel + api tokens) from tofu outputs"
set -euo pipefail
cd "$(dirname "$0")/.."
exec ./scripts/apply-secrets.sh
```

- [ ] **Step 8: Create `mise-tasks/bootstrap`**

```bash
#!/usr/bin/env bash
#MISE description="One-shot cluster bootstrap: Cilium + ArgoCD + root Application"
set -euo pipefail
cd "$(dirname "$0")/.."
exec ./scripts/bootstrap.sh
```

- [ ] **Step 9: Create `mise-tasks/hubble`**

```bash
#!/usr/bin/env bash
#MISE description="Port-forward Cilium Hubble UI on http://localhost:12000"
set -euo pipefail
kubectl -n kube-system port-forward svc/hubble-ui 12000:80
```

- [ ] **Step 10: Create `mise-tasks/argocd-ui`**

```bash
#!/usr/bin/env bash
#MISE description="Port-forward ArgoCD UI on https://localhost:8080"
set -euo pipefail
kubectl -n argocd port-forward svc/argo-cd-argocd-server 8080:443
```

- [ ] **Step 11: Create `mise-tasks/adr-new`**

```bash
#!/usr/bin/env bash
#MISE description="Scaffold the next-numbered ADR under docs/adr/"
#USAGE arg "<title>" "Short kebab-case title for the ADR"
set -euo pipefail
title="${usage_title:-${1:-}}"
if [[ -z "$title" ]]; then
  echo "Usage: mise run adr-new <kebab-case-title>" >&2
  exit 2
fi

cd "$(dirname "$0")/.."
last=$(find docs/adr -maxdepth 1 -type f -name '[0-9][0-9][0-9][0-9]-*.md' \
  | sort | tail -n1 | sed -E 's|.*/([0-9]{4}).*|\1|')
next=$(printf "%04d" $((10#${last:-0} + 1)))
date_str=$(date +%Y-%m-%d)
out="docs/adr/${next}-${title}.md"

cp docs/adr/template.md "$out"
sed -i.bak "s/NNNN/${next}/g; s/YYYY-MM-DD/${date_str}/g; s/<title>/${title}/g" "$out"
rm "${out}.bak"
echo "Created $out"
```

- [ ] **Step 12: Mark all executable**

Run: `chmod +x mise-tasks/*`
Expected: no output. Verify with `ls -l mise-tasks/`.

- [ ] **Step 13: Verify mise sees the tasks**

Run: `mise tasks`
Expected: every task above listed with its description.

- [ ] **Step 14: Run shellcheck against the tasks**

Run: `shellcheck mise-tasks/*`
Expected: no warnings or errors.

- [ ] **Step 15: Commit (suggested)**

```bash
git add mise-tasks/
git commit -m "chore: add mise task runner scripts"
```

---

## Task 5: Author CLAUDE.md (AI guidance)

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Create `CLAUDE.md`**

```markdown
# Claude guidance for homelab-v3

Brief operating manual for Claude (or any AI assistant) working in this repo. Read this before making changes.

## What this repo is

GitOps + IaC for a personal homelab. A Talos Kubernetes cluster runs on Proxmox; OpenTofu provisions infra and Cloudflare resources; ArgoCD reconciles everything past bootstrap.

## Layout

| Path | Purpose |
|------|---------|
| `tofu/` | Proxmox VMs, Talos machine config, Cloudflare tunnel + scoped tokens. State on Cloudflare R2. |
| `scripts/` | One-shot helper scripts (`bootstrap.sh`, `apply-secrets.sh`). |
| `k8s/bootstrap/` | Files consumed by `scripts/bootstrap.sh` (Helm values, root Application). |
| `k8s/apps/` | ArgoCD app-of-apps — everything past Cilium + ArgoCD lives here. |
| `mise-tasks/` | Task runner. Add new operations as small files here, not in scripts. |
| `docs/adr/` | Architecture Decision Records. |
| `docs/superpowers/specs/` | Phase design specs (read these for current scope). |
| `docs/superpowers/plans/` | Implementation plans for phases. |

## Conventions

- **Tool versions** are pinned in `.mise.toml`. Run `mise install` first. Do not bump versions in code without an ADR if the change is non-trivial.
- **Pre-commit hooks must pass.** Install with `mise run hk-install`. Do not bypass (`--no-verify` is forbidden); fix the underlying issue.
- **No secrets in git.** Tokens flow through `tofu output -json` into in-cluster Secrets via `mise run apply-secrets`. If a value must be held in code, encrypt with sops or sealed-secrets (later phases).
- **Big decisions get ADRs.** Use `mise run adr-new <kebab-title>` to scaffold one. Brief: context (2–3 sentences), decision (1–2 sentences), consequences (bulleted pros/tradeoffs).
- **Post-bootstrap state is owned by ArgoCD.** Never `kubectl apply` directly to the live cluster. Change git, push, let ArgoCD reconcile.
- **Helm chart and image versions** are managed by Renovate (later phase). Don't bump versions ad-hoc in this repo until Renovate is in place — or note the bump in a commit so Renovate can pick up the line.

## Common commands

| Command | What it does |
|---------|--------------|
| `mise install` | Materialize the toolchain pinned in `.mise.toml`. |
| `mise run hk-install` | Install the pre-commit hook into `.git/hooks/`. |
| `mise run lint` | Run every linter against the tree. |
| `mise run fmt` | Auto-fix formatting. |
| `mise run tf-plan` / `mise run tf-apply` | OpenTofu plan / apply against `tofu/`. |
| `mise run kubeconfig` | Write `./kubeconfig` from Tofu output. |
| `mise run apply-secrets` | Apply bootstrap Secrets (CF tunnel + API tokens) from Tofu outputs. |
| `mise run bootstrap` | One-shot cluster bring-up (Cilium + ArgoCD + root app). |
| `mise run hubble` | Port-forward Cilium Hubble UI. |
| `mise run argocd-ui` | Port-forward ArgoCD UI. |
| `mise run adr-new <title>` | Scaffold the next-numbered ADR. |

## When in doubt

- Read the current phase spec in `docs/superpowers/specs/`.
- Read `docs/adr/` to understand why the current setup looks the way it does.
- If a change does not fit any existing ADR, draft a new one.
```

- [ ] **Step 2: Commit (suggested)**

```bash
git add CLAUDE.md
git commit -m "docs: add CLAUDE.md AI guidance"
```

---

## Task 6: Author ADR template + README

**Files:**
- Create: `docs/adr/README.md`
- Create: `docs/adr/template.md`

- [ ] **Step 1: Create `docs/adr/README.md`**

```markdown
# Architecture Decision Records

Brief, dated records of non-trivial decisions. Format: status, date, context (2–3 sentences), decision (1–2 sentences), consequences (bulleted pros/tradeoffs).

## Adding a new ADR

```bash
mise run adr-new my-decision-title
```

Edits the next-numbered file in this directory. Keep them short — context belongs in PRs and commit messages, not here.

## Index

- `0001-iac-opentofu-proxmox-talos.md`
- `0002-state-backend-cloudflare-r2.md`
- `0003-storage-longhorn.md`
- `0004-cluster-topology-3-combined-vms.md`
- `0005-cni-cilium-with-kube-proxy-replacement.md`
- `0006-service-mesh-istio-ambient-gateway-api.md`
- `0007-tls-cert-manager-letsencrypt-dns01.md`
- `0008-external-hostnames-cloudflared-wildcard.md`
- `0009-bootstrap-pattern-tofu-then-script-then-argocd.md`
- `0010-repo-layout-flat-by-purpose.md`
- `0011-toolchain-mise-hk-mise-tasks.md`
- `0012-secrets-bootstrap-deferred-eso.md`
```

- [ ] **Step 2: Create `docs/adr/template.md`**

```markdown
# NNNN — <title>

- **Status:** Accepted
- **Date:** YYYY-MM-DD

## Context

2–3 sentences on the problem.

## Decision

1–2 sentences on the choice.

## Consequences

- Pro
- Pro
- Tradeoff
```

- [ ] **Step 3: Commit (suggested)**

```bash
git add docs/adr/README.md docs/adr/template.md
git commit -m "docs(adr): add ADR template and index"
```

---

## Task 7: Write all 12 ADRs

**Files:**
- Create: `docs/adr/0001-iac-opentofu-proxmox-talos.md`
- Create: `docs/adr/0002-state-backend-cloudflare-r2.md`
- Create: `docs/adr/0003-storage-longhorn.md`
- Create: `docs/adr/0004-cluster-topology-3-combined-vms.md`
- Create: `docs/adr/0005-cni-cilium-with-kube-proxy-replacement.md`
- Create: `docs/adr/0006-service-mesh-istio-ambient-gateway-api.md`
- Create: `docs/adr/0007-tls-cert-manager-letsencrypt-dns01.md`
- Create: `docs/adr/0008-external-hostnames-cloudflared-wildcard.md`
- Create: `docs/adr/0009-bootstrap-pattern-tofu-then-script-then-argocd.md`
- Create: `docs/adr/0010-repo-layout-flat-by-purpose.md`
- Create: `docs/adr/0011-toolchain-mise-hk-mise-tasks.md`
- Create: `docs/adr/0012-secrets-bootstrap-deferred-eso.md`

- [ ] **Step 1: Write `0001-iac-opentofu-proxmox-talos.md`**

```markdown
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
```

- [ ] **Step 2: Write `0002-state-backend-cloudflare-r2.md`**

```markdown
# 0002 — State backend: Cloudflare R2

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

OpenTofu state must live somewhere durable, off the workstation, and with locking. We already use Cloudflare for DNS and tunnel; reusing the vendor minimizes account sprawl.

## Decision

Use the OpenTofu `s3` backend pointed at a Cloudflare R2 bucket (S3-compatible). Locking via R2's conditional writes (Tofu 1.10+ native lock support); no separate DynamoDB-equivalent needed.

## Consequences

- Free tier covers homelab state easily.
- Bucket and API token must be created out-of-band before `tofu init` (chicken-egg with Tofu state); documented in README.
- Token has scoped object read/write on the single bucket only.
- Outage of R2 blocks Tofu operations; acceptable for homelab.
```

- [ ] **Step 3: Write `0003-storage-longhorn.md`**

```markdown
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
```

- [ ] **Step 4: Write `0004-cluster-topology-3-combined-vms.md`**

```markdown
# 0004 — Cluster topology: 3 combined CP+worker VMs

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

A single VM avoids quorum but makes 1→3 etcd migration painful. Splitting CP and worker roles is YAGNI at homelab scale.

## Decision

Three Talos VMs, each control-plane + worker (`allowSchedulingOnControlPlanes: true`). Three-member etcd from day 1.

## Consequences

- Survives a single VM crash.
- VMs initially share one Proxmox host — host failure still loses the cluster (acceptable; resolved as hosts are added).
- ~6–9 GB RAM total for control-plane overhead; trivial on a Proxmox host of any reasonable size.
- Adding a Proxmox host = migrate one or two VMs over and quorum becomes real.
```

- [ ] **Step 5: Write `0005-cni-cilium-with-kube-proxy-replacement.md`**

```markdown
# 0005 — CNI: Cilium with kube-proxy replacement

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

Talos defaults to Flannel + kube-proxy. Flannel lacks NetworkPolicy and observability we'll want later (and that Istio Ambient interoperates with).

## Decision

Cilium with `kubeProxyReplacement: true` and Hubble enabled. Talos machine config disables Flannel and kube-proxy.

## Consequences

- eBPF datapath, native NetworkPolicy, Hubble for traffic visibility.
- ~200–400 MB RAM per node.
- Istio Ambient interop requires `socketLB.hostNamespaceOnly: true` on Cilium and `cni.exclude` configured on Istio (see ADR 0006).
- Cilium upgrades touch core networking — be deliberate, especially when only one cluster exists.
```

- [ ] **Step 6: Write `0006-service-mesh-istio-ambient-gateway-api.md`**

```markdown
# 0006 — Service mesh: Istio Ambient + Gateway API

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

We want zero-touch in-cluster mTLS, an L7 gateway, and no per-pod sidecar overhead. A separate ingress controller (ingress-nginx) plus a service mesh would be two systems where one suffices.

## Decision

Istio Ambient (ztunnels per node, no sidecars) plus Gateway API. Istio Gateway is the cluster's only ingress; no ingress-nginx. Cilium tuned for Ambient compatibility.

## Consequences

- Single L7 control plane for ingress and east-west traffic.
- Apps don't need any in-pod injection to get mTLS.
- Ambient + Cilium has a known set of knobs that must be set correctly (`socketLB.hostNamespaceOnly`, Istio `cni.exclude`).
- Waypoint proxies (per-namespace L7 enforcement) are opt-in per workload as needs arise.
```

- [ ] **Step 7: Write `0007-tls-cert-manager-letsencrypt-dns01.md`**

```markdown
# 0007 — TLS: cert-manager + Let's Encrypt DNS01 over Cloudflare

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

We want valid public certs at the cluster gateway, even though traffic enters via Cloudflare Tunnel. The same cert should be valid for split-horizon LAN access. HTTP01 won't work behind a tunnel without exposing port 80.

## Decision

cert-manager with two ClusterIssuers (LE staging, LE prod), DNS01 challenge against Cloudflare via a scoped API token (DNS edit on target zones only). Default to staging during phase 1 verification.

## Consequences

- Real certs everywhere, no per-app cert plumbing.
- Token scope minimized; no Global API Key.
- Wildcard certs available if desired (DNS01 supports them).
- LE prod rate-limit risk handled by staging-first pattern.
```

- [ ] **Step 8: Write `0008-external-hostnames-cloudflared-wildcard.md`**

```markdown
# 0008 — External hostnames: wildcard cloudflared rule + external-dns

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

We need a cheap, declarative way to expose new apps publicly without editing tunnel config per app.

## Decision

Run cloudflared as an in-cluster Deployment with a single ingress rule: `* → istio-gateway:443`. Istio Gateway routes by Host header. external-dns watches Gateway listeners and writes CNAMEs to `<tunnel>.cfargotunnel.com`.

## Consequences

- Adding an app = adding a Gateway listener; no tunnel config changes.
- Single failure surface (one cloudflared Deployment) — acceptable for homelab; can scale replicas later.
- Tunnel-scoped credential and a separate scoped DNS-edit token; both narrow.
```

- [ ] **Step 9: Write `0009-bootstrap-pattern-tofu-then-script-then-argocd.md`**

```markdown
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
```

- [ ] **Step 10: Write `0010-repo-layout-flat-by-purpose.md`**

```markdown
# 0010 — Repo layout: flat by purpose

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

ArgoCD app-of-apps repos commonly use either `clusters/<name>/` per-cluster or a flat `tofu|scripts|k8s|docs` structure. We have one cluster planned.

## Decision

Flat layout by purpose: `tofu/`, `scripts/`, `k8s/{bootstrap,apps}/`, `docs/{adr,superpowers}/`, `mise-tasks/`. If a second cluster appears, evolve to `clusters/<name>/` with an ADR.

## Consequences

- Less nesting now, fewer per-cluster knobs.
- Refactor cost when scaling to multi-cluster — accept the hit if/when needed.
```

- [ ] **Step 11: Write `0011-toolchain-mise-hk-mise-tasks.md`**

```markdown
# 0011 — Toolchain: mise + hk + mise tasks

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

We need pinned tool versions, a pre-commit hook runner, and a task runner that is not Make.

## Decision

`mise` for tool version pinning and env, `hk` for pre-commit hooks (jdx ecosystem coherent with mise), `mise-tasks/` shell scripts as the task runner.

## Consequences

- One vendor for toolchain, hooks, and tasks; less plumbing.
- Each task is a standalone shell file — easy to read and shellcheck.
- New contributors install via `mise install`; nothing else.
```

- [ ] **Step 12: Write `0012-secrets-bootstrap-deferred-eso.md`**

```markdown
# 0012 — Secrets: bootstrap via Tofu outputs; ESO deferred

- **Status:** Accepted
- **Date:** 2026-05-02

## Context

cert-manager (Cloudflare API token), external-dns (Cloudflare API token), and cloudflared (tunnel credentials) need secrets to function. We don't want secrets in git and don't yet need a full secret manager.

## Decision

Tofu emits the values as outputs. `scripts/apply-secrets.sh` reads `tofu output -json` and `kubectl apply`s in-cluster Secrets in the relevant namespaces. External Secrets Operator + a secret manager (1Password Connect, Vault, AWS SM, etc.) are deferred to a later phase.

## Consequences

- No secrets in git, no extra control plane to run.
- Token rotation is manual: `tofu apply` regenerates, `mise run apply-secrets` re-applies.
- Migration to ESO later requires re-namespacing secrets but is straightforward.
```

- [ ] **Step 13: Lint the ADR set**

Run: `markdownlint-cli2 'docs/adr/*.md'`
Expected: no warnings or errors.

- [ ] **Step 14: Commit (suggested)**

```bash
git add docs/adr/
git commit -m "docs(adr): record phase 1 foundation decisions (0001-0012)"
```

---

## Task 8: Author OpenTofu skeleton (versions, providers, backend, vars, outputs)

**Files:**
- Create: `tofu/versions.tf`
- Create: `tofu/backend.tf`
- Create: `tofu/providers.tf`
- Create: `tofu/variables.tf`
- Create: `tofu/outputs.tf`
- Create: `tofu/example.tfvars`

- [ ] **Step 1: Create `tofu/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.8.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.7"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.45"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
```

- [ ] **Step 2: Create `tofu/backend.tf`**

```hcl
# Cloudflare R2 (S3-compatible) state backend.
# Bucket and access keys must be created out-of-band before `tofu init`.
# Endpoint host is "<account-id>.r2.cloudflarestorage.com".
# Set credentials via environment: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY.

terraform {
  backend "s3" {
    bucket = "homelab-v3-tofu-state"
    key    = "phase1/terraform.tfstate"
    region = "auto"

    endpoints = {
      s3 = "https://CHANGE_ME.r2.cloudflarestorage.com"
    }

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
    encrypt                     = true
  }
}
```

> Operator note: replace `CHANGE_ME` with the Cloudflare account ID when first running. This is the only Tofu file that needs a manual edit before `tofu init`. If this is annoying, switch to a partial backend config and pass via `-backend-config=...` later.

- [ ] **Step 3: Create `tofu/providers.tf`**

```hcl
provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
  ssh {
    agent    = true
    username = var.proxmox_ssh_user
  }
}

provider "talos" {}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
```

- [ ] **Step 4: Create `tofu/variables.tf`**

```hcl
# ---------- Proxmox ----------

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, e.g. https://pve.lan:8006/"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the form 'user@realm!tokenid=secret'."
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Name of the target Proxmox node (e.g. 'pve')."
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification on the Proxmox API. Set to false in prod."
  type        = bool
  default     = true
}

variable "proxmox_ssh_user" {
  description = "SSH user for the Proxmox host (used by bpg/proxmox for image import)."
  type        = string
  default     = "root"
}

variable "proxmox_storage_pool" {
  description = "Storage pool for VM disks."
  type        = string
  default     = "local-lvm"
}

variable "proxmox_iso_pool" {
  description = "Storage pool for the Talos ISO/qcow image."
  type        = string
  default     = "local"
}

variable "proxmox_bridge" {
  description = "Linux bridge used for VM networking."
  type        = string
  default     = "vmbr0"
}

# ---------- Cluster ----------

variable "cluster_name" {
  description = "Talos cluster name."
  type        = string
  default     = "homelab"
}

variable "cluster_endpoint_ip" {
  description = "Floating or first control-plane IP used as Talos cluster endpoint."
  type        = string
}

variable "control_plane_nodes" {
  description = "List of combined CP+worker VMs."
  type = list(object({
    name    = string
    cpu     = number
    memory  = number
    disk_gb = number
    ip      = string
    gw      = string
    mac     = optional(string)
    vmid    = optional(number)
  }))
  validation {
    condition     = length(var.control_plane_nodes) == 3
    error_message = "Phase 1 expects exactly 3 control-plane nodes."
  }
}

variable "talos_version" {
  description = "Talos image version, e.g. v1.9.1."
  type        = string
  default     = "v1.9.1"
}

variable "kubernetes_version" {
  description = "Kubernetes version, e.g. 1.31.4."
  type        = string
  default     = "1.31.4"
}

# ---------- Cloudflare ----------

variable "cloudflare_api_token" {
  description = "Cloudflare API token with permissions to create tunnels and scoped DNS-edit tokens. Used only by Tofu."
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "cloudflare_zone" {
  description = "Cloudflare zone name (e.g. example.com)."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for var.cloudflare_zone."
  type        = string
}
```

- [ ] **Step 5: Create `tofu/outputs.tf`**

```hcl
output "kubeconfig" {
  description = "Generated kubeconfig (raw)."
  value       = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "Generated talosconfig (raw)."
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Talos cluster endpoint URL."
  value       = "https://${var.cluster_endpoint_ip}:6443"
}

output "cloudflare_tunnel_id" {
  description = "Cloudflare tunnel ID."
  value       = cloudflare_tunnel.homelab.id
}

output "cloudflare_tunnel_credentials_json" {
  description = "JSON credentials for cloudflared (consumed by apply-secrets)."
  value       = local.cloudflared_credentials_json
  sensitive   = true
}

output "cloudflare_token_cert_manager" {
  description = "Scoped API token for cert-manager DNS01."
  value       = cloudflare_api_token.cert_manager.value
  sensitive   = true
}

output "cloudflare_token_external_dns" {
  description = "Scoped API token for external-dns."
  value       = cloudflare_api_token.external_dns.value
  sensitive   = true
}

output "cloudflare_zone" {
  description = "Cloudflare zone name."
  value       = var.cloudflare_zone
}
```

- [ ] **Step 6: Create `tofu/example.tfvars`**

```hcl
# Copy to terraform.tfvars and fill in. terraform.tfvars is gitignored.

proxmox_endpoint    = "https://pve.lan:8006/"
proxmox_api_token   = "tofu@pve!homelab=REPLACE-ME"
proxmox_node        = "pve"
proxmox_storage_pool = "local-lvm"
proxmox_iso_pool     = "local"
proxmox_bridge       = "vmbr0"

cluster_name        = "homelab"
cluster_endpoint_ip = "192.168.1.50"

control_plane_nodes = [
  { name = "talos-cp-0", cpu = 4, memory = 8192, disk_gb = 80, ip = "192.168.1.50", gw = "192.168.1.1" },
  { name = "talos-cp-1", cpu = 4, memory = 8192, disk_gb = 80, ip = "192.168.1.51", gw = "192.168.1.1" },
  { name = "talos-cp-2", cpu = 4, memory = 8192, disk_gb = 80, ip = "192.168.1.52", gw = "192.168.1.1" },
]

cloudflare_api_token  = "REPLACE-ME"
cloudflare_account_id = "REPLACE-ME"
cloudflare_zone       = "example.com"
cloudflare_zone_id    = "REPLACE-ME"
```

- [ ] **Step 7: Format and validate**

Run: `cd tofu && tofu fmt && tofu init -backend=false && tofu validate`
Expected: validate succeeds (`Success! The configuration is valid.`). Backend init skipped.

- [ ] **Step 8: Commit (suggested)**

```bash
git add tofu/versions.tf tofu/backend.tf tofu/providers.tf tofu/variables.tf tofu/outputs.tf tofu/example.tfvars
git commit -m "feat(tofu): add module skeleton (versions, providers, backend, vars, outputs)"
```

---

## Task 9: Author Talos image schematic and machine config (`tofu/talos.tf`)

**Files:**
- Create: `tofu/talos.tf`

- [ ] **Step 1: Create `tofu/talos.tf`**

```hcl
locals {
  # Talos image factory schematic — extensions baked into the image.
  talos_schematic = {
    customization = {
      systemExtensions = {
        officialExtensions = [
          "siderolabs/iscsi-tools",
          "siderolabs/util-linux-tools",
          "siderolabs/qemu-guest-agent",
        ]
      }
    }
  }
}

# Submit schematic to image factory and capture the schematic ID.
resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode(local.talos_schematic)
}

# Resolve a downloadable image URL for the schematic at the chosen Talos version.
data "talos_image_factory_urls" "this" {
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = "nocloud"
  architecture  = "amd64"
}

# ---------------- Machine configuration ----------------

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${var.cluster_endpoint_ip}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version

  config_patches = [
    yamlencode({
      cluster = {
        allowSchedulingOnControlPlanes = true
        network = {
          # Disable Talos' built-in CNI; Cilium will be installed by bootstrap.sh.
          cni = { name = "none" }
        }
        proxy = {
          # Disable kube-proxy; Cilium replaces it.
          disabled = true
        }
        extraManifests = []
      }
      machine = {
        kubelet = {
          extraArgs = {
            rotate-server-certificates = "true"
          }
        }
        # Required by Longhorn (iscsi).
        kernel = {
          modules = [
            { name = "iscsi_tcp" },
            { name = "dm_crypt" },
          ]
        }
      }
    }),
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for n in var.control_plane_nodes : n.ip]
  nodes                = [for n in var.control_plane_nodes : n.ip]
}

resource "talos_machine_configuration_apply" "controlplane" {
  for_each = { for n in var.control_plane_nodes : n.name => n }

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  endpoint                    = each.value.ip
  node                        = each.value.ip

  config_patches = [
    yamlencode({
      machine = {
        network = {
          hostname = each.value.name
          interfaces = [
            {
              interface = "eth0"
              dhcp      = false
              addresses = ["${each.value.ip}/24"]
              routes = [
                { network = "0.0.0.0/0", gateway = each.value.gw },
              ]
            },
          ]
          nameservers = ["1.1.1.1", "1.0.0.1"]
        }
        install = {
          disk = "/dev/sda"
        }
      }
    }),
  ]

  depends_on = [proxmox_virtual_environment_vm.talos]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = var.control_plane_nodes[0].ip
  node                 = var.control_plane_nodes[0].ip

  depends_on = [talos_machine_configuration_apply.controlplane]
}

data "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = var.cluster_endpoint_ip
  node                 = var.control_plane_nodes[0].ip

  depends_on = [talos_machine_bootstrap.this]
}
```

- [ ] **Step 2: Format and validate**

Run: `cd tofu && tofu fmt && tofu validate`
Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit (suggested)**

```bash
git add tofu/talos.tf
git commit -m "feat(tofu): Talos image schematic, machine config, bootstrap"
```

---

## Task 10: Author Proxmox VM resources (`tofu/proxmox.tf`)

**Files:**
- Create: `tofu/proxmox.tf`

- [ ] **Step 1: Create `tofu/proxmox.tf`**

```hcl
# Talos image download to the Proxmox node.
resource "proxmox_virtual_environment_download_file" "talos_nocloud" {
  content_type        = "iso"
  datastore_id        = var.proxmox_iso_pool
  node_name           = var.proxmox_node
  url                 = data.talos_image_factory_urls.this.urls.disk_image
  file_name           = "talos-${var.talos_version}-nocloud-amd64.img"
  overwrite           = false
  checksum            = data.talos_image_factory_urls.this.urls.disk_image_checksum
  checksum_algorithm  = "sha256"
}

resource "proxmox_virtual_environment_vm" "talos" {
  for_each = { for n in var.control_plane_nodes : n.name => n }

  name      = each.value.name
  node_name = var.proxmox_node
  vm_id     = try(each.value.vmid, null)

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cpu
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.proxmox_storage_pool
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = each.value.disk_gb
    file_id      = proxmox_virtual_environment_download_file.talos_nocloud.id
  }

  network_device {
    bridge      = var.proxmox_bridge
    model       = "virtio"
    mac_address = try(each.value.mac, null)
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  initialization {
    datastore_id = var.proxmox_storage_pool
    interface    = "ide2"

    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = each.value.gw
      }
    }
  }

  on_boot       = true
  reboot        = false
  stop_on_destroy = true

  lifecycle {
    ignore_changes = [
      # Talos itself manages OS state; ignore drift on boot disk after first apply.
      disk[0].file_id,
    ]
  }
}
```

- [ ] **Step 2: Format and validate**

Run: `cd tofu && tofu fmt && tofu validate`
Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Commit (suggested)**

```bash
git add tofu/proxmox.tf
git commit -m "feat(tofu): Proxmox VM resources for 3 Talos control-plane nodes"
```

---

## Task 11: Author Cloudflare resources (`tofu/cloudflare.tf`)

**Files:**
- Create: `tofu/cloudflare.tf`

- [ ] **Step 1: Create `tofu/cloudflare.tf`**

```hcl
resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

resource "cloudflare_tunnel" "homelab" {
  account_id = var.cloudflare_account_id
  name       = "${var.cluster_name}-tunnel"
  secret     = base64encode(random_password.tunnel_secret.result)
  config_src = "local"
}

# JSON blob expected by cloudflared as its credentials file.
locals {
  cloudflared_credentials_json = jsonencode({
    AccountTag   = var.cloudflare_account_id
    TunnelID     = cloudflare_tunnel.homelab.id
    TunnelName   = cloudflare_tunnel.homelab.name
    TunnelSecret = base64encode(random_password.tunnel_secret.result)
  })
}

# Permission group lookups for scoped tokens.
data "cloudflare_api_token_permission_groups" "all" {}

resource "cloudflare_api_token" "cert_manager" {
  name = "${var.cluster_name}-cert-manager"

  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.zone["DNS Write"],
      data.cloudflare_api_token_permission_groups.all.zone["Zone Read"],
    ]
    resources = {
      "com.cloudflare.api.account.zone.${var.cloudflare_zone_id}" = "*"
    }
  }
}

resource "cloudflare_api_token" "external_dns" {
  name = "${var.cluster_name}-external-dns"

  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.zone["DNS Write"],
      data.cloudflare_api_token_permission_groups.all.zone["Zone Read"],
    ]
    resources = {
      "com.cloudflare.api.account.zone.${var.cloudflare_zone_id}" = "*"
    }
  }
}
```

- [ ] **Step 2: Format and validate**

Run: `cd tofu && tofu fmt && tofu validate`
Expected: `Success! The configuration is valid.`

- [ ] **Step 3: tflint pass**

Run: `cd tofu && tflint --init && tflint`
Expected: no warnings or errors.

- [ ] **Step 4: Commit (suggested)**

```bash
git add tofu/cloudflare.tf
git commit -m "feat(tofu): Cloudflare tunnel and scoped API tokens"
```

---

## Task 12: Author bootstrap helm values and root Application

**Files:**
- Create: `k8s/bootstrap/cilium-values.yaml`
- Create: `k8s/bootstrap/argocd-values.yaml`
- Create: `k8s/bootstrap/root-app.yaml`

- [ ] **Step 1: Create `k8s/bootstrap/cilium-values.yaml`**

```yaml
# Cilium values for bootstrap install (kube-system).
# IMPORTANT: keep in sync with k8s/apps/cilium/ chart version + values
# so ArgoCD adopts the release without diff after bootstrap.

ipam:
  mode: kubernetes

kubeProxyReplacement: true

# Talos kube-apiserver is reachable on each node at this address.
k8sServiceHost: localhost
k8sServicePort: 7445

# Required for Istio Ambient interop on Cilium.
socketLB:
  hostNamespaceOnly: true

cgroup:
  autoMount:
    enabled: false
  hostRoot: /sys/fs/cgroup

securityContext:
  capabilities:
    ciliumAgent:
      - CHOWN
      - KILL
      - NET_ADMIN
      - NET_RAW
      - IPC_LOCK
      - SYS_ADMIN
      - SYS_RESOURCE
      - DAC_OVERRIDE
      - FOWNER
      - SETGID
      - SETUID
    cleanCiliumState:
      - NET_ADMIN
      - SYS_ADMIN
      - SYS_RESOURCE

hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true

operator:
  replicas: 1

# Talos hosts the kubelet-on-host root inside Talos rootfs:
hostFirewall:
  enabled: false
```

- [ ] **Step 2: Create `k8s/bootstrap/argocd-values.yaml`**

```yaml
# ArgoCD values for bootstrap install (argocd namespace).
# IMPORTANT: keep in sync with k8s/apps/argo-cd/ Application values
# so ArgoCD adopts the release without diff after bootstrap.

global:
  domain: argocd.local

configs:
  params:
    server.insecure: "true"   # initial; TLS via Istio Gateway later
  cm:
    application.resourceTrackingMethod: annotation
    timeout.reconciliation: 60s
    accounts.image-updater: ""
  repositories:
    homelab-v3:
      url: https://github.com/REPLACE_ME/homelab-v3.git
      type: git

server:
  extraArgs:
    - --insecure
  service:
    type: ClusterIP

controller:
  metrics:
    enabled: true
  resources:
    requests:
      cpu: 100m
      memory: 256Mi

repoServer:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi

applicationSet:
  enabled: true

dex:
  enabled: false

notifications:
  enabled: false
```

> Operator note: replace `REPLACE_ME` with the GitHub user/org once the repo is pushed.

- [ ] **Step 3: Create `k8s/bootstrap/root-app.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/REPLACE_ME/homelab-v3.git
    targetRevision: main
    path: k8s/apps
    directory:
      recurse: false
      include: '*.yaml'
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
      - ServerSideApply=true
```

> Operator note: `path: k8s/apps` with `directory.include: '*.yaml'` discovers each app's top-level Application manifest. Each app subdir holds its own `application.yaml`.

- [ ] **Step 4: Validate manifests**

Run: `kubeconform -strict -ignore-missing-schemas k8s/bootstrap/root-app.yaml`
Expected: `k8s/bootstrap/root-app.yaml - Application root is valid`

Run: `helm template cilium oci://ghcr.io/cilium/charts/cilium --version 1.16.4 -f k8s/bootstrap/cilium-values.yaml > /tmp/cilium-render.yaml && kubeconform -strict -ignore-missing-schemas /tmp/cilium-render.yaml`
Expected: every resource reports `valid`. (Some CRDs may not be in default schemas — that is what `-ignore-missing-schemas` covers.)

Run: `helm template argo-cd argo/argo-cd --version 7.7.10 -f k8s/bootstrap/argocd-values.yaml > /tmp/argocd-render.yaml && kubeconform -strict -ignore-missing-schemas /tmp/argocd-render.yaml`
Expected: every resource reports `valid`.

- [ ] **Step 5: Commit (suggested)**

```bash
git add k8s/bootstrap/
git commit -m "feat(bootstrap): Cilium + ArgoCD helm values and root Application"
```

---

## Task 13: Author `scripts/apply-secrets.sh`

**Files:**
- Create: `scripts/apply-secrets.sh`

- [ ] **Step 1: Create `scripts/apply-secrets.sh`**

```bash
#!/usr/bin/env bash
# Apply bootstrap Secrets from Tofu outputs into the cluster.
# Idempotent (kubectl apply). Safe to re-run after token rotation.

set -euo pipefail

TOFU_DIR="${TOFU_DIR:-tofu}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"

require_bin() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 1; }
}
require_bin tofu
require_bin "$KUBECTL_BIN"
require_bin jq

if [[ -z "${KUBECONFIG:-}" || ! -f "${KUBECONFIG}" ]]; then
  echo "KUBECONFIG is unset or file missing: ${KUBECONFIG:-<unset>}" >&2
  echo "Run 'mise run kubeconfig' first." >&2
  exit 1
fi

ensure_ns() {
  local ns="$1"
  "$KUBECTL_BIN" get ns "$ns" >/dev/null 2>&1 || "$KUBECTL_BIN" create namespace "$ns"
}

apply_secret() {
  local ns="$1" name="$2" key="$3" value="$4"
  ensure_ns "$ns"
  "$KUBECTL_BIN" create secret generic "$name" \
    -n "$ns" \
    --from-literal="${key}=${value}" \
    --dry-run=client -o yaml \
  | "$KUBECTL_BIN" apply -f -
  echo "applied secret: ${ns}/${name}"
}

# Pull tofu outputs once.
outputs_json=$(tofu -chdir="$TOFU_DIR" output -json)

cf_tunnel_creds=$(jq -r '.cloudflare_tunnel_credentials_json.value' <<<"$outputs_json")
cf_token_cm=$(jq -r '.cloudflare_token_cert_manager.value' <<<"$outputs_json")
cf_token_dns=$(jq -r '.cloudflare_token_external_dns.value' <<<"$outputs_json")

# cloudflared: a Secret with credentials.json key.
ensure_ns cloudflared
"$KUBECTL_BIN" create secret generic cloudflared-credentials \
  -n cloudflared \
  --from-literal=credentials.json="$cf_tunnel_creds" \
  --dry-run=client -o yaml \
| "$KUBECTL_BIN" apply -f -
echo "applied secret: cloudflared/cloudflared-credentials"

# cert-manager: token used by ClusterIssuer DNS01 solver.
apply_secret cert-manager cloudflare-api-token api-token "$cf_token_cm"

# external-dns: token used as CF_API_TOKEN env var.
apply_secret external-dns cloudflare-api-token api-token "$cf_token_dns"

echo "all bootstrap secrets applied."
```

- [ ] **Step 2: Mark executable**

Run: `chmod +x scripts/apply-secrets.sh`
Expected: no output.

- [ ] **Step 3: shellcheck**

Run: `shellcheck scripts/apply-secrets.sh`
Expected: no warnings or errors.

- [ ] **Step 4: Commit (suggested)**

```bash
git add scripts/apply-secrets.sh
git commit -m "feat(bootstrap): apply-secrets.sh — tofu outputs to in-cluster Secrets"
```

---

## Task 14: Author `scripts/bootstrap.sh`

**Files:**
- Create: `scripts/bootstrap.sh`

- [ ] **Step 1: Create `scripts/bootstrap.sh`**

```bash
#!/usr/bin/env bash
# Phase 1 cluster bootstrap.
# Pre-req: `mise run tf-apply` and `mise run apply-secrets` already succeeded.
# Idempotent: safe to re-run after partial failure.

set -euo pipefail

CILIUM_VERSION="${CILIUM_VERSION:-1.16.4}"
ARGOCD_VERSION="${ARGOCD_VERSION:-7.7.10}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"
HELM_BIN="${HELM_BIN:-helm}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP_DIR="${REPO_ROOT}/k8s/bootstrap"

require_bin() {
  command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 1; }
}
for b in talosctl helm kubectl jq tofu; do require_bin "$b"; done

if [[ -z "${KUBECONFIG:-}" || ! -f "${KUBECONFIG}" ]]; then
  echo "KUBECONFIG is unset or file missing: ${KUBECONFIG:-<unset>}" >&2
  echo "Run 'mise run kubeconfig' first." >&2
  exit 1
fi

# ---------- Helm repos ----------

"$HELM_BIN" repo add cilium https://helm.cilium.io/ >/dev/null 2>&1 || true
"$HELM_BIN" repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
"$HELM_BIN" repo update >/dev/null

# ---------- Cilium ----------

echo "==> Installing Cilium ${CILIUM_VERSION}"
"$HELM_BIN" upgrade --install cilium cilium/cilium \
  --version "$CILIUM_VERSION" \
  --namespace kube-system \
  -f "${BOOTSTRAP_DIR}/cilium-values.yaml" \
  --wait --timeout 10m

echo "==> Waiting for nodes Ready"
"$KUBECTL_BIN" wait --for=condition=Ready nodes --all --timeout=10m

# ---------- ArgoCD ----------

echo "==> Installing ArgoCD ${ARGOCD_VERSION}"
"$HELM_BIN" upgrade --install argo-cd argo/argo-cd \
  --version "$ARGOCD_VERSION" \
  --namespace argocd --create-namespace \
  -f "${BOOTSTRAP_DIR}/argocd-values.yaml" \
  --wait --timeout 10m

echo "==> Waiting for argocd-server Ready"
"$KUBECTL_BIN" -n argocd rollout status deploy/argo-cd-argocd-server --timeout=5m

# ---------- Root Application ----------

echo "==> Applying root Application"
"$KUBECTL_BIN" apply -f "${BOOTSTRAP_DIR}/root-app.yaml"

echo "==> Bootstrap complete. ArgoCD will reconcile k8s/apps/."
echo "    Open the UI:    mise run argocd-ui"
echo "    Initial password (delete after first login):"
"$KUBECTL_BIN" -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d || true
echo
```

- [ ] **Step 2: Mark executable**

Run: `chmod +x scripts/bootstrap.sh`
Expected: no output.

- [ ] **Step 3: shellcheck**

Run: `shellcheck scripts/bootstrap.sh`
Expected: no warnings or errors.

- [ ] **Step 4: Commit (suggested)**

```bash
git add scripts/bootstrap.sh
git commit -m "feat(bootstrap): bootstrap.sh — Cilium + ArgoCD + root Application"
```

---

## Task 15: ArgoCD self-management Application

**Files:**
- Create: `k8s/apps/argo-cd/application.yaml`

- [ ] **Step 1: Create `k8s/apps/argo-cd/application.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argo-cd
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-10"
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-cd
    targetRevision: 7.7.10
    helm:
      releaseName: argo-cd
      valueFiles: []
      values: |
        global:
          domain: argocd.local
        configs:
          params:
            server.insecure: "true"
          cm:
            application.resourceTrackingMethod: annotation
            timeout.reconciliation: 60s
        server:
          extraArgs:
            - --insecure
          service:
            type: ClusterIP
        applicationSet:
          enabled: true
        dex:
          enabled: false
        notifications:
          enabled: false
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
      - RespectIgnoreDifferences=true
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
```

> Note: chart version + key values must match `k8s/bootstrap/argocd-values.yaml`. When bumping, update both files in the same commit.

- [ ] **Step 2: Validate**

Run: `kubeconform -strict -ignore-missing-schemas k8s/apps/argo-cd/application.yaml`
Expected: `valid`.

- [ ] **Step 3: Commit (suggested)**

```bash
git add k8s/apps/argo-cd/
git commit -m "feat(argocd): self-management Application"
```

---

## Task 16: Cilium self-management Application

**Files:**
- Create: `k8s/apps/cilium/application.yaml`

- [ ] **Step 1: Create `k8s/apps/cilium/application.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cilium
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-10"
spec:
  project: default
  source:
    repoURL: https://helm.cilium.io/
    chart: cilium
    targetRevision: 1.16.4
    helm:
      releaseName: cilium
      values: |
        ipam:
          mode: kubernetes
        kubeProxyReplacement: true
        k8sServiceHost: localhost
        k8sServicePort: 7445
        socketLB:
          hostNamespaceOnly: true
        cgroup:
          autoMount:
            enabled: false
          hostRoot: /sys/fs/cgroup
        securityContext:
          capabilities:
            ciliumAgent:
              - CHOWN
              - KILL
              - NET_ADMIN
              - NET_RAW
              - IPC_LOCK
              - SYS_ADMIN
              - SYS_RESOURCE
              - DAC_OVERRIDE
              - FOWNER
              - SETGID
              - SETUID
            cleanCiliumState:
              - NET_ADMIN
              - SYS_ADMIN
              - SYS_RESOURCE
        hubble:
          enabled: true
          relay:
            enabled: true
          ui:
            enabled: true
        operator:
          replicas: 1
        hostFirewall:
          enabled: false
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  syncPolicy:
    automated:
      prune: false
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
```

- [ ] **Step 2: Validate**

Run: `kubeconform -strict -ignore-missing-schemas k8s/apps/cilium/application.yaml`
Expected: `valid`.

- [ ] **Step 3: Commit (suggested)**

```bash
git add k8s/apps/cilium/
git commit -m "feat(cilium): self-management Application"
```

---

## Task 17: cert-manager Application + ClusterIssuers

**Files:**
- Create: `k8s/apps/cert-manager/application.yaml`
- Create: `k8s/apps/cert-manager/clusterissuer-staging.yaml`
- Create: `k8s/apps/cert-manager/clusterissuer-prod.yaml`

- [ ] **Step 1: Create `k8s/apps/cert-manager/application.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-5"
spec:
  project: default
  sources:
    - repoURL: https://charts.jetstack.io
      chart: cert-manager
      targetRevision: v1.16.2
      helm:
        releaseName: cert-manager
        values: |
          installCRDs: true
          prometheus:
            enabled: false
          extraArgs:
            - --dns01-recursive-nameservers-only
            - --dns01-recursive-nameservers=1.1.1.1:53,8.8.8.8:53
    - repoURL: https://github.com/REPLACE_ME/homelab-v3.git
      targetRevision: main
      path: k8s/apps/cert-manager
      directory:
        include: 'clusterissuer-*.yaml'
  destination:
    server: https://kubernetes.default.svc
    namespace: cert-manager
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

> Operator note: replace `REPLACE_ME` with your GitHub user/org. The multi-source pattern keeps the helm chart and the ClusterIssuers in one Application — sync wave applies to both.

- [ ] **Step 2: Create `k8s/apps/cert-manager/clusterissuer-staging.yaml`**

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: REPLACE_ME@example.com
    privateKeySecretRef:
      name: letsencrypt-staging-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
```

- [ ] **Step 3: Create `k8s/apps/cert-manager/clusterissuer-prod.yaml`**

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: REPLACE_ME@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
```

> Operator note: the Cloudflare API token Secret is created in `cert-manager` namespace by `apply-secrets.sh`.

- [ ] **Step 4: Validate**

Run: `kubeconform -strict -ignore-missing-schemas k8s/apps/cert-manager/*.yaml`
Expected: every file reports `valid` (ClusterIssuer schema may need `-schema-location` for cert-manager CRDs; using `-ignore-missing-schemas` is acceptable here because we know the CRDs install at runtime).

- [ ] **Step 5: Commit (suggested)**

```bash
git add k8s/apps/cert-manager/
git commit -m "feat(cert-manager): Application + LE staging/prod ClusterIssuers"
```

---

## Task 18: Longhorn Application + StorageClass

**Files:**
- Create: `k8s/apps/longhorn/application.yaml`
- Create: `k8s/apps/longhorn/storageclass-default.yaml`

- [ ] **Step 1: Create `k8s/apps/longhorn/application.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: longhorn
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-5"
spec:
  project: default
  sources:
    - repoURL: https://charts.longhorn.io
      chart: longhorn
      targetRevision: 1.7.2
      helm:
        releaseName: longhorn
        values: |
          defaultSettings:
            defaultDataPath: /var/lib/longhorn
            createDefaultDiskLabeledNodes: true
            defaultReplicaCount: 1
            replicaSoftAntiAffinity: true
            storageOverProvisioningPercentage: 200
          persistence:
            defaultClass: false
          longhornUI:
            replicas: 1
          ingress:
            enabled: false
    - repoURL: https://github.com/REPLACE_ME/homelab-v3.git
      targetRevision: main
      path: k8s/apps/longhorn
      directory:
        include: 'storageclass-*.yaml'
  destination:
    server: https://kubernetes.default.svc
    namespace: longhorn-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

> Operator note: `defaultReplicaCount: 1` because phase 1 starts on a single physical host. Bump to 2 when a second Proxmox host is online; bump to 3 with three hosts.

- [ ] **Step 2: Create `k8s/apps/longhorn/storageclass-default.yaml`**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
    argocd.argoproj.io/sync-wave: "0"
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
parameters:
  numberOfReplicas: "1"
  staleReplicaTimeout: "30"
  fromBackup: ""
  fsType: "ext4"
  dataLocality: "best-effort"
```

- [ ] **Step 3: Validate**

Run: `kubeconform -strict -ignore-missing-schemas k8s/apps/longhorn/*.yaml`
Expected: every file reports `valid`.

- [ ] **Step 4: Commit (suggested)**

```bash
git add k8s/apps/longhorn/
git commit -m "feat(longhorn): Application + default StorageClass (replica=1)"
```

---

## Task 19: Istio base + istiod + CNI Applications

**Files:**
- Create: `k8s/apps/istio-base/application.yaml`
- Create: `k8s/apps/istio-cni/application.yaml`
- Create: `k8s/apps/istiod/application.yaml`

- [ ] **Step 1: Create `k8s/apps/istio-base/application.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-base
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-10"
spec:
  project: default
  source:
    repoURL: https://istio-release.storage.googleapis.com/charts
    chart: base
    targetRevision: 1.24.1
    helm:
      releaseName: istio-base
      values: |
        defaultRevision: default
  destination:
    server: https://kubernetes.default.svc
    namespace: istio-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

- [ ] **Step 2: Create `k8s/apps/istio-cni/application.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-cni
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-5"
spec:
  project: default
  source:
    repoURL: https://istio-release.storage.googleapis.com/charts
    chart: cni
    targetRevision: 1.24.1
    helm:
      releaseName: istio-cni
      values: |
        profile: ambient
        cni:
          ambient:
            enabled: true
          excludeNamespaces:
            - kube-system
            - argocd
            - longhorn-system
  destination:
    server: https://kubernetes.default.svc
    namespace: istio-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

- [ ] **Step 3: Create `k8s/apps/istiod/application.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istiod
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-5"
spec:
  project: default
  source:
    repoURL: https://istio-release.storage.googleapis.com/charts
    chart: istiod
    targetRevision: 1.24.1
    helm:
      releaseName: istiod
      values: |
        profile: ambient
        pilot:
          env:
            PILOT_ENABLE_AMBIENT: "true"
        meshConfig:
          accessLogFile: /dev/stdout
          defaultConfig:
            tracing: {}
  destination:
    server: https://kubernetes.default.svc
    namespace: istio-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

- [ ] **Step 4: Validate**

Run: `kubeconform -strict -ignore-missing-schemas k8s/apps/istio-base/*.yaml k8s/apps/istio-cni/*.yaml k8s/apps/istiod/*.yaml`
Expected: every file reports `valid`.

- [ ] **Step 5: Commit (suggested)**

```bash
git add k8s/apps/istio-base/ k8s/apps/istio-cni/ k8s/apps/istiod/
git commit -m "feat(istio): base + CNI + istiod Applications (ambient profile)"
```

---

## Task 20: Istio ztunnel + Gateway resources

**Files:**
- Create: `k8s/apps/istio-ztunnel/application.yaml`
- Create: `k8s/apps/istio-gateway/application.yaml`
- Create: `k8s/apps/istio-gateway/gateway.yaml`

- [ ] **Step 1: Create `k8s/apps/istio-ztunnel/application.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-ztunnel
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  project: default
  source:
    repoURL: https://istio-release.storage.googleapis.com/charts
    chart: ztunnel
    targetRevision: 1.24.1
    helm:
      releaseName: ztunnel
      values: |
        profile: ambient
  destination:
    server: https://kubernetes.default.svc
    namespace: istio-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
```

- [ ] **Step 2: Create `k8s/apps/istio-gateway/application.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: istio-gateway
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  project: default
  sources:
    - repoURL: https://istio-release.storage.googleapis.com/charts
      chart: gateway
      targetRevision: 1.24.1
      helm:
        releaseName: istio-gateway
        values: |
          name: istio-gateway
          service:
            type: ClusterIP
            ports:
              - name: http
                port: 80
                targetPort: 80
              - name: https
                port: 443
                targetPort: 443
    - repoURL: https://github.com/REPLACE_ME/homelab-v3.git
      targetRevision: main
      path: k8s/apps/istio-gateway
      directory:
        include: 'gateway.yaml'
  destination:
    server: https://kubernetes.default.svc
    namespace: istio-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
```

- [ ] **Step 3: Create `k8s/apps/istio-gateway/gateway.yaml`**

```yaml
# Cluster-wide Gateway used as the single ingress point.
# Hostnames live on individual HTTPRoute resources owned by each app.
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: public
  namespace: istio-system
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
    argocd.argoproj.io/sync-wave: "5"
spec:
  gatewayClassName: istio
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: All
    - name: https
      protocol: HTTPS
      port: 443
      hostname: "*.REPLACE_ME.example.com"
      tls:
        mode: Terminate
        certificateRefs:
          - name: public-tls
      allowedRoutes:
        namespaces:
          from: All
```

> Operator note: `cert-manager.io/cluster-issuer` annotation switches between staging and prod. Start on staging; flip to `letsencrypt-prod` after verifying issuance works. Replace `REPLACE_ME.example.com` with your zone.

- [ ] **Step 4: Validate**

Run: `kubeconform -strict -ignore-missing-schemas k8s/apps/istio-ztunnel/*.yaml k8s/apps/istio-gateway/*.yaml`
Expected: every file reports `valid`.

- [ ] **Step 5: Commit (suggested)**

```bash
git add k8s/apps/istio-ztunnel/ k8s/apps/istio-gateway/
git commit -m "feat(istio): ztunnel + cluster Gateway with HTTPS listener"
```

---

## Task 21: cloudflared Application

**Files:**
- Create: `k8s/apps/cloudflared/application.yaml`
- Create: `k8s/apps/cloudflared/deployment.yaml`
- Create: `k8s/apps/cloudflared/configmap.yaml`

- [ ] **Step 1: Create `k8s/apps/cloudflared/application.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cloudflared
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  project: default
  source:
    repoURL: https://github.com/REPLACE_ME/homelab-v3.git
    targetRevision: main
    path: k8s/apps/cloudflared
    directory:
      include: '{deployment,configmap}.yaml'
  destination:
    server: https://kubernetes.default.svc
    namespace: cloudflared
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

- [ ] **Step 2: Create `k8s/apps/cloudflared/configmap.yaml`**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflared-config
  namespace: cloudflared
data:
  config.yaml: |
    tunnel: homelab-tunnel
    credentials-file: /etc/cloudflared/credentials.json
    metrics: 0.0.0.0:2000
    no-autoupdate: true
    ingress:
      - service: https://istio-gateway.istio-system.svc.cluster.local:443
        originRequest:
          noTLSVerify: true
      - service: http_status:404
```

- [ ] **Step 3: Create `k8s/apps/cloudflared/deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflared
  labels:
    app.kubernetes.io/name: cloudflared
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: cloudflared
  template:
    metadata:
      labels:
        app.kubernetes.io/name: cloudflared
    spec:
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:2024.12.2
          args:
            - tunnel
            - --config
            - /etc/cloudflared/config.yaml
            - run
          livenessProbe:
            httpGet:
              path: /ready
              port: 2000
            initialDelaySeconds: 10
            periodSeconds: 10
          ports:
            - name: metrics
              containerPort: 2000
          volumeMounts:
            - name: config
              mountPath: /etc/cloudflared/config.yaml
              subPath: config.yaml
            - name: credentials
              mountPath: /etc/cloudflared/credentials.json
              subPath: credentials.json
              readOnly: true
      volumes:
        - name: config
          configMap:
            name: cloudflared-config
        - name: credentials
          secret:
            secretName: cloudflared-credentials
```

> Operator note: `tunnel: homelab-tunnel` must match the tunnel name created by Tofu. Adjust if `var.cluster_name` is changed from `homelab`.

- [ ] **Step 4: Validate**

Run: `kubeconform -strict -ignore-missing-schemas k8s/apps/cloudflared/*.yaml`
Expected: every file reports `valid`.

- [ ] **Step 5: Commit (suggested)**

```bash
git add k8s/apps/cloudflared/
git commit -m "feat(cloudflared): tunnel Deployment with single wildcard ingress rule"
```

---

## Task 22: external-dns Application

**Files:**
- Create: `k8s/apps/external-dns/application.yaml`

- [ ] **Step 1: Create `k8s/apps/external-dns/application.yaml`**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-dns
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  project: default
  source:
    repoURL: https://kubernetes-sigs.github.io/external-dns
    chart: external-dns
    targetRevision: 1.15.0
    helm:
      releaseName: external-dns
      values: |
        provider: cloudflare
        sources:
          - gateway-httproute
          - gateway-grpcroute
        env:
          - name: CF_API_TOKEN
            valueFrom:
              secretKeyRef:
                name: cloudflare-api-token
                key: api-token
        domainFilters:
          - REPLACE_ME.example.com
        policy: sync
        registry: txt
        txtOwnerId: homelab
        extraArgs:
          - --cloudflare-proxied=false
          - --gateway-name=public
          - --gateway-namespace=istio-system
        logLevel: info
  destination:
    server: https://kubernetes.default.svc
    namespace: external-dns
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

> Operator note: replace `REPLACE_ME.example.com` with your Cloudflare zone. `--cloudflare-proxied=false` is required because we route through the Cloudflare Tunnel CNAME, which is itself proxied; setting proxied=true on the CNAME would conflict.

- [ ] **Step 2: Validate**

Run: `kubeconform -strict -ignore-missing-schemas k8s/apps/external-dns/application.yaml`
Expected: `valid`.

- [ ] **Step 3: Commit (suggested)**

```bash
git add k8s/apps/external-dns/
git commit -m "feat(external-dns): Application targeting Cloudflare zone via Gateway API"
```

---

## Task 23: Verify all manifests pass kubeconform + lint

**Files:** none (verification task)

- [ ] **Step 1: Run repo-wide manifest validation**

Run:
```bash
kubeconform -strict -ignore-missing-schemas \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  $(find k8s -name '*.yaml')
```
Expected: every resource reports `valid` (CRDs-catalog covers cert-manager, ArgoCD, Gateway API). Resources still reporting `unknown` should be inspected.

- [ ] **Step 2: Run repo-wide lint**

Run: `mise run lint`
Expected: every linter passes (no warnings, no errors).

- [ ] **Step 3: Commit fixups (if any)**

If any lint or schema errors required code changes, commit them:

```bash
git add -p
git commit -m "fix: address lint and schema errors uncovered during validation"
```

---

## Task 24: End-to-end bring-up

**Files:** none (live system task)

This task brings the cluster up against real Proxmox + Cloudflare. Run it on the workstation that can reach Proxmox API.

- [ ] **Step 1: One-time R2 bucket + token**

Pre-condition: Cloudflare R2 bucket `homelab-v3-tofu-state` exists; an R2 API token with object read/write on that bucket has been created and exported as `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` in the shell. Replace `CHANGE_ME` in `tofu/backend.tf` with the Cloudflare account ID. (This is the only manual edit Tofu needs.)

- [ ] **Step 2: Fill in `terraform.tfvars`**

Run: `cp tofu/example.tfvars tofu/terraform.tfvars && $EDITOR tofu/terraform.tfvars`
Expected: every `REPLACE-ME` filled in. File is gitignored.

- [ ] **Step 3: Tofu apply**

Run: `mise run tf-apply`
Expected: provisions 3 Talos VMs, applies machine config, bootstraps etcd, emits outputs (kubeconfig, talosconfig, tunnel ID, scoped tokens). Apply duration: ~10–20 minutes first run.

- [ ] **Step 4: Pull kubeconfig**

Run: `mise run kubeconfig`
Expected: writes `./kubeconfig` (mode 600). `KUBECONFIG` env var already points there via `.mise.toml`.

- [ ] **Step 5: Apply bootstrap secrets**

Run: `mise run apply-secrets`
Expected: creates `cloudflared/cloudflared-credentials`, `cert-manager/cloudflare-api-token`, `external-dns/cloudflare-api-token` in their namespaces. (Namespaces auto-created.)

- [ ] **Step 6: Run bootstrap**

Run: `mise run bootstrap`
Expected: Cilium installs and nodes go Ready; ArgoCD installs; root Application applied; ArgoCD begins reconciling `k8s/apps/`.

- [ ] **Step 7: Watch reconciliation**

Run: `mise run argocd-ui &` then open `https://localhost:8080`. Initial admin password printed by bootstrap script.
Expected within ~10 minutes: every Application reaches `Synced` + `Healthy` for cilium, argo-cd, cert-manager, longhorn, istio-base, istio-cni, istiod, istio-ztunnel, istio-gateway, cloudflared, external-dns. (cert-manager's `letsencrypt-prod` ClusterIssuer remains `Ready: False` until first cert request — that is fine; staging is the default in the Gateway annotation.)

- [ ] **Step 8: Verify Cilium and Hubble**

Run: `kubectl -n kube-system get pods -l app.kubernetes.io/part-of=cilium`
Expected: every pod Running.

Run (optional): `mise run hubble &` then open `http://localhost:12000`.
Expected: Hubble UI shows in-cluster traffic.

- [ ] **Step 9: Verify Longhorn**

Run: `kubectl get sc longhorn -o yaml`
Expected: default StorageClass marked default; provisioner `driver.longhorn.io`.

Run: `kubectl get nodes.longhorn.io -n longhorn-system`
Expected: 3 nodes listed, each Ready, with at least one disk per node.

- [ ] **Step 10: Verify Gateway and TLS path**

Deploy a tiny test workload + HTTPRoute (do not commit unless you want it kept):

```yaml
# /tmp/whoami-test.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: whoami
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: whoami, namespace: whoami}
spec:
  replicas: 1
  selector: {matchLabels: {app: whoami}}
  template:
    metadata: {labels: {app: whoami}}
    spec:
      containers:
        - name: whoami
          image: traefik/whoami:v1.10
          ports: [{containerPort: 80}]
---
apiVersion: v1
kind: Service
metadata: {name: whoami, namespace: whoami}
spec:
  selector: {app: whoami}
  ports: [{port: 80, targetPort: 80}]
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: whoami, namespace: whoami}
spec:
  parentRefs:
    - name: public
      namespace: istio-system
  hostnames: ["whoami.REPLACE_ME.example.com"]
  rules:
    - matches: [{path: {type: PathPrefix, value: "/"}}]
      backendRefs: [{name: whoami, port: 80}]
```

Run: `kubectl apply -f /tmp/whoami-test.yaml`
Expected: pod Running; HTTPRoute Accepted; external-dns creates a CNAME `whoami.<zone>` → `<tunnel>.cfargotunnel.com` (visible in Cloudflare DNS UI within ~1 minute).

Run: `curl -v https://whoami.REPLACE_ME.example.com/`
Expected (with staging issuer): TLS handshake completes against the LE staging CA; HTTP 200 with whoami output. Browser will show "untrusted" because staging CA — confirm via curl `--insecure`.

- [ ] **Step 11: Flip Gateway to LE prod**

Edit `k8s/apps/istio-gateway/gateway.yaml`: change `cert-manager.io/cluster-issuer: letsencrypt-staging` → `letsencrypt-prod`. Commit and push (per the user's commit policy):

```bash
git add k8s/apps/istio-gateway/gateway.yaml
git commit -m "feat(gateway): switch to LE production issuer after staging verification"
git push
```

Wait for ArgoCD to reconcile.
Expected: cert-manager re-issues from LE prod; `curl https://whoami.REPLACE_ME.example.com/` succeeds without `--insecure`.

- [ ] **Step 12: Tear down test workload**

Run: `kubectl delete -f /tmp/whoami-test.yaml && rm /tmp/whoami-test.yaml`
Expected: namespace gone; corresponding DNS record removed by external-dns.

- [ ] **Step 13: Final lint pass**

Run: `mise run lint`
Expected: clean.

- [ ] **Step 14: Capture phase-1 success**

Phase 1 success criteria from spec:

- [x] `mise run tf-apply && mise run apply-secrets && mise run bootstrap` produced a healthy 3-node Talos cluster with Cilium + ArgoCD running.
- [x] ArgoCD reconciled `k8s/apps/` to green for cert-manager, Longhorn, all Istio components, cloudflared, external-dns; self-managed Cilium and ArgoCD healthy.
- [x] Test HTTPRoute reachable from public internet with valid LE production cert.
- [x] `mise run lint` passes on a clean checkout.
- [x] ADRs 0001–0012 present.
- [x] `CLAUDE.md` present and accurate.

Done.

---

## Self-review checklist

After authoring, verified inline:

- **Spec coverage:** every spec section has at least one task. Architecture → tasks 8–22; bootstrap order → tasks 12–14, 24; ownership matrix → tasks 8–22; toolchain → tasks 2–4; ADRs → task 7; CLAUDE.md → task 5; success criteria → task 24 step 14.
- **Placeholder scan:** no `TBD` / `TODO` / "implement later". Concrete code in every step. `REPLACE_ME` markers are intentional operator inputs (GitHub repo URL, email, zone) and called out via "Operator note" callouts.
- **Type/name consistency:** chart/version pins match between `k8s/bootstrap/*-values.yaml` and the corresponding `k8s/apps/*/application.yaml` (Cilium 1.16.4, ArgoCD 7.7.10, Istio 1.24.1). Secret names match between `apply-secrets.sh` and consumers (`cloudflared-credentials`, `cloudflare-api-token`).
- **Sync wave order:** wave -10 (CRDs/base/argo-cd self/cilium self) → wave -5 (controllers: cert-manager, longhorn, istiod, istio-cni) → wave 0 (ClusterIssuers, StorageClass, ztunnel) → wave 5 (cloudflared, external-dns, Gateway). Matches spec.
