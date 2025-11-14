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

output "nginx_local_url" {
  description = "Local URL that serves the Hello World page."
  value       = "http://localhost:${var.nginx_host_port}"
}
