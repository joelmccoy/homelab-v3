# Claude guidance

Brief operating manual for AI assistants working in this repo.

## What this is

Personal homelab. Talos Kubernetes on Proxmox; OpenTofu provisions infra and Cloudflare resources; ArgoCD reconciles everything past bootstrap.

## Conventions

- **Toolchain** is pinned in `.mise.toml`. Run `mise install`. Add a tool only when something in this repo actually needs it; pin to the latest version at time of addition.
- **Pre-commit hooks must pass.** Install via `mise run hk-install`. Do not bypass (`--no-verify` forbidden) — fix the underlying issue.
- **No secrets in git.** Tokens flow `tofu output` → in-cluster Secrets via a helper script. Never paste real values into `.tfvars` files committed to the repo.
- **Big decisions get ADRs** in `docs/adr/`. Brief: context (2–3 sentences), decision (1–2), consequences (bullets). Use `mise run adr-new <kebab-title>`.
- **Runtime state is owned by ArgoCD** once bootstrapped. Don't `kubectl apply` directly — change git, push, let ArgoCD reconcile.
- **Don't pre-add files, configs, or scripts speculatively.** Add as needed; remove when no longer needed.

## When adding a new app/component

Four things happen together — never one without the others:

1. **Implement it** under `k8s/apps/<name>/` following the existing pattern (`application.yaml` + `manifests/` + optional `values.yaml`). New namespace? Include a `manifests/namespace.yaml` with the `istio.io/dataplane-mode: ambient` label unless there's a reason not to (mesh-incompat workload).
2. **Capture every non-trivial choice as an ADR.** Tool selection (chart vs operator), data model, integration shape — anything the next person would otherwise have to reverse-engineer from yaml. Brief format. Use `mise run adr-new <kebab-title>`.
3. **Update Renovate grouping** in `renovate.json` so dependency PRs for the new app land in a logical group. If it is support/dev tooling rather than a runtime app, group it under `support dependencies`.
4. **Update `README.md`** — add a row to the relevant table (`Platform building blocks` for infra, `GitOps apps` for cluster components). Keep the badge style consistent with existing rows.

Skipping any of the four is a half-finished change.

When using a Helm chart, pin the chart's image repositories/tags in `values.yaml` when the chart exposes stable image fields, using the chart's normal `image.repository` / `image.tag` shape where possible so Renovate's `helm-values` manager can bump them. Keep the initial pin aligned with the chart's current default image to avoid accidental rollout changes, and validate the rendered manifests before merging.

## Where to look

- Current phase scope: `docs/superpowers/specs/`
- Implementation plan: `docs/superpowers/plans/`
- Why the setup looks the way it does: `docs/adr/`
- Available task commands: `mise tasks`
- One-time cluster bring-up: `docs/bootstrap.md`
