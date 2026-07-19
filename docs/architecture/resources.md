# Resource planning

Status: Recommended

This page gives a comfortable starting allocation for a three-node homelab and identifies the workloads most likely to constrain it.

## Suggested capacity

| Machine | Suggested role | CPU | RAM | Storage |
|---|---|---:|---:|---|
| Node 1 | Infrastructure | 4–8 cores | 16 GB | 500 GB SSD |
| Node 2 | Compute/apps | 8+ cores | 32–64 GB | 1 TB SSD/NVMe |
| Node 3 | Media/storage | 4–8 cores | 16–32 GB | SSD + large HDDs |

The likely RAM-heavy workloads are:

- GitLab
- Jupyter user environments
- OpenProject
- Nextcloud with many extensions
- Monitoring with long data retention

Jellyfin depends more on media storage and hardware transcoding than on RAM.

With less than approximately 48 GB of aggregate RAM, prefer a lighter Git forge or place GitLab on a separate machine with strict resource limits.

## See also

- [Machine roles](machine-roles.md)
- [Storage strategy](storage.md)
- [Monitoring](monitoring.md)
- [Phase 1 — base OS](../guides/phase-01-base-os.md)
- [GitLab or a lighter forge](../apps/gitlab-or-forgejo.md)
- [JupyterHub](../apps/jupyterhub.md)
