# Matomo on single-node K3s with Cloudflare Tunnel — design

Date: 2026-09-14  
Status: Approved for planning

## Purpose

Self-host [Matomo](https://matomo.org/) On-Premise as an open-source Google Analytics alternative for **public and personal websites** (blogs, docs, `willyrv.com`). Run it on teaching GPU host A’s existing single-node K3s cluster. Publish `https://webanalytics.willyrv.com` through Cloudflare Tunnel. Protect the dashboard with Cloudflare Access (allowlisted email) plus Matomo’s own login. Leave tracking endpoints publicly reachable so site snippets can record visits without an Access session.

This extends the hybrid K3s handbook with a second Tunnel-backed app that needs a **split gate**: anonymous tracking vs authenticated UI.

## Goals

- Run Matomo on the already-installed single-node K3s cluster on teaching GPU host A.
- Use MariaDB in-cluster for analytics data (MySQL-compatible; **not** PostgreSQL).
- Expose one hostname via Cloudflare Tunnel (no inbound ports on the PC; home ISP remains CGNAT).
- Restrict the dashboard with Cloudflare Access (allowlisted emails) **and** Matomo login.
- Leave tracking paths public: `/matomo.php`, `/matomo.js`, `/piwik.php`, `/piwik.js`.
- Use official `matomo` and `mariadb` images (pinned tags at install time), plus a Kubernetes CronJob for `core:archive`.
- Keep `cloudflared` as a small hand-written Deployment in the same namespace.
- Record the lived path in this repo (`docs/apps/matomo.md`, topology, networking, dated experience).
- Keep an upgrade path toward a shared Traefik-fronted Tunnel and GitOps later.

## Non-goals (v1)

- Paid Matomo plugins (heatmaps, session recordings, A/B testing, Funnels Marketplace packs).
- Matomo Tag Manager as a project in itself (default JS tracker only).
- Importing historical Google Analytics data.
- Tracking homelab apps (OpenProject, JupyterHub, n8n) in v1.
- Docker Compose beside k3s on host A.
- Bitnami Matomo/MariaDB Helm charts.
- Multi-node / HA control plane or replicated MariaDB.
- Routing Matomo through Traefik / cert-manager (Cloudflare terminates TLS).
- Flux / SOPS GitOps (Secrets in-cluster for now).
- Longhorn or replicated block storage.
- Moving Matomo to the OVH VPS.
- Guaranteed-working secrets or private inventory in this docs repo.

## Context from the handbook

- Teaching GPU host A already runs single-node k3s with JupyterHub and n8n, each published via Cloudflare Tunnel + Access. See [deployment topology](../../experiences/deployment-topology.md) and [n8n](../../apps/n8n.md).
- Home IPv4 is CGNAT; public HTTP apps use Tunnel + Access, not port forwards. [Networking](../../architecture/networking.md).
- The hybrid design puts web apps on K3s and keeps Compose for host-level tools such as Uptime Kuma on the VPS. Matomo is a web app, so it belongs on k3s on host A, not on the Headscale VPS.
- Matomo On-Premise is GPL-3.0. Core analytics are free; some GA-like extras are paid plugins and stay out of v1.
- Tracking beacons **must** reach `matomo.php` / `matomo.js` without login. Putting the whole hostname behind Access (or enabling Tunnel **Protect with Access**) would drop visits.

## Decision

**Approach 1 — K3s + official images + one Tunnel with path-based Access**

Deploy Matomo and MariaDB from official images in namespace `matomo`. Run `cloudflared` in-cluster so the Tunnel targets the Matomo ClusterIP Service. Use a single public hostname `webanalytics.willyrv.com`. Configure Cloudflare Access so tracking paths Bypass and all other paths require an allowlisted email. Complete Matomo’s web wizard through Access. Archive reports with a CronJob, not during browser views.

Rejected for v1:

- **Docker Compose beside k3s** — matches Matomo’s FAQ, but puts a second orchestrator on a host that already runs k3s for JupyterHub and n8n.
- **Bitnami Matomo Helm chart** — fewer manifests, but Bitnami registry/image friction (already a fallback topic for n8n Postgres) and less control over archive scheduling and official image pins.
- **Two hostnames** (dashboard vs tracker) — clearer Access rules, extra DNS/Tunnel/snippet surface; one hostname with Bypass paths is enough for v1.
- **VPN-only dashboard** (Headscale) with a public tracker hostname — cleaner isolation, more Ingress/Tunnel pieces than needed while Access already gates other apps on this host.

## Architecture

```text
Public sites (JS snippet on willyrv.com, blogs, docs)
        │
        ▼
https://webanalytics.willyrv.com/matomo.js
https://webanalytics.willyrv.com/matomo.php
        │
        ▼
Cloudflare Edge (HTTPS) — Access Bypass on tracking paths
        │
        ▼
Cloudflare Tunnel (outbound from teaching GPU host A)
        │
        ▼
cloudflared  ──►  Matomo Service :80
                      │
        ┌─────────────┴─────────────┐
        ▼                           ▼
   MariaDB PVC                 Matomo files PVC
        ▲
        └── CronJob: console core:archive

You (allowlisted email)
        │
        ▼
Same hostname, other paths
        │
        ▼
Cloudflare Access (email) → Matomo login → dashboard
```

| Concern | Choice |
|---------|--------|
| Cluster | Existing single-node K3s on teaching GPU host A |
| Namespace | `matomo` |
| Hostname | `webanalytics.willyrv.com` |
| App | Official `matomo` image, Apache variant, pinned tag |
| Database | Official `mariadb` image, pinned tag (not Postgres, not Bitnami) |
| Archive | Kubernetes CronJob running `php /var/www/html/console core:archive` |
| Matomo files | PVC mounted at `/var/www/html` (config, plugins, generated JS) |
| MariaDB data | Separate PVC |
| StorageClass | Default on the cluster (often `local-path`) |
| Tunnel | `cloudflared` Deployment + Secret (tunnel token) |
| TLS | Cloudflare edge; no Traefik/cert-manager for this app |
| Dashboard auth | Cloudflare Access Allow (email) **and** Matomo login |
| Tracking auth | Access Bypass for `/matomo.php`, `/matomo.js`, `/piwik.php`, `/piwik.js` |
| Secrets | Kubernetes Secrets; copies under `~/secrets/` on the host; never Git |

Do **not** enable **Protect with Access** on the Tunnel public hostname. That injects Access in front of every request, including tracking beacons. Access policy lives on the Zero Trust **application** with Bypass vs Allow, not as a blanket tunnel switch.

## Components

### MariaDB

- StatefulSet (or equivalent) with a dedicated Service, ClusterIP only, port 3306.
- Database/user/password from a Secret (`matomo` database, non-root app user).
- PVC size ~20 Gi for v1 (personal-site volume; grow if dumps or archive times warrant it).
- Starting resources: request 250m CPU / 512 Mi; limit 1 CPU / 2 Gi.
- Not published via NodePort, Ingress, or host ports.

### Matomo

- Deployment using official `matomo` (Apache) image.
- Env: `MATOMO_DATABASE_HOST`, `MATOMO_DATABASE_USERNAME`, `MATOMO_DATABASE_PASSWORD`, `MATOMO_DATABASE_DBNAME`, `PHP_MEMORY_LIMIT=512M`.
- PVC ~5 Gi at `/var/www/html` so `config.ini.php`, plugins, and generated files survive reschedules.
- Starting resources: request 250m CPU / 512 Mi; limit 1 CPU / 2 Gi.
- Service ClusterIP port 80. Tunnel HTTP URL: `matomo.matomo.svc.cluster.local:80` (exact Service name locked at implement time).

### Archive CronJob

- Same image and Matomo PVC as the app; command `php /var/www/html/console core:archive`.
- Schedule every 15 minutes after the wizard has written `config.ini.php`.
- Do not enable the CronJob (or expect it to succeed) before first install.
- After the wizard: disable **Archive reports when viewed from the browser** in Matomo system settings so archives do not run on dashboard load.

### cloudflared

- Deployment (one or two replicas) with the tunnel token from a Secret, same pattern as n8n.
- Outbound HTTPS to Cloudflare only.

### First boot

1. Prerequisites: node Ready, default StorageClass, Helm not required unless used as a convenience wrapper, outbound HTTPS to Cloudflare.
2. Cloudflare Tunnel public hostname `webanalytics.willyrv.com` → Matomo Service `:80`.
3. Access application on that hostname: Bypass policies for tracking paths (order before Allow); Allow policy for operator email(s).
4. Namespace, Secrets, MariaDB, Matomo.
5. Open `https://webanalytics.willyrv.com` through Access; complete the setup wizard. Database server is the in-cluster MariaDB Service name, not `localhost`.
6. Privacy defaults (below). Disable browser archiving. Enable CronJob.
7. Add the first owned site, paste the JS snippet, confirm a visit after an archive run.

### Visitor IP and HTTPS

Matomo sits behind Cloudflare and `cloudflared`. After install, configure trusted proxies / `CF-Connecting-IP` (or Matomo’s proxy client headers) so visits are not all attributed to Cloudflare. Force HTTPS / correct public URL (`https://webanalytics.willyrv.com`) so tracking snippets and cookies (if ever enabled) use the public hostname.

Optional later (not v1 blockers): Tag Manager `/js/container_*.js` Bypass, opt-out iframe paths from [Matomo’s security FAQ](https://matomo.org/faq/on-premise/how-to-configure-matomo-for-security/).

## Security and privacy

- Dashboard: Access email allowlist **plus** Matomo superuser password. Teaching or extra operators get Access invites, not cluster credentials or the tunnel token.
- Tracking: unauthenticated by design. Rate-limit / WAF at Cloudflare if abuse appears; v1 does not add a custom WAF.
- Database and Matomo files stay cluster-internal.
- Privacy defaults for personal sites (not an ads product):
  - anonymize visitor IPs;
  - cookieless / do not set tracking cookies unless a site later needs them;
  - delete old raw/visit logs after about **13 months**;
  - respect Do Not Track;
  - no heatmaps or session recordings;
  - tracker snippet only on sites the operator owns.
- Secrets: MariaDB passwords and tunnel token in Kubernetes Secrets and `~/secrets/` on host A (mode `600`). Never commit them. Public docs use placeholders if a token-shaped example would otherwise appear.

## Operations

- **Backup before calling v1 done:** `mysqldump` of the `matomo` database plus a copy of `config.ini.php` (salt, superuser token, DB settings) under `~/secrets/` on the host, dated, not in Git. Cluster PVCs are not a backup.
- **Restart test:** delete the Matomo pod; UI and a known visit remain.
- **Tracking regression test:** `curl` `/matomo.js` without an Access cookie must return `200`. `curl` `/` without Access must not return the dashboard.
- **Upgrades:** pin image tags; `kubectl` (or a documented roll) to a newer Matomo tag; complete any in-app database upgrade; keep MariaDB major version explicit.
- Later without changing the public hostname: point the same Tunnel at Traefik Ingress; join more K3s nodes; keep namespace and Service names stable.

## Documentation updates in this repo

1. Add `docs/apps/matomo.md` — canonical placement, install narrative, Access Bypass list, backups. Status **Planned** until the live install works, then **Implemented**.
2. Cross-link [docs/architecture/networking.md](../../architecture/networking.md): Tunnel + Access for this app, with tracking-path Bypass (unlike n8n’s full-hostname gate).
3. Add Matomo on teaching GPU host A and `webanalytics.willyrv.com` to [docs/experiences/deployment-topology.md](../../experiences/deployment-topology.md).
4. Link from the README apps list, docs index as needed, and [Phase 5 — stateful apps](../../guides/phase-05-stateful-apps.md).
5. After the live install, add a dated experience under `docs/experiences/` and list it from [experiences README](../../experiences/README.md).
6. Manifests may move to a GitOps repo later. This docs repo holds design, runbook, and app notes — not live secrets.

Private addresses stay in gitignored `docs/**/*.local.md`. Tracked markdown must still pass `./scripts/verify-docs.sh`.

## Success criteria

- Dashboard at `https://webanalytics.willyrv.com` only after Cloudflare Access **and** Matomo login.
- `/matomo.js` and `/matomo.php` succeed **without** an Access cookie.
- At least one owned page records a visit after `core:archive`.
- MariaDB dump and `config.ini.php` copy exist under `~/secrets/` on host A.
- Matomo and MariaDB PVCs rebound after pod deletion.
- Handbook `docs/apps/matomo.md` and topology match the lived path.
- `./scripts/verify-docs.sh` passes.

## Open choices deferred to implementation plan

- Exact image tags (`matomo`, `mariadb`, `cloudflare/cloudflared`) and whether Matomo is a Deployment or a small Helm wrapper around the official image.
- Exact Kubernetes Service/StatefulSet names (Tunnel URL must match).
- Exact Cloudflare Access path matchers (prefix vs exact; whether `/js/` and opt-out paths are Bypass on day one).
- StorageClass name present on the cluster.
- CronJob schedule (15 minutes vs hourly) after measuring archive duration.
- Whether to reuse an existing Tunnel on host A or create a dedicated Tunnel token for namespace `matomo` (n8n used a dedicated token; prefer dedicated unless host-A Tunnel management is already centralized).
- Geolocation database (DB-IP vs MaxMind) — optional, not a v1 blocker.
