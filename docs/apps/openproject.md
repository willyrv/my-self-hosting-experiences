# OpenProject

Status: Recommended

## Purpose

OpenProject provides project planning, issue tracking, and team collaboration. Its official Helm chart makes it a suitable stateful K3s workload for this homelab.

## Placement

Deploy OpenProject in K3s on the application and compute node. Keep PostgreSQL on persistent SSD storage, and give the attachment store its own persistent volume.

## Deployment sketch

```text
OpenProject web/workers → Kubernetes
PostgreSQL              → Kubernetes with persistent SSD storage
Attachments             → persistent volume
Redis                   → Kubernetes
```

Keep PostgreSQL and Redis private; expose only the OpenProject web interface through the ingress policy described in [Networking and exposure](../architecture/networking.md).

## Backups

Back up both:

- PostgreSQL database dumps
- Attachment storage

Use logical database dumps as well as volume-level backups. Test a restore before depending on the service; see [Backup design](../architecture/backups.md).

## Planned

- Validate the official Helm chart against the lab's K3s version.
- Choose local SSD or Longhorn-backed persistent volumes.
- Document secrets, ingress, upgrades, and a complete restore procedure.

## See also

- [Architecture overview](../architecture/overview.md)
- [Storage strategy](../architecture/storage.md)
- [Phase 5 — stateful apps](../guides/phase-05-stateful-apps.md)
