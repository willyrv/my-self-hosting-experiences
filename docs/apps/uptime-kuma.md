# Uptime Kuma

Status: Recommended

## Purpose

[Uptime Kuma](https://github.com/louislam/uptime-kuma) provides lightweight availability checks and alerts for the Headscale remote-access path:

1. **Headscale control plane** — `https://headscale.willyrv.com/health`
2. **Home subnet router** — ping/TCP to the home PC’s Tailscale IP from the OVH VPS

Public UI: `https://status.willyrv.com` (intentional long-term public exposure).

## Placement

Run on the **OVH VPS** with Docker Compose, behind the existing Nginx + Certbot edge (same pattern as Headscale). Do **not** put this stack on Rancher/K3s on a small VPS for v1 — keep it independent of a cluster so alerts still work if Kubernetes is not installed yet.

```text
OVH VPS
├── Nginx :443
│     ├── headscale.willyrv.com → Headscale
│     ├── status.willyrv.com    → Uptime Kuma :3001
│     └── other sites…
├── Tailscale client (probe node)
└── Uptime Kuma (Docker) → pings home Tailscale IP
```

Cloudflare for `status.willyrv.com`: **DNS only** (grey cloud).

## Compose (summary)

Data under Docker volume; bind only to localhost:

```yaml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    restart: unless-stopped
    volumes:
      - uptime-kuma-data:/app/data
    ports:
      - "127.0.0.1:3001:3001"

volumes:
  uptime-kuma-data:
```

If ICMP ping from the container to the Tailscale IP fails, use `network_mode: host` or a **TCP Port** monitor instead of Ping.

Nginx proxies `status.willyrv.com` to `http://127.0.0.1:3001` with WebSocket upgrade headers (same idea as other Node UIs).

## Monitors (validated)

| Name | Type | Target |
|------|------|--------|
| Headscale health | HTTP(s) | `https://headscale.willyrv.com/health` |
| Home bridge | Ping or TCP | Home node Tailscale IP (e.g. `<ts-home-node>`) |

Real Tailscale/LAN addresses live in gitignored `docs/inventory.local.md` and `docs/experiences/deployment-topology.local.md`.

Prerequisites:

- VPS joined to Headscale as a **probe** client (no subnet/exit routes required for the ping check).
- Home PC always online on the tailnet with `<home-lan-cidr>` advertised and approved.

Notifications: ntfy and/or Telegram from the Kuma UI.

## Hardening (public UI)

- Strong unique admin password (no reuse with host/Headscale).
- Include `status.willyrv.com` in [CrowdSec](https://www.crowdsec.net/) / Nginx protection when abuse monitoring is enabled.
- Optionally limit what a public status page shows.
- Back up the Kuma data volume off-box.

## Related abuse monitoring

Alongside Kuma availability checks, the VPS should run:

- **CrowdSec** on Nginx logs for `headscale.willyrv.com` and `status.willyrv.com`
- A **Headscale journal watcher** for auth/registration failure spikes → same alert channel

See the experience note for the bring-up narrative.

## See also

- [Headscale](headscale.md)
- [Monitoring architecture](../architecture/monitoring.md)
- [Phase 4 — low-risk apps](../guides/phase-04-low-risk-apps.md)
- [Experience: Uptime Kuma VPN monitoring](../experiences/2026-07-20-uptime-kuma-vpn-monitoring.md)
- Upstream: https://github.com/louislam/uptime-kuma
