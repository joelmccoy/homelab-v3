# 0021 — S3 buckets via Crossplane provider-aws-s3

- **Status:** Superseded
- **Date:** 2026-05-04
- **Superseded by:** Argo-managed per-app bucket bootstrap Jobs

## Context

Loki and any future S3-consuming workload need buckets created before the workload starts. RustFS speaks the standard S3 API, so the original plan was to use a Crossplane provider that targets generic S3 and accepts a custom endpoint.

In practice, `provider-aws-s3` tracks the HashiCorp AWS provider and assumes AWS-specific S3 control-plane behavior. The provider attempted `CreateBucket` with AWS-style `CreateBucketConfiguration` XML and S3 Control tagging calls; RustFS rejected the create request with `MalformedXML`, matching known failures in S3-compatible APIs before the upstream Terraform AWS provider added fallback behavior.

## Decision

Remove `xpkg.upbound.io/upbound/provider-aws-s3`, its RustFS `ProviderConfig`, and its credentials Secret. Use small Argo CD PreSync Jobs beside each S3-consuming app to perform an idempotent `head-bucket || create-bucket` against RustFS with path-style AWS CLI requests.

## Consequences

- Bucket creation remains GitOps-managed and ordered before the app workload, but it is a bootstrap action rather than a continuously reconciled bucket CR.
- Crossplane remains in use for Keycloak clients only; the AWS S3 provider and its CRDs are removed from the cluster.
- This avoids depending on AWS S3 Control APIs for RustFS. If a mature RustFS bucket/user CRD or a stable COSI driver appears later, revisit the per-app Job pattern.
- Loki and any bootstrap Jobs must use path-style S3 requests. Loki keeps `s3forcepathstyle: true`; AWS CLI Jobs use the RustFS service endpoint directly.
