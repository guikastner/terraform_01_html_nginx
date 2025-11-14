# terraform_01_html_nginx

Infrastructure as code that serves a static `index.html` with nginx inside Docker and publishes it through a Cloudflare Tunnel.

## Prerequisites
- Docker Engine installed with access to the local daemon.
- Cloudflare account with permissions to manage Tunnels and DNS records in the desired zone.
- Existing Cloudflare Tunnel running on this host (installed via `cloudflared tunnel run <tunnel-id>`).
- Terraform >= 1.5.

## Configuring variables
You can provide all variables via `terraform.tfvars` (recommended for simplicity) or keep them in a `.env` file that exports `TF_VAR_*` values before running OpenTofu—pick whichever workflow fits your tooling.

1. Copy `terraform.tfvars.example` to `terraform.tfvars`, fill every field (sensitive Cloudflare values and nginx/tunnel settings) and run `tofu plan`. This file is already gitignored.
2. *(Optional)* Copy `.env.example` to `.env`, fill the same values as `TF_VAR_*`, and load them into the shell with `export $(grep -v '^#' .env | xargs)` or `direnv allow`.

### `terraform.tfvars` fields (required unless noted)
| Variable | Description |
| --- | --- |
| `cloudflare_api_token` | API token with permissions for `Account.Cloudflare Tunnel:Edit` and `Zone.DNS:Edit`. |
| `cloudflare_account_id` | Cloudflare account ID that owns the tunnel. |
| `cloudflare_zone_id` | DNS zone ID where the hostname will reside. |
| `cloudflare_domain` | Fully qualified domain (e.g. `app.example.com`) routed through the tunnel. |
| `cloudflare_tunnel_id` | UUID of the pre-existing Cloudflare Tunnel running on your host (you may paste either the raw UUID or `account_id/uuid`; Terraform extracts just the UUID). |
| `nginx_container_name` | Name used for the nginx container. |
| `nginx_host_port` | Host port mapped to nginx (also used by Cloudflare ingress). |
| `nginx_image` | Docker image for nginx. |
| `tunnel_target_host` | Hostname/IP that Cloudflare should reach (defaults to `127.0.0.1` if omitted). |

**Example `terraform.tfvars`**
```hcl
cloudflare_api_token  = "cf_api_token_here"
cloudflare_account_id = "1234567890abcdef1234567890abcdef"
cloudflare_zone_id    = "abcdef1234567890abcdef1234567890"
cloudflare_domain     = "app.example.com"
cloudflare_tunnel_id  = "11111111-2222-3333-4444-555555555555"

nginx_container_name = "nginx-html"
nginx_host_port      = 8080
nginx_image          = "nginx:1.27-alpine"
tunnel_target_host   = "192.168.0.66"
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
   - Update the Cloudflare tunnel ingress so the hostname maps to `http://<tunnel_target_host>:<nginx_host_port>` (defaults to `127.0.0.1`, but you can point it to `192.168.0.66` or any reachable host IP).
   - Create/ensure a DNS CNAME pointing `cloudflare_domain` to `<cloudflare_tunnel_id>.cfargotunnel.com`.
   - **Reminder:** keep `cloudflared` running on the host; Terraform does not manage the connector.
4. Access the site locally using `http://localhost:<nginx_host_port>` or publicly through the configured hostname.

## Cloudflare reference notes
Use the Cloudflare dashboard (or API) to gather the values required by `terraform.tfvars`:

- **API token**: Go to *My Profile → API Tokens → Create Token* and use the “Edit Cloudflare Tunnel” template. Add Zone-level `DNS:Edit` permission for the zone that hosts `cloudflare_domain`. Copy the generated token once.
- **Account ID**: In the dashboard, open any zone under the same account and look at the right-hand sidebar (it lists “Account ID”). You can also read it from the URL (`/dash/accounts/<account_id>/`).
- **Zone ID**: Inside the DNS tab of the desired domain, the sidebar shows “Zone ID”. Copy the 32-character hex string.
- **Tunnel ID**: Navigate to *Zero Trust → Networks → Tunnels* (or `https://dash.cloudflare.com/<account>/networking/tunnels`). Select the tunnel that runs on this host and copy the UUID shown in the details panel. You may use the raw UUID or the `account_id/uuid` format; Terraform extracts the UUID automatically.
- **Hostname**: `cloudflare_domain` must already exist as a DNS name inside the zone above; Terraform will create/update the CNAME, but if you need SSL or proxy-specific settings, configure them in Cloudflare as usual.
