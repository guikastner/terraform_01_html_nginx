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

variable "cloudflare_managed_tunnel_name" {
  description = "Name assigned to the Cloudflare Tunnel resource managed by this module."
  type        = string
  default     = "nginx-html-tunnel"
}

variable "nginx_container_name" {
  description = "Name for the Docker container running nginx."
  type        = string
  default     = "nginx-html"
}

variable "nginx_image" {
  description = "Docker image for nginx."
  type        = string
  default     = "nginx:1.27-alpine"
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
