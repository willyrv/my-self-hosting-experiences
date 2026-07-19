# Storage strategy

Status: Recommended

This page selects storage by workload instead of assuming that every Kubernetes volume should use the same backend.

Storage is more important than Kubernetes itself. A small homelab has three principal choices.

## Choice 1 — Local persistent volumes

Each application's data stays on a specific machine.

```text
Jellyfin media  → node-3 local disks
GitLab data     → node-2 local SSD
OpenProject DB  → node-1 local SSD
```

### Advantages

- Simple, fast, and easy to understand
- No distributed-storage overhead

### Disadvantages

- An application cannot transparently move to another node
- Node failure causes downtime until recovery

For a small installation, local persistent volumes are often the best initial choice. Use node affinity to keep pods on the node containing their data.

## Choice 2 — Longhorn

Longhorn provides replicated block storage across Kubernetes nodes.

```text
Each node
├── OS SSD
└── Dedicated Longhorn SSD
```

Longhorn can suit:

- PostgreSQL volumes
- Application configuration
- Jupyter home directories
- Small and medium application data

Do not automatically use it for:

- A multi-terabyte Jellyfin media library
- Large disposable datasets
- Backup storage
- Frequently rewritten large media files

Replication multiplies storage consumption. A 500 GB volume with three replicas can consume approximately 1.5 TB before overhead and snapshots.

## Choice 3 — Central NFS storage

One machine exports storage over NFS.

```text
Storage node
└── ZFS/Btrfs/ext4 filesystems
    ├── /exports/cloud
    ├── /exports/jupyter
    └── /exports/media
```

### Advantages

- Centralized storage that is easy to inspect and back up
- Appropriate for media and shared notebooks

### Disadvantages

- The storage node is a single point of failure
- Database performance and locking may be problematic
- Network speed becomes important

## Practical combination

```text
Databases and configuration → local SSD or Longhorn
Cloud user files             → NFS or dedicated local disks
Jupyter home directories     → NFS
Jellyfin media               → local storage on media node
Backups                      → independent disk + off-site copy
```

## See also

- [Architecture overview](overview.md)
- [Machine roles](machine-roles.md)
- [Backup design](backups.md)
- [Phase 3 — K3s cluster](../guides/phase-03-k3s-cluster.md)
- [Jellyfin](../apps/jellyfin.md)
- [JupyterHub](../apps/jupyterhub.md)
