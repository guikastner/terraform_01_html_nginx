# terraform_01_html_nginx

Infrastructure as code that serves a static `index.html` with nginx inside Docker and publishes it through a Cloudflare Tunnel.

## Prerequisites
- Docker Engine installed with access to the local daemon.
- Cloudflare account with permissions to manage Tunnels and DNS records in the desired zone.
- Terraform >= 1.5.
- *(Optional)* If you disable the managed tunnel (`cloudflare_manage_tunnel = false`), make sure another host/container is already running `cloudflared tunnel run <your-tunnel-id>` so Cloudflare keeps the tunnel online.

## Configuring variables
You can provide all variables via `terraform.tfvars` (recommended for simplicity) or keep them in a `.env` file that exports `TF_VAR_*` values before running OpenTofu—pick whichever workflow fits your tooling. All examples and testing were developed with OpenTofu v1.10.0; Terraform 1.5+ should behave the same, but stick with the OpenTofu version above if you want an identical experience.

1. Copy `terraform.tfvars.example` to `terraform.tfvars`, fill every field (sensitive Cloudflare values and nginx/tunnel settings) and run `tofu plan`. This file is already gitignored.
2. *(Optional)* Copy `.env.example` to `.env`, fill the same values as `TF_VAR_*`, and load them into the shell with `export $(grep -v '^#' .env | xargs)` or `direnv allow`.

### `terraform.tfvars` fields (required unless noted)
| Variable | Description |
| --- | --- |
| `cloudflare_api_token` | API token with permissions for `Account.Cloudflare Tunnel:Edit` and `Zone.DNS:Edit`. |
| `cloudflare_account_id` | Cloudflare account ID that owns the tunnel. |
| `cloudflare_zone_id` | DNS zone ID where the hostname will reside. |
| `cloudflare_domain` | Fully qualified domain (e.g. `app.example.com`) routed through the tunnel. |
| `cloudflare_manage_tunnel` | When `true` (default) this module creates its own Cloudflare Tunnel plus a `cloudflared` connector container. Set to `false` if you want to reuse an existing tunnel. |
| `cloudflare_tunnel_id` | UUID (or `account_id/uuid`) of a pre-existing Cloudflare Tunnel. Required only when `cloudflare_manage_tunnel = false`. |
| `cloudflare_managed_tunnel_name` | Friendly name applied to the managed Cloudflare Tunnel (only used when `cloudflare_manage_tunnel = true`). |
| `nginx_container_name` | Name used for the nginx container. |
| `nginx_host_port` | Host port mapped to nginx (also used by Cloudflare ingress). |
| `nginx_image` | Docker image for nginx. |
| `tunnel_target_host` | Hostname/IP that Cloudflare should reach (defaults to `127.0.0.1` if omitted). When the module manages its own tunnel it points directly at the nginx container; otherwise this value is used as-is. |
| `cloudflare_additional_tunnel_ingress` | (Optional) List of other ingress rules that must remain in the same tunnel. Each item needs `hostname`/`service` and an optional `path`. When you reuse a tunnel (`cloudflare_manage_tunnel = false`), specify *all* hostnames/paths that should continue to exist or Terraform will remove them. |
| `cloudflare_catch_all_ingress_service` | (Optional) Service string used for the implicit “match everything else” ingress rule when you are not listing one through `cloudflare_additional_tunnel_ingress`. Defaults to the nginx service, but you can point it to any connector-reachable endpoint. |
| `cloudflared_container_name` | Docker container name for the Cloudflare connector that keeps the managed tunnel alive. |
| `cloudflared_image` | Docker image tag for the connector (defaults to `cloudflare/cloudflared:latest`; pin it to a specific version if you need reproducible builds). |

**Example `terraform.tfvars`**
```hcl
cloudflare_api_token  = "cf_api_token_here"
cloudflare_account_id = "1234567890abcdef1234567890abcdef"
cloudflare_zone_id    = "abcdef1234567890abcdef1234567890"
cloudflare_domain     = "app.example.com"

nginx_container_name = "nginx-html"
nginx_host_port      = 8080
nginx_image          = "nginx:1.27-alpine"
tunnel_target_host   = "192.168.0.66"

# Let this module manage a dedicated tunnel + connector (default behavior)
cloudflare_manage_tunnel     = true
cloudflare_managed_tunnel_name = "nginx-html-tunnel"
cloudflared_container_name   = "cloudflared-nginx"
cloudflared_image            = "cloudflare/cloudflared:latest"

# Use nginx as the default catch-all route (set any service you prefer)
cloudflare_catch_all_ingress_service = "http://192.168.0.66:8080"

# Preserve two existing routes managed elsewhere
cloudflare_additional_tunnel_ingress = [
  {
    hostname = "api.example.com"
    service  = "http://127.0.0.1:5000"
  },
  {
    hostname = "grafana.example.com"
    service  = "http://192.168.0.50:3000"
    path     = "/metrics"
  }
]

# If you need to reuse a tunnel that already exists, switch:
# cloudflare_manage_tunnel = false
# cloudflare_tunnel_id     = "account_id/uuid-or-plain-uuid"
```

### Optional `.env`
If you prefer environment variables, keep `.env` (same keys as above but prefixed with `TF_VAR_`) and run:

```bash
export $(grep -v '^#' .env | xargs)
```

## Deployment steps
1. Customize `index.html` if you need different content—it is uploaded to `/usr/share/nginx/html/index.html` inside the container.
2. Run `terraform init` to download the Docker and Cloudflare providers.
3. Execute `terraform apply` and confirm the plan. Terraform will:
   - Pull the nginx image, start the container with your HTML, and expose the configured port.
   - Create (or reuse) the Cloudflare Tunnel, apply the ingress rules for `cloudflare_domain`, and add any extra entries you define via `cloudflare_additional_tunnel_ingress`. When you point to an existing tunnel, make sure the list contains every hostname/path you want to keep so Terraform doesn’t delete them. Cloudflare requires that the final ingress rule matches every request, so this module injects a catch-all rule using `cloudflare_catch_all_ingress_service` (default: the nginx service) whenever you are not already providing one.
   - Create/ensure a DNS CNAME pointing `cloudflare_domain` to `<cloudflare_tunnel_id>.cfargotunnel.com`.
   - When `cloudflare_manage_tunnel = true`, download the `cloudflared` image and launch a dedicated container that runs `cloudflared tunnel --no-autoupdate run --token <tunnel-token>` on the same Docker network as nginx.
   - **Reminder:** whether you run the packaged container or manage your own connector, the tunnel only stays up while `cloudflared` is running with a valid token.
4. Access the site locally using `http://localhost:<nginx_host_port>` or publicly through the configured hostname.

### Managed Cloudflare tunnel & connector
By default the module creates its own Cloudflare Tunnel, retrieves the tunnel token, and launches a `cloudflare/cloudflared` container on a private Docker network shared with nginx using `tunnel --no-autoupdate run --token <token>`. Adjust `cloudflare_managed_tunnel_name`, `cloudflared_container_name`, or `cloudflared_image` to match your naming standards. The token itself never lands on disk—Terraform feeds it directly to the container command.

If you need to reuse an existing tunnel (maybe another Terraform project already owns it), set `cloudflare_manage_tunnel = false` and fill `cloudflare_tunnel_id` with the UUID (or `account_id/uuid`). In that mode, this module stops creating the connector container and assumes some other process keeps the tunnel online.

### Keeping other Cloudflare routes intact
Cloudflare treats each tunnel config as a single document—Terraform only knows about the hostnames you declare here. When reusing an existing tunnel, feed every hostname/path that must remain into `cloudflare_additional_tunnel_ingress` (you can source the list from other state files or data sources). Otherwise, Cloudflare will drop the missing entries when this module writes the new config. When you omit a custom catch-all entry, the module automatically appends one using `cloudflare_catch_all_ingress_service`; set it to your preferred fallback service or supply an explicit catch-all object (without hostname/path) in `cloudflare_additional_tunnel_ingress` if another app should handle unmatched requests.

## Cloudflare reference notes
Use the Cloudflare dashboard (or API) to gather the values required by `terraform.tfvars`:

- **API token**: Go to *My Profile → API Tokens → Create Token* and use the “Edit Cloudflare Tunnel” template. Add Zone-level `DNS:Edit` permission for the zone that hosts `cloudflare_domain`. Copy the generated token once.
- **Account ID**: In the dashboard, open any zone under the same account and look at the right-hand sidebar (it lists “Account ID”). You can also read it from the URL (`/dash/accounts/<account_id>/`).
- **Zone ID**: Inside the DNS tab of the desired domain, the sidebar shows “Zone ID”. Copy the 32-character hex string.
- **Tunnel ID**: Navigate to *Zero Trust → Networks → Tunnels* (or `https://dash.cloudflare.com/<account>/networking/tunnels`). Select the tunnel that runs on this host and copy the UUID shown in the details panel. You may use the raw UUID or the `account_id/uuid` format; Terraform extracts the UUID automatically.
- **Hostname**: `cloudflare_domain` must already exist as a DNS name inside the zone above; Terraform will create/update the CNAME, but if you need SSL or proxy-specific settings, configure them in Cloudflare as usual.
