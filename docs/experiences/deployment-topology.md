# Deployment topology

Status: Lived (as of experience posts through 2026-09-28)

Graphic overview of the computers currently hosting services described in this repository. Network addresses, CIDRs, and private hostnames are intentionally omitted from this public page. Real addresses live in gitignored `docs/inventory.local.md` and `docs/experiences/deployment-topology.local.md`.

## Security

Publishing host roles, public hostnames, and exposure methods already helps reconnaissance. Omitting LAN/Tailscale/public VPS IPs and private hostnames reduces how useful this page is as a targeting map. Do not paste private addressing into this file or into git.

## Diagram

```mermaid
flowchart TB
  subgraph Internet["Internet"]
    Users["Users / clients"]
    CF["Cloudflare Edge<br/>Tunnel + Access"]
  end

  subgraph OVH["OVH VPS — public IPv4"]
    Nginx["Nginx + Certbot"]
    HS["Headscale control plane<br/>headscale.willyrv.com"]
    Kuma["Uptime Kuma<br/>status.willyrv.com"]
    TS_VPS["Tailscale client<br/>probe node"]
  end

  subgraph HomeCGNAT["Home site — IPv4 CGNAT<br/>no inbound port forwards"]
    subgraph HomeLAN["Home LAN"]
      Bridge["Home infrastructure PC<br/>(subnet router)<br/>Tailscale subnet router"]
      OP["OpenProject mini PC<br/>single-node k3s"]
      OPApps["OpenProject + cloudflared"]
    end
  end

  subgraph OtherLAN["Separate LAN — not on Headscale advertised route"]
    GuestA["Teaching GPU host A<br/>single-node k3s + GPU"]
    GuestB["Teaching GPU host B<br/>single-node k3s + GPU"]
    JH1["JupyterHub + cloudflared<br/>jupyter.willyrv.com"]
    JH2["JupyterHub GPU + cloudflared<br/>jupyter2.willyrv.com"]
    N8N["n8n + Postgres + cloudflared<br/>(inferred: host A)"]
    MATOMO["Matomo + MariaDB + cloudflared<br/>webanalytics.willyrv.com"]
  end

  Users --> CF
  Users -->|"HTTPS DNS-only<br/>(grey cloud)"| Nginx
  Nginx --> HS
  Nginx --> Kuma
  HS -.->|"Tailscale / Headscale mesh"| TS_VPS
  HS -.->|"Tailscale / Headscale mesh"| Bridge
  Bridge -->|"advertises home LAN"| OP
  OP --- OPApps
  CF -->|"Tunnel"| OPApps
  CF -->|"Tunnel"| JH1
  CF -->|"Tunnel"| JH2
  CF -->|"Tunnel"| N8N
  CF -->|"Tunnel"| MATOMO
  GuestA --- JH1
  GuestA --- N8N
  GuestA --- MATOMO
  GuestB --- JH2
  Kuma -.->|"monitors Headscale health<br/>+ home bridge on mesh"| HS
  Kuma -.-> Bridge
```

## Hosts and exposure

| Host | Role | Services | How it is reached |
|------|------|----------|-------------------|
| OVH VPS | Public edge + VPN control plane | Nginx/Certbot, Headscale, Uptime Kuma, Tailscale probe | Direct HTTPS on the VPS (Cloudflare **DNS only** for Headscale/status); UDP STUN for embedded DERP; not behind Cloudflare Tunnel |
| Home infrastructure PC (subnet router) | Subnet router into the home LAN | Tailscale client advertising the home LAN | Outbound-only at the ISP edge (CGNAT); joins Headscale; no public inbound ports |
| OpenProject mini PC | App node | Single-node k3s, OpenProject, `cloudflared` | Public: Cloudflare Tunnel + Access → `projects.willyrv.com`. Private: via Headscale through the subnet router (Tailscale need not run on this box) |
| Teaching GPU host A | Compute / teaching node | Single-node k3s, JupyterHub (+ GPU), n8n (inferred), Matomo + MariaDB | Public: Cloudflare Tunnel + Access → `jupyter.willyrv.com`, the n8n Access-protected hostname, and `webanalytics.willyrv.com` (dashboard behind Access; tracker paths public). Not covered by the home LAN Headscale route unless this host joins the mesh or its LAN is advertised |
| Teaching GPU host B | Compute / teaching node | Single-node k3s, JupyterHub (+ GPU), local CuPy image | Public: Cloudflare Tunnel + Access → `jupyter2.willyrv.com`. Same guest-LAN caveat as host A |

## Notes

- **CGNAT:** The home ISP line cannot accept reliable inbound IPv4 port forwards; tunnels and the VPS-hosted Headscale control plane work around that.
- **Headscale vs Tunnel:** Headscale must stay on DNS-only / direct TLS (not Cloudflare Proxy or Tunnel). HTTP apps (OpenProject, JupyterHub, n8n, Matomo) use Tunnel + Access. Matomo’s tracker paths (`/matomo.js`, `/matomo.php`, and the `/piwik.*` aliases) Bypass Access; the dashboard does not.
- **n8n placement:** Experience/design material describes n8n on the high-spec single-node k3s host; that matches teaching GPU host A. Confirm locally if you split clusters later.
- **Canonical write-ups:** [Headscale / CGNAT](2026-07-19-headscale-ovh-cgnat.md), [Uptime Kuma](2026-07-20-uptime-kuma-vpn-monitoring.md), [OpenProject](2026-07-22-openproject-cloudflare-tunnel.md), [JupyterHub](2026-07-22-jupyterhub-cloudflare-tunnel.md), [GPU JupyterHub host B](2026-08-09-jupyterhub-gpu-guest2.md), [n8n](2026-07-31-n8n-k3s-cloudflare.md), [Matomo](2026-09-28-matomo-k3s-cloudflare.md).
