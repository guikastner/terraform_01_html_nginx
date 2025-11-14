# terraform_01_html_nginx

Infrastructure as code that serves a static `index.html` with nginx inside Docker and publishes it through a Cloudflare Tunnel.

## Prerequisites
- Docker Engine installed with access to the local daemon.
- Cloudflare account with permissions to manage Tunnels and DNS records in the desired zone.
- Existing Cloudflare Tunnel running on this host (installed via `cloudflared tunnel run <tunnel-id>`).
- Terraform >= 1.5.

## Configuring variables
1. Copy `.env.example` to `.env`, fill in the sensitive values, then load them into your shell with `export $(grep -v '^#' .env | xargs)` (or rely on `direnv`). Terraform automatically reads any variable prefixed with `TF_VAR_`.
2. Copy `terraform.tfvars.example` to `terraform.tfvars` and update the optional parameters as needed.

### `.env` variables
| Variable | Description |
| --- | --- |
| `TF_VAR_cloudflare_api_token` | API token with permissions for `Account.Cloudflare Tunnel:Edit` and `Zone.DNS:Edit`. |
| `TF_VAR_cloudflare_account_id` | Cloudflare account ID that owns the tunnel. |
| `TF_VAR_cloudflare_zone_id` | DNS zone ID where the hostname will reside. |
| `TF_VAR_cloudflare_domain` | Fully qualified domain (e.g. `app.example.com`) routed through the tunnel. |
| `TF_VAR_cloudflare_tunnel_id` | UUID of the pre-existing Cloudflare Tunnel running on your host (you may paste either the raw UUID or `account_id/uuid`; Terraform will extract the UUID automatically). |

**Example `.env`**
```env
TF_VAR_cloudflare_api_token="cf_api_token_here"
TF_VAR_cloudflare_account_id="1234567890abcdef1234567890abcdef"
TF_VAR_cloudflare_zone_id="abcdef1234567890abcdef1234567890"
TF_VAR_cloudflare_domain="app.example.com"
TF_VAR_cloudflare_tunnel_id="11111111-2222-3333-4444-555555555555"
```

### `terraform.tfvars` values
| Variable | Description |
| --- | --- |
| `nginx_container_name` | Name used for the nginx container. |
| `nginx_host_port` | Local port exposed for debugging. |
| `nginx_image` | Docker image for nginx. |

**Example `terraform.tfvars`**
```hcl
nginx_container_name   = "nginx-html"
nginx_host_port        = 8080
nginx_image            = "nginx:1.27-alpine"
```

## Deployment steps
1. Customize `index.html` if you need different content—it is uploaded to `/usr/share/nginx/html/index.html` inside the container.
2. Run `terraform init` to download the Docker and Cloudflare providers.
3. Execute `terraform apply` and confirm the plan. Terraform will:
   - Pull the nginx image, start the container with your HTML, and expose the configured port.
   - Update the Cloudflare tunnel ingress so the hostname maps to `http://127.0.0.1:<nginx_host_port>` (the Docker-published port).
   - Create/ensure a DNS CNAME pointing `cloudflare_domain` to `<cloudflare_tunnel_id>.cfargotunnel.com`.
   - **Reminder:** keep `cloudflared` running on the host; Terraform does not manage the connector.
4. Access the site locally using `http://localhost:<nginx_host_port>` or publicly through the configured hostname.
