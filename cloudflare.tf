provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

locals {
  tunnel_id_segments = split("/", trimspace(var.cloudflare_tunnel_id))
  tunnel_uuid        = local.tunnel_id_segments[length(local.tunnel_id_segments) - 1]
}

resource "cloudflare_tunnel_config" "nginx" {
  account_id = var.cloudflare_account_id
  tunnel_id  = local.tunnel_uuid

  config {
    ingress_rule {
      hostname = var.cloudflare_domain
      service  = "http://127.0.0.1:${var.nginx_host_port}"
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "tunnel_cname" {
  zone_id          = var.cloudflare_zone_id
  name             = var.cloudflare_domain
  type             = "CNAME"
  ttl              = 1
  proxied          = true
  allow_overwrite  = true
  value            = "${local.tunnel_uuid}.cfargotunnel.com"
}

output "cloudflare_hostname" {
  description = "Public hostname routed through Cloudflare Tunnel."
  value       = var.cloudflare_domain
}
