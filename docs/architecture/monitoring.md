# Monitoring

Status: Recommended

This page defines a modest initial observability stack and the minimum signals needed to operate the homelab.

## Initial stack

```text
Prometheus       → metrics
Grafana          → dashboards
Loki             → logs
Alertmanager     → alerts
Uptime Kuma      → external-style availability checks
```

Keep monitoring lightweight initially. Full Prometheus retention can consume considerable storage.

### VPN path (validated early)

Before the full Prometheus stack, this lab uses **[Uptime Kuma](../apps/uptime-kuma.md)** on the OVH VPS (Docker + Nginx, public `status.willyrv.com`) to watch:

- Headscale: `https://headscale.willyrv.com/health`
- Home Tailscale subnet router: ping/TCP to the home node’s Tailscale IP from a VPS probe client

Abuse signals (Nginx scanners, Headscale auth failures) are handled with CrowdSec and a journal watcher alongside Kuma — see the [Uptime Kuma experience note](../experiences/2026-07-20-uptime-kuma-vpn-monitoring.md).

## Minimum coverage

Monitor:

- Node CPU and RAM
- Temperatures
- Disk space and SMART status
- Kubernetes pod restarts
- Certificate expiration
- HTTP availability
- PostgreSQL backup age
- Backup job success
- UPS status
- Internet connectivity
- RAID, ZFS, or Btrfs health where applicable

Monitoring should verify the backup process, not merely whether the cluster is running. Prefer VPN-only for heavy admin UIs (Grafana, etc.). **Uptime Kuma** is an intentional exception: it stays publicly reachable with a strong admin password and edge protection.

## See also

- [Uptime Kuma](../apps/uptime-kuma.md)
- [Headscale](../apps/headscale.md)
- [Networking and exposure](networking.md)
- [Backup design](backups.md)
- [Resource planning](resources.md)
- [OpenProject](../apps/openproject.md)
- [Phase 4 — low-risk apps](../guides/phase-04-low-risk-apps.md)
- [Phase 7 — operations](../guides/phase-07-operations.md)
