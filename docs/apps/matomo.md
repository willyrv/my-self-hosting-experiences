# Matomo

Status: Planned

## Purpose

[Matomo](https://matomo.org/) On-Premise is an open-source Google Analytics alternative (GPL-3.0). This lab will use it for public and personal websites (`willyrv.com`, blogs, docs). Data stays on the cluster. Paid plugins (heatmaps, session recordings) are out of scope for v1.

## Placement (intended)

| Role | Where |
|------|--------|
| k3s + Matomo + MariaDB | Teaching GPU host A (same single-node cluster as JupyterHub and n8n) |
| Public HTTPS | Cloudflare Tunnel → `https://webanalytics.willyrv.com` |
| Dashboard | Cloudflare Access (email) **and** Matomo login |
| Tracking (`/matomo.js`, `/matomo.php`) | Public (Access Bypass). Do not enable Tunnel **Protect with Access**. |

## Manual install

Run the commands yourself on host A:

**[Guide — Matomo on k3s + Cloudflare Tunnel](../guides/matomo-k3s-cloudflare.md)**

## See also

- Design: [2026-09-14-matomo-k3s-cloudflare-design.md](../superpowers/specs/2026-09-14-matomo-k3s-cloudflare-design.md)
- Plan: [2026-09-14-matomo-k3s-cloudflare.md](../superpowers/plans/2026-09-14-matomo-k3s-cloudflare.md)
- [Networking](../architecture/networking.md)
- Upstream: https://matomo.org/matomo-on-premise/
