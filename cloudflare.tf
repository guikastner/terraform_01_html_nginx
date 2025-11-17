provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "random_id" "cloudflare_tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "nginx" {
  account_id = var.cloudflare_account_id
  name       = var.cloudflare_managed_tunnel_name
  config_src = "cloudflare"
  secret     = random_id.cloudflare_tunnel_secret.b64_std
}

locals {
  origin_service_host = var.nginx_container_name
  origin_service_port = 80
}

locals {
  base_ingress_rule = {
    hostname = var.cloudflare_domain
    service  = "http://${local.origin_service_host}:${local.origin_service_port}"
    path     = null
  }

  additional_ingress_rules = [
    for rule in var.cloudflare_additional_tunnel_ingress : merge(
      {
        hostname = null
        path     = null
      },
      rule
    )
  ]

  additional_catch_all_rules = [
    for rule in local.additional_ingress_rules : rule
    if trimspace(coalesce(rule.hostname, "")) == "" && rule.path == null
  ]

  additional_hostname_rules = [
    for rule in local.additional_ingress_rules : rule
    if !(trimspace(coalesce(rule.hostname, "")) == "" && rule.path == null)
  ]

  additional_hostname_rule_keys = [
    for rule in local.additional_hostname_rules :
    "${lower(trimspace(coalesce(rule.hostname, "")))}|${coalesce(rule.path, "")}"
  ]

  fallback_catch_all_rules = length(local.additional_catch_all_rules) > 0 ? [] : [
    {
      hostname = null
      path     = null
      service  = coalesce(var.cloudflare_catch_all_ingress_service, "http://${local.origin_service_host}:${local.origin_service_port}")
    }
  ]

  managed_catch_all_rules = (
    length(local.additional_catch_all_rules) > 0 ? local.additional_catch_all_rules : local.fallback_catch_all_rules
  )

  managed_ingress_rules = concat(
    [local.base_ingress_rule],
    local.additional_hostname_rules,
    local.managed_catch_all_rules
  )
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "nginx" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.nginx.id

  config {
    dynamic "ingress_rule" {
      for_each = local.managed_ingress_rules
      content {
        hostname = ingress_rule.value.hostname
        service  = ingress_rule.value.service
        path     = ingress_rule.value.path
      }
    }
  }
}

resource "cloudflare_record" "tunnel_cname" {
  zone_id         = var.cloudflare_zone_id
  name            = var.cloudflare_domain
  type            = "CNAME"
  ttl             = 1
  proxied         = true
  allow_overwrite = true
  content         = cloudflare_zero_trust_tunnel_cloudflared.nginx.cname
}

output "cloudflare_hostname" {
  description = "Public hostname routed through Cloudflare Tunnel."
  value       = var.cloudflare_domain
}

output "cloudflare_tunnel_id" {
  description = "UUID of the Cloudflare Tunnel currently managed or referenced by this module."
  value       = cloudflare_zero_trust_tunnel_cloudflared.nginx.id
}
