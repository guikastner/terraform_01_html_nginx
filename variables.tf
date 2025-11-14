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

variable "cloudflare_tunnel_id" {
  description = "Existing Cloudflare Tunnel ID (UUID) running on your host."
  type        = string
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
