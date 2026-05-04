# 0021 — S3 buckets via Crossplane provider-aws-s3

- **Status:** Accepted
- **Date:** 2026-05-04

## Context

Loki and any future S3-consuming workload need declaratively-managed buckets — manual `aws s3 mb` Jobs don't scale and don't fit the GitOps model. RustFS speaks the standard S3 API, so we need a Crossplane provider that targets generic S3 and accepts a custom endpoint.

## Decision

Adopt `xpkg.upbound.io/upbound/provider-aws-s3` with a `ProviderConfig` whose `endpoint.url` points at the in-cluster RustFS Service (`http://rustfs-svc.rustfs.svc.cluster.local:9001`). All AWS-specific validations are disabled (`skip_credentials_validation`, `skip_metadata_api_check`, `skip_requesting_account_id`, `skip_region_validation`) and `s3_use_path_style: true` is set since RustFS doesn't support virtual-hosted-style addressing.

## Consequences

- Per-app declarative buckets via `Bucket` (`s3.aws.upbound.io/v1beta2`) CRs in each app's `manifests/` directory — same pattern as Crossplane Keycloak `Client` CRs.
- Switching to a different S3-compatible backend later (real AWS, Cloudflare R2, Backblaze B2) is a single `ProviderConfig.endpoint.url` change — Bucket CRs are reusable.
- No User/AccessKey/Policy CRs from this provider — RustFS issues access keys via its own admin API (which we won't expose to Crossplane). For per-app least-privilege keys we'd add another mechanism later; for now Loki uses the RustFS root creds.
- `s3_use_path_style: true` means SDKs querying the bucket must also use path-style — Loki's S3 storage_config has `s3forcepathstyle: true` to match.
