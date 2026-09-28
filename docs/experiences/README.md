# Experiences log

Dated notes from building and operating this self-hosting lab.

## Deployment topology

See [deployment topology](deployment-topology.md) for a Mermaid overview of the PCs, services, and how they are exposed (Cloudflare Tunnel, Headscale on OVH, etc.).

That public page **omits IPs, CIDRs, and private hostnames** on purpose. Real addresses live in gitignored `docs/inventory.local.md` and `docs/experiences/deployment-topology.local.md`.

## Conventions

- One file per entry: `YYYY-MM-DD-short-slug.md`
- First-person is fine
- Record what you tried, what failed, and what you decided
- When a decision becomes lasting policy, update the canonical docs under `architecture/`, `guides/`, or `apps/`, and link both ways

## Entries

- [2026-09-28 — Matomo on single-node k3s with Cloudflare Tunnel](2026-09-28-matomo-k3s-cloudflare.md)
- [2026-08-09 — GPU JupyterHub on teaching GPU host B (discrete NVIDIA GPU + local CuPy)](2026-08-09-jupyterhub-gpu-guest2.md)
- [2026-07-31 — n8n on single-node K3s with Cloudflare Tunnel](2026-07-31-n8n-k3s-cloudflare.md)
- [2026-07-22 — JupyterHub teaching stack + Cloudflare Tunnel (+ GPU)](2026-07-22-jupyterhub-cloudflare-tunnel.md)
- [2026-07-22 — OpenProject on k3s + Cloudflare Tunnel](2026-07-22-openproject-cloudflare-tunnel.md)
- [2026-07-20 — Uptime Kuma VPN monitoring](2026-07-20-uptime-kuma-vpn-monitoring.md)
- [2026-07-19 — Headscale on OVH after CGNAT](2026-07-19-headscale-ovh-cgnat.md)
- [2026-07-18 — Architecture decision: hybrid K3s](2026-07-18-architecture-decision.md)
