# Deployment topology

Status: Lived (as of experience posts through 2026-07-31)

Graphic overview of the computers currently hosting services described in this repository. Network addresses and CIDRs are intentionally omitted from this public page; a local companion with that detail may exist on the operator machine as `deployment-topology.local.md` (gitignored).

## Security

Publishing host roles, public hostnames, and exposure methods already helps reconnaissance. Omitting LAN/Tailscale/public VPS IPs reduces how useful this page is as a targeting map. Do not paste private addressing into this file or into git.

## Diagram

```mermaid
flowchart TB
  subgraph Internet["Internet"]
    Users["Users / clients"]
    CF["Cloudflare Edge<br/>Tunnel + Access"]
  end

  subgraph OVH["OVH VPS — public IPv4"]
    Nginx["Nginx + Certbot"]
    Static["Static site<br/>muscle-master.willyrv.com"]
    HS["Headscale control plane<br/>headscale.willyrv.com"]
    Kuma["Uptime Kuma<br/>status.willyrv.com"]
    TS_VPS["Tailscale client<br/>probe node"]
  end

  subgraph HomeCGNAT["Home site — IPv4 CGNAT<br/>no inbound port forwards"]
    subgraph HomeLAN["Home LAN"]
      Bridge["Infrastructure PC<br/>nuc2-ingress<br/>Tailscale subnet router"]
      OP["OpenProject mini PC<br/>single-node k3s"]
      OPApps["OpenProject + cloudflared"]
    end
  end

  subgraph OtherLAN["Separate LAN — not on Headscale advertised route"]
    Guest["GUEST1<br/>single-node k3s + GPU"]
    JH["JupyterHub + cloudflared"]
    N8N["n8n + Postgres + cloudflared<br/>(inferred: same host)"]
  end

  Users --> CF
  Users -->|"HTTPS DNS-only<br/>(grey cloud)"| Nginx
  Nginx --> Static
  Nginx --> HS
  Nginx --> Kuma
  HS -.->|"Tailscale / Headscale mesh"| TS_VPS
  HS -.->|"Tailscale / Headscale mesh"| Bridge
  Bridge -->|"advertises home LAN"| OP
  OP --- OPApps
  CF -->|"Tunnel"| OPApps
  CF -->|"Tunnel"| JH
  CF -->|"Tunnel"| N8N
  Guest --- JH
  Guest --- N8N
  Kuma -.->|"monitors Headscale health<br/>+ home bridge on mesh"| HS
  Kuma -.-> Bridge
```

## Hosts and exposure

| Host | Role | Services | How it is reached |
|------|------|----------|-------------------|
| OVH VPS | Public edge + VPN control plane | Nginx/Certbot, static site, Headscale, Uptime Kuma, Tailscale probe | Direct HTTPS on the VPS (Cloudflare **DNS only** for Headscale/status); UDP STUN for embedded DERP; not behind Cloudflare Tunnel |
| Home infrastructure PC (`nuc2-ingress`) | Subnet router into the home LAN | Tailscale client advertising the home LAN | Outbound-only at the ISP edge (CGNAT); joins Headscale; no public inbound ports |
| OpenProject mini PC | App node | Single-node k3s, OpenProject, `cloudflared` | Public: Cloudflare Tunnel + Access → `projects.willyrv.com`. Private: via Headscale through the subnet router (Tailscale need not run on this box) |
| GUEST1 | Compute / teaching node | Single-node k3s, JupyterHub (+ GPU), n8n (inferred) | Public: Cloudflare Tunnel + Access → `jupyter.willyrv.com` and the n8n Access-protected hostname. Not covered by the home LAN Headscale route unless this host joins the mesh or its LAN is advertised |

## Notes

- **CGNAT:** The home ISP line cannot accept reliable inbound IPv4 port forwards; tunnels and the VPS-hosted Headscale control plane work around that.
- **Headscale vs Tunnel:** Headscale must stay on DNS-only / direct TLS (not Cloudflare Proxy or Tunnel). HTTP apps (OpenProject, JupyterHub, n8n) use Tunnel + Access.
- **n8n placement:** Experience/design material describes n8n on the high-spec single-node k3s host; that matches GUEST1. Confirm locally if you split clusters later.
- **Canonical write-ups:** [Headscale / CGNAT](2026-07-19-headscale-ovh-cgnat.md), [Uptime Kuma](2026-07-20-uptime-kuma-vpn-monitoring.md), [OpenProject](2026-07-22-openproject-cloudflare-tunnel.md), [JupyterHub](2026-07-22-jupyterhub-cloudflare-tunnel.md), [n8n](2026-07-31-n8n-k3s-cloudflare.md).
