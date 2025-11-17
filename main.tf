terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.29"
    }

  }
}

provider "docker" {}

resource "docker_network" "nginx" {
  name = "${var.nginx_container_name}-net"
}

locals {
  html_content = file("${path.module}/index.html")
}

resource "docker_image" "nginx" {
  name         = var.nginx_image
  keep_locally = true
}

resource "docker_container" "nginx" {
  name  = var.nginx_container_name
  image = docker_image.nginx.image_id

  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.nginx.name
    aliases = [var.nginx_container_name]
  }

  ports {
    internal = 80
    external = var.nginx_host_port
    protocol = "tcp"
  }

  upload {
    content = local.html_content
    file    = "/usr/share/nginx/html/index.html"
  }
}

resource "docker_image" "cloudflared" {
  count        = var.cloudflare_manage_tunnel ? 1 : 0
  name         = var.cloudflared_image
  keep_locally = true
}

resource "docker_container" "cloudflared" {
  count = var.cloudflare_manage_tunnel ? 1 : 0

  name  = var.cloudflared_container_name
  image = docker_image.cloudflared[0].image_id

  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.nginx.name
  }

  command = [
    "tunnel",
    "--no-autoupdate",
    "run",
    "--token",
    cloudflare_zero_trust_tunnel_cloudflared.nginx[0].tunnel_token
  ]

  depends_on = [
    cloudflare_zero_trust_tunnel_cloudflared_config.nginx
  ]
}

output "nginx_local_url" {
  description = "Local URL that serves the Hello World page."
  value       = "http://localhost:${var.nginx_host_port}"
}
