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

## Where to look

- Current phase scope: `docs/superpowers/specs/`
- Implementation plan: `docs/superpowers/plans/`
- Why the setup looks the way it does: `docs/adr/`
- Available task commands: `mise tasks`
- One-time cluster bring-up: `docs/bootstrap.md`
