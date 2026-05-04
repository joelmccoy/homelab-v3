locals {
  # Well-known Cloudflare permission group IDs (stable, from API tokens schema docs).
  cf_perm_dns_write = "4755a26eedb94da69e1066d98aa820be"
  cf_perm_zone_read = "c8fed203ed3043cba015a93ad1616f1f"
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id = var.cloudflare_account_id
  name       = "${var.cluster_name}-tunnel"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id

  config = {
    ingress = [
      {
        service = "https://istio-gateway-istio.istio-ingress.svc.cluster.local:443"
        origin_request = {
          # Wildcard cert is for *.joelmccoy.dev — pick any subdomain for SNI.
          # Host header is preserved separately, so HTTPRoute routing isn't affected.
          # Keep origin TLS verification enabled; SNI makes the cert validate.
          origin_server_name = "gateway.joelmccoy.dev"
          no_tls_verify      = false
        }
      },
    ]
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}

resource "cloudflare_api_token" "cert_manager" {
  name = "${var.cluster_name}-cert-manager"

  policies = [{
    effect = "allow"
    permission_groups = [
      { id = local.cf_perm_dns_write },
      { id = local.cf_perm_zone_read },
    ]
    resources = jsonencode({
      "com.cloudflare.api.account.zone.${var.cloudflare_zone_id}" = "*"
    })
  }]
}

resource "cloudflare_api_token" "external_dns" {
  name = "${var.cluster_name}-external-dns"

  policies = [{
    effect = "allow"
    permission_groups = [
      { id = local.cf_perm_dns_write },
      { id = local.cf_perm_zone_read },
    ]
    resources = jsonencode({
      "com.cloudflare.api.account.zone.${var.cloudflare_zone_id}" = "*"
    })
  }]
}
