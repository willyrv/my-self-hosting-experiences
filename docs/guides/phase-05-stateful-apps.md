# Phase 5 — Stateful applications

Status: Planned

## Goal

Introduce important persistent workloads one at a time, with storage, backup, and tested recovery designed before the next application is deployed.

## Checklist

- Deploy OpenProject.
- Create and test the OpenProject database and attachment backups.
- Deploy JupyterHub.
- Create and test backups of user homes and shared notebooks.
- Select and deploy either Seafile or Nextcloud.
- Create and test backups of its database, configuration, and user files.
- Document storage placement, secrets, upgrades, and recovery for each application.

## Details

Deploy OpenProject on the application/compute node. Keep PostgreSQL on persistent SSD storage, give attachments their own persistent volume, and expose only the web interface. Back up both logical PostgreSQL dumps and volume data, including attachments.

Use JupyterHub when several users or isolated environments justify it; a single trusted user may only need JupyterLab. Keep JupyterHub VPN-only, set CPU and memory guarantees and limits, and separate persistent home directories from disposable computation. NFS, local SSD, or Longhorn can hold homes according to the lab's availability and performance needs.

Choose Nextcloud for a broad collaboration platform or Seafile for focused file synchronization and a lighter footprint. Place user files on NFS or dedicated local storage and databases on SSD-backed storage. Confirm that user files remain recoverable without a running cluster.

For every application, finish a restore test before moving to the next. Replication and volume snapshots are not sufficient backups: use application-aware exports or logical database dumps alongside file or volume backups, with an independent copy outside the cluster.

## Verify before next phase

- OpenProject survives a redeployment and a tested restore recovers both database records and attachments.
- JupyterHub enforces resource limits and a tested restore recovers representative user work.
- The chosen cloud service can recover its database, configuration, and representative user files in the documented order.
- Databases and internal data services are not directly exposed.
- Backup outputs are stored independently of the cluster and their age or success can be checked.
- Each application's storage placement, secrets, update, rollback, and recovery notes are current.

## See also

- [OpenProject](../apps/openproject.md)
- [JupyterHub](../apps/jupyterhub.md)
- [Nextcloud or Seafile](../apps/cloud-nextcloud-seafile.md)
- [Backup design](../architecture/backups.md)
- [Storage strategy](../architecture/storage.md)

## Navigation

- Previous: [Phase 4 — low-risk apps](phase-04-low-risk-apps.md)
- Next: [Phase 6 — media and Git](phase-06-media-and-git.md)
