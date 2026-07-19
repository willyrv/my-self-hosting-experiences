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

Monitoring should verify the backup process, not merely whether the cluster is running. Keep administrative dashboards under the [VPN-only exposure policy](networking.md).

## See also

- [Networking and exposure](networking.md)
- [Backup design](backups.md)
- [Resource planning](resources.md)
- [Phase 4 — low-risk apps](../guides/phase-04-low-risk-apps.md)
- [Phase 7 — operations](../guides/phase-07-operations.md)
