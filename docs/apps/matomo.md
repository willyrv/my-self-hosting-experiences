# Matomo

Status: Implemented (single-node k3s, 2026-09-28)

## Purpose

[Matomo](https://matomo.org/) On-Premise is an open-source Google Analytics alternative (GPL-3.0). This lab uses it for public and personal websites (`willyrv.com`, blogs, docs). Data stays on the cluster. Paid plugins (heatmaps, session recordings) are out of scope for v1.

## Placement

| Role | Where |
|------|--------|
| k3s + Matomo + MariaDB | Teaching GPU host A (same single-node cluster as JupyterHub and n8n) |
| Public HTTPS | Cloudflare Tunnel → `https://webanalytics.willyrv.com` |
| Dashboard | Cloudflare Access (email) **and** Matomo login |
| Tracking (`/matomo.js`, `/matomo.php`, `/piwik.js`, `/piwik.php`) | Public (Access Bypass). Do not enable Tunnel **Protect with Access**. |

```text
Public sites  →  /matomo.js and /matomo.php   →  Cloudflare  (no Access login)
You           →  dashboard at /               →  Cloudflare Access  →  Matomo login
                     │
                     ▼
              Tunnel (outbound from host A)
                     │
              k3s namespace matomo
              ├── matomo (official image, port 80, PVC /var/www/html)
              ├── matomo-mariadb (official image, port 3306)
              ├── matomo-archive CronJob (or same-pod sidecar if the volume is in use)
              └── cloudflared
```

| Piece | Choice |
|-------|--------|
| Namespace | `matomo` |
| App | Official `matomo:5-apache` |
| Database | Official `mariadb:11`, Service `matomo-mariadb` |
| Storage | Default StorageClass (often `local-path`); MariaDB PVC plus `matomo-html` at `/var/www/html` |
| Archive | `php /var/www/html/console core:archive` on the same app volume; browser archiving off |
| Tunnel | Dedicated `cloudflared` Deployment, HTTP to `matomo.matomo.svc.cluster.local:80` |
| Secrets | Kubernetes Secrets and `~/secrets/` on the host (not in git) |

Do **not** publish Matomo or MariaDB via NodePort / host ports. Public HTTPS terminates at Cloudflare.

## Install

Copy-paste runbook (commands, Access apps, wizard, archive, backup):

**[Guide — Matomo on k3s + Cloudflare Tunnel](../guides/matomo-k3s-cloudflare.md)**

Lived notes from the 2026-09-28 install: [experience](../experiences/2026-09-28-matomo-k3s-cloudflare.md).

## See also

- Design: [2026-09-14-matomo-k3s-cloudflare-design.md](../superpowers/specs/2026-09-14-matomo-k3s-cloudflare-design.md)
- Plan: [2026-09-14-matomo-k3s-cloudflare.md](../superpowers/plans/2026-09-14-matomo-k3s-cloudflare.md)
- [Networking](../architecture/networking.md)
- Upstream install: https://matomo.org/faq/how-to-install/install-matomo-with-docker/
- Upstream product: https://matomo.org/matomo-on-premise/
