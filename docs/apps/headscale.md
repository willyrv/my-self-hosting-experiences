# Headscale

Status: Recommended

## Purpose

[Headscale](https://headscale.net/) is a self-hosted implementation of the Tailscale control server. This lab uses it for:

- mesh VPN between personal devices (laptop, phone, servers);
- remote access to the home LAN (`192.168.1.0/24`) via a subnet router on the home Ubuntu PC.

Public coordination URL: `https://headscale.willyrv.com`

## Placement (validated)

Domestic ISP lines often use **IPv4 CGNAT**, which blocks inbound port forwarding to a home PC. This lab therefore splits roles:

```text
Internet clients (Tailscale app)
        │
        │  https://headscale.willyrv.com
        ▼
OVH VPS (public IPv4)
├── Nginx :443 (TLS via Certbot)
│     ├── muscle-master.willyrv.com  → static site
│     └── headscale.willyrv.com      → 127.0.0.1:8080 (Headscale)
└── Headscale
      ├── control API (localhost only)
      └── embedded DERP + STUN UDP 3478

Home Ubuntu PC (CGNAT — no inbound ports)
└── Tailscale client
      ├── --login-server=https://headscale.willyrv.com
      └── advertises 192.168.1.0/24 (subnet router)
```

Keep Headscale **outside Kubernetes**. The VPN path must remain usable when the future K3s cluster is down.

Do **not** put Headscale behind Cloudflare Proxy or Tunnel (orange cloud). Use **DNS only** (grey cloud). See [Headscale reverse proxy notes](https://headscale.net/stable/ref/integration/reverse-proxy/).

---

## 1. DNS (Cloudflare)

Create an A record:

| Field | Value |
|-------|--------|
| Type | A |
| Name | `headscale` |
| Content | OVH VPS public IPv4 |
| Proxy | **DNS only** (grey cloud) |

Verify:

```bash
dig +short headscale.willyrv.com A
```

Expected: the VPS IPv4 (not a Cloudflare anycast address).

---

## 2. Headscale on the OVH VPS

Install the official `.deb` from [GitHub releases](https://github.com/juanfont/headscale/releases) if needed ([install docs](https://headscale.net/stable/setup/install/official/)).

Configure `/etc/headscale/config.yaml` for a reverse proxy (keys may vary slightly by version; validated against **v0.29.x**):

```yaml
server_url: https://headscale.willyrv.com

listen_addr: 127.0.0.1:8080
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 127.0.0.1:50443

trusted_proxies:
  - 127.0.0.1/32
  - ::1/128

# TLS terminated by Nginx
tls_letsencrypt_hostname: ""
tls_cert_path: ""
tls_key_path: ""

dns:
  magic_dns: true
  # Must differ from the Headscale hostname domain usage
  base_domain: ts.willyrv.com
  nameservers:
    global:
      - 1.1.1.1
      - 1.0.0.1

derp:
  server:
    enabled: true
    region_id: 999
    region_code: "ovh"
    region_name: "OVH Embedded DERP"
    stun_listen_addr: "0.0.0.0:3478"
    automatically_add_embedded_derp_region: true
  urls:
    - https://controlplane.tailscale.com/derpmap/default
```

```bash
sudo systemctl enable --now headscale
sudo systemctl restart headscale
curl -sS http://127.0.0.1:8080/health; echo
```

### Firewall / STUN

Allow **UDP 3478** on the VPS host firewall (and OVH Network Firewall if enabled):

```bash
# if using ufw
sudo ufw allow 3478/udp comment 'headscale-stun'
sudo ss -ulnp | grep 3478
```

Keep TCP 80/443 open for Nginx/Certbot. Do **not** expose Headscale `:8080` publicly.

---

## 3. Nginx reverse proxy (share :443 with other sites)

This VPS already serves a static site (`muscle-master.willyrv.com`) with Certbot. Add a second vhost for Headscale.

`/etc/nginx/sites-available/headscale`:

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

upstream headscale {
    server 127.0.0.1:8080;
    keepalive 2;
}

server {
    listen 80;
    listen [::]:80;
    server_name headscale.willyrv.com;

    location = /generate_204 {
        return 204;
    }

    location / {
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header True-Client-IP $remote_addr;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        proxy_read_timeout 86400s;
        proxy_pass http://headscale;
    }
}
```

```bash
sudo ln -sf /etc/nginx/sites-available/headscale /etc/nginx/sites-enabled/headscale
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d headscale.willyrv.com
curl -fsS https://headscale.willyrv.com/health; echo
```

WebSocket / Tailscale Control Protocol support is required; the `Upgrade` / `Connection` headers and long `proxy_read_timeout` above matter. Official examples: [Reverse proxy](https://headscale.net/stable/ref/integration/reverse-proxy/).

---

## 4. Users and client enrollment

On the VPS:

```bash
sudo headscale users create willy
sudo headscale users list
sudo headscale preauthkeys create --user USER_ID --reusable --expiration 24h
```

On any client (official Tailscale app):

```bash
sudo tailscale up \
  --login-server=https://headscale.willyrv.com \
  --authkey=YOUR_PREAUTH_KEY
```

Interactive registration also works; approve with `headscale nodes` / auth commands for your version. Never commit preauth keys.

---

## 5. Home PC as subnet router

On the home Ubuntu host (example LAN IP `192.168.1.12`):

1. Prefer **not** running a second public Headscale there (`sudo systemctl disable --now headscale` if it was started earlier).
2. Enable forwarding:

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-headscale-forward.conf
sudo sysctl --system | grep ip_forward
```

3. Join the tailnet and advertise the LAN:

```bash
sudo tailscale up \
  --login-server=https://headscale.willyrv.com \
  --authkey=YOUR_PREAUTH_KEY \
  --advertise-routes=192.168.1.0/24 \
  --accept-dns=false
```

4. On the VPS, approve routes (**Headscale v0.29+** — there is no top-level `headscale routes`):

```bash
sudo headscale nodes list
sudo headscale nodes list-routes
sudo headscale nodes approve-routes --identifier NODE_ID --routes 192.168.1.0/24
sudo headscale nodes list-routes
```

`approve-routes` replaces the approved set for that node.

---

## 6. Remote verification

From a client **outside** the home LAN (mobile data):

```bash
tailscale up --login-server=https://headscale.willyrv.com --accept-routes
tailscale status
ping -c 3 192.168.1.1
```

Expected: home subnet router online; LAN hosts reachable.

---

## Backups and warnings

- Back up `/etc/headscale/`, SQLite DB under `/var/lib/headscale/`, and Nginx/Certbot material off-box (encrypted).
- Do not commit API tokens, preauth keys, or private keys.
- Cloudflare must stay DNS-only for `headscale.willyrv.com`.
- gRPC admin stays on localhost.

## See also

- [Phase 2 — VPN access](../guides/phase-02-vpn-access.md)
- [Networking](../architecture/networking.md)
- [WireGuard](wireguard.md) (alternative / fallback)
- [Experience: Headscale on OVH after CGNAT](../experiences/2026-07-19-headscale-ovh-cgnat.md)
- Upstream: https://headscale.net/
