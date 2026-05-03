# Cloudflare R2 (S3-compatible) state backend.
# Bucket and access keys must exist before `tofu init`.
# Auth via env: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (R2 token).
#
# The skip_* flags are required for R2 — it has no STS, no IMDS, no AWS regions,
# rejects S3 trailing checksums, and requires path-style URLs.

terraform {
  backend "s3" {
    bucket = "homelab-v3-tofu-state"
    key    = "homelab.tfstate"
    region = "auto"

    endpoints = {
      s3 = "https://73cc895f8fc761e9d76a9da012c86478.r2.cloudflarestorage.com"
    }

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
