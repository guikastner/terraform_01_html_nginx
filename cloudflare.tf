provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

locals {
  provided_tunnel_value    = trimspace(coalesce(var.cloudflare_tunnel_id, ""))
  provided_tunnel_segments = local.provided_tunnel_value == "" ? [] : split("/", local.provided_tunnel_value)
  provided_tunnel_uuid     = local.provided_tunnel_value == "" ? null : local.provided_tunnel_segments[length(local.provided_tunnel_segments) - 1]
}

resource "random_id" "cloudflare_tunnel_secret" {
  count       = var.cloudflare_manage_tunnel ? 1 : 0
  byte_length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "nginx" {
  count      = var.cloudflare_manage_tunnel ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = var.cloudflare_managed_tunnel_name
  config_src = "cloudflare"
  secret     = random_id.cloudflare_tunnel_secret[0].b64_std
}

locals {
  managed_tunnel_uuid = var.cloudflare_manage_tunnel ? cloudflare_zero_trust_tunnel_cloudflared.nginx[0].id : null
  tunnel_uuid         = coalesce(local.managed_tunnel_uuid, local.provided_tunnel_uuid)

  origin_service_host = var.cloudflare_manage_tunnel ? var.nginx_container_name : var.tunnel_target_host
  origin_service_port = var.cloudflare_manage_tunnel ? 80 : var.nginx_host_port
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
  tunnel_id  = local.tunnel_uuid

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
  content         = var.cloudflare_manage_tunnel ? cloudflare_zero_trust_tunnel_cloudflared.nginx[0].cname : "${local.tunnel_uuid}.cfargotunnel.com"
}

output "cloudflare_hostname" {
  description = "Public hostname routed through Cloudflare Tunnel."
  value       = var.cloudflare_domain
}

output "cloudflare_tunnel_id" {
  description = "UUID of the Cloudflare Tunnel currently managed or referenced by this module."
  value       = local.tunnel_uuid
}
