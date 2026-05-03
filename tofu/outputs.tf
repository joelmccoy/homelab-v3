output "kubeconfig" {
  description = "Generated kubeconfig (raw)."
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
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
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}

output "cloudflare_tunnel_token" {
  description = "Connector token consumed by cloudflared (TUNNEL_TOKEN env var)."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.homelab.token
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
