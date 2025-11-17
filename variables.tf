variable "cloudflare_api_token" {
  description = "API token with permissions to manage Tunnels and DNS records in the selected zone."
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID that owns the Argo Tunnel."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID where the DNS record will be created."
  type        = string
}

variable "cloudflare_domain" {
  description = "Fully qualified domain (ex: app.example.com) that will route to the tunnel."
  type        = string
}

variable "cloudflare_subdomain" {
  description = "Subdomain (host label only) that will be created under cloudflare_domain. Leave empty to target the apex record."
  type        = string
  default     = ""
}

variable "cloudflare_manage_tunnel" {
  description = "When true, this module creates its own Cloudflare Tunnel and cloudflared connector container. Set to false to reuse an existing tunnel_id."
  type        = bool
  default     = true
}

variable "cloudflare_tunnel_id" {
  description = "Existing Cloudflare Tunnel ID (UUID or account_id/uuid). Required when cloudflare_manage_tunnel is false."
  type        = string
  default     = null

  validation {
    condition     = var.cloudflare_manage_tunnel || length(trimspace(coalesce(var.cloudflare_tunnel_id, ""))) > 0
    error_message = "Set cloudflare_tunnel_id when cloudflare_manage_tunnel is false."
  }
}

variable "cloudflare_managed_tunnel_name" {
  description = "Name assigned to the Cloudflare Tunnel resource when cloudflare_manage_tunnel is true."
  type        = string
  default     = "nginx-html-tunnel"
}

variable "nginx_container_name" {
  description = "Name for the Docker container running nginx."
  type        = string
  default     = "nginx-html"
}

variable "nginx_host_port" {
  description = "Local host port exposed by nginx for debugging."
  type        = number
  default     = 8080
}

variable "nginx_image" {
  description = "Docker image for nginx."
  type        = string
  default     = "nginx:1.27-alpine"
}

variable "tunnel_target_host" {
  description = "Hostname or IP that the Cloudflare Tunnel should reach (where nginx listens)."
  type        = string
  default     = "127.0.0.1"
}

variable "cloudflare_additional_tunnel_ingress" {
  description = "List of additional Cloudflare Tunnel ingress rules that must remain alongside the nginx rule managed by this module."
  type = list(object({
    hostname = string
    service  = string
    path     = optional(string)
  }))
  default = []
}

variable "cloudflare_catch_all_ingress_service" {
  description = "Service string used for the fallback ingress rule (no hostname/path) when you are not passing an explicit catch-all rule via cloudflare_additional_tunnel_ingress."
  type        = string
  default     = null
}

variable "cloudflared_container_name" {
  description = "Docker container name for the cloudflared connector that keeps the managed tunnel online."
  type        = string
  default     = "cloudflared-nginx"
}

variable "cloudflared_image" {
  description = "Docker image for the cloudflared connector."
  type        = string
  default     = "cloudflare/cloudflared:latest"
}
