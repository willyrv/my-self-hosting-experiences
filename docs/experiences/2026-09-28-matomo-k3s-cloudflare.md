# Matomo on single-node k3s with Cloudflare Tunnel

Date: 2026-09-28  
Status: Accepted

## Context

I wanted Matomo On-Premise for sites I own (`willyrv.com`, blogs, docs), with the data on a machine I already run. Teaching GPU host A already had single-node k3s, JupyterHub, and n8n, and those apps are published with Cloudflare Tunnel because the home line is behind CGNAT. Matomo is different from n8n: the dashboard should stay behind Access, but `/matomo.js` and `/matomo.php` have to stay public or the tracker never records a visit.

## Decision

Follow the copy-paste runbook rather than Docker Compose on the host:

- Namespace `matomo` on host A
- Official `matomo:5-apache` and `mariadb:11`
- App files on a PVC at `/var/www/html`, database on its own PVC
- Dedicated tunnel `homelab-matomo` to `https://webanalytics.willyrv.com`
- Access Bypass on the tracker paths; Access Allow plus Matomo login on the dashboard
- Report archiving with `core:archive`, not when someone opens the UI

The commands, Access app names, wizard fields, and backup steps are in the [guide](../guides/matomo-k3s-cloudflare.md). I checked that shape against the [official Docker install](https://matomo.org/faq/how-to-install/install-matomo-with-docker/) before starting. Stable Matomo was still 5.x (`5-apache` is the right pin; 6.0 was only a beta). The Compose FAQ’s database env vars, `/var/www/html` volume, `PHP_MEMORY_LIMIT`, and `core:archive` loop match the guide. The k3s-only parts (Access path split, ReadWriteOnce archive fallback) are not in that FAQ.

## What I did

1. Confirmed `kubectl` was the host A cluster, then created the tunnel, the four Bypass apps, and the dashboard Allow app in Zero Trust before `cloudflared` existed in the cluster.
2. Created the namespace and Secrets from `~/secrets/` (not from git).
3. Applied MariaDB, then the Matomo Deployment, then `cloudflared`.
4. Finished the web wizard through Access, with database server `matomo-mariadb`.
5. Continued through the guide until the UI was up.

## Friction

The MariaDB smoke test in the guide failed on current `kubectl`:

```text
error: --rm should only be used for attached containers
```

`--rm` only deletes the pod when the client stays attached. The command needs `-it` (the guide now includes it).

The retry then failed with:

```text
Error from server (AlreadyExists): pods "mysql-smoke" already exists
```

The first attempt had already created the pod. `kubectl -n matomo delete pod mysql-smoke --wait=true`, then the same `kubectl run` again, got a `SELECT 1` result.

The guide still pins `cloudflared:2025.8.1`. Newer tags (`2026.9.0`) exist, and Cloudflare’s support window is about a year, so the next image bump should leave that 2025 tag behind. This install used the pin in the guide.

## Consequences

- `docs/apps/matomo.md` is the handbook page for this placement. The [guide](../guides/matomo-k3s-cloudflare.md) stays the command list.
- Tracking paths are public on purpose. Turning on **Protect with Access** for the tunnel hostname would drop visits.
- If the archive CronJob stays Pending with a Multi-Attach error, the guide’s sidecar (same pod, same PVC) is the fallback. I did not need a second orchestrator beside k3s.
- Database dumps and `config.ini.php` belong in `~/secrets/` on the host. The PVCs are not a backup.

## See also

- [Matomo app page](../apps/matomo.md)
- [Guide](../guides/matomo-k3s-cloudflare.md)
- [Design](../superpowers/specs/2026-09-14-matomo-k3s-cloudflare-design.md)
- [Implementation plan](../superpowers/plans/2026-09-14-matomo-k3s-cloudflare.md)
- [Networking](../architecture/networking.md)
