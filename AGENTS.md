# Agent guidance

Brief operating manual for AI assistants and automation working in this repo.
This file is the canonical repo-wide guidance; tool-specific files should point
here instead of duplicating policy.

## What this is

Personal homelab. Talos Kubernetes on Proxmox; OpenTofu provisions infra and
Cloudflare resources; Argo CD reconciles everything past bootstrap.

## Conventions

- **Toolchain** is pinned in `.mise.toml`. Run `mise install`. Add a tool only
  when something in this repo actually needs it; pin to the latest version at
  time of addition.
- **Pre-commit hooks must pass.** Install via `mise run hk-install`. Do not
  bypass hooks (`--no-verify` forbidden) — fix the underlying issue.
- **No secrets in git.** Tokens flow `tofu output` → in-cluster Secrets via a
  helper script. Never paste real values into `.tfvars` files committed to the
  repo.
- **Big decisions get ADRs** in `docs/adr/`. Brief: context (2–3 sentences),
  decision (1–2), consequences (bullets). Use `mise run adr-new <kebab-title>`.
- **Runtime state is owned by Argo CD** once bootstrapped. Do not `kubectl apply`
  directly — change git, push, let Argo CD reconcile.
- **Do not pre-add files, configs, or scripts speculatively.** Add what the task
  needs; remove it when no longer needed.

## When adding a new app/component

Four things happen together — never one without the others:

1. **Implement it** under `k8s/apps/<name>/` following the existing pattern
   (`application.yaml` + `manifests/` + optional `values.yaml`). New namespace?
   Include `manifests/namespace.yaml` with the `istio.io/dataplane-mode:
   ambient` label unless there is a reason not to (mesh-incompatible workload).
2. **Capture every non-trivial choice as an ADR.** Tool selection (chart vs
   operator), data model, integration shape — anything the next person would
   otherwise have to reverse-engineer from yaml. Keep the ADR brief.
3. **Update Renovate grouping** in `renovate.json` so dependency PRs for the new
   app land in a logical group. If it is support/dev tooling rather than a
   runtime app, group it under `support dependencies`.
4. **Update `README.md`** — add a row to the relevant table (`Platform building
   blocks` for infra, `GitOps apps` for cluster components). Keep the badge
   style consistent with existing rows.

Skipping any of the four is a half-finished change.

When using a Helm chart, pin the chart's image repositories/tags in
`values.yaml` when the chart exposes stable image fields, using the chart's
normal `image.repository` / `image.tag` shape where possible so Renovate's
`helm-values` manager can bump them. Keep the initial pin aligned with the
chart's current default image to avoid accidental rollout changes, and validate
the rendered manifests before merging.

## Review guidance

This section is advisory repo-wide guidance for human and AI reviewers. Treat it
as medium priority by default: useful signal, not bureaucracy cosplay.

- Focus review effort on correctness, security, GitOps ownership, operational
  safety, upgrade/rollback behavior, validation gaps, and maintainability.
- Call out likely breakage, secret exposure, unsafe infra mutation, or repo
  policy violations as blocking.
- Mark design, reliability, readability, and follow-up concerns as advisory
  unless they create concrete risk.
- Avoid blocking on subjective style, tool-specific preferences, speculative
  rewrites, or changes unrelated to the PR.
- Prefer small concrete suggestions over broad complaints. Cite the file/path,
  explain the risk, and recommend the smallest safe fix.
- If assumptions matter, state them. If one decision blocks safe review, ask one
  concise question instead of spraying hypotheticals everywhere.
- For generated or dependency-heavy changes, review the declared source of truth
  plus rendered output when practical.
- Validation should match the change: `mise run lint` for repo checks; `tofu
  validate`/`tofu plan` for infra; `helm template`, Argo CD diff, or
  Kubernetes dry-run-style checks for app manifests when available.

Suggested comment labels:

- `[blocking]` likely breakage, safety issue, secret leak, destructive operation,
  or clear repo-policy violation.
- `[advisory]` medium-priority improvement, risk reduction, missing validation,
  or maintainability concern.
- `[nit]` optional cleanup that should not block merge.

## Where to look

- Architecture decisions: `docs/adr/`
- Available task commands: `mise tasks`
- One-time cluster bring-up: `docs/bootstrap.md`
