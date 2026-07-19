# Phase 6 — Hardware-sensitive and heavy applications

Status: Planned

## Goal

Add media and Git services with placement, resources, storage, devices, and recovery matched to their hardware and operational weight.

## Checklist

- Choose host-level Docker Compose or a node-pinned K3s deployment for Jellyfin.
- Place Jellyfin on the storage/media node.
- Validate media mounts and hardware transcoding.
- Decide whether GitLab's features justify its resource cost or select Forgejo/Gitea.
- Place GitLab on a dedicated VM or host when selected.
- Deploy GitLab Runner in K3s when cluster-based CI is needed.
- Set resource limits and complete backup and restore tests for both services.

## Details

Jellyfin depends on media disks and, often, a GPU or integrated GPU. Run it directly on the media host or pin it permanently to that node in K3s. Keep configuration and cache on SSD, media on large local disks or purpose-built shared storage, and pass the required device only after validating permissions and hardware acceleration. Do not replicate a multi-terabyte media library through Longhorn.

Back up Jellyfin configuration and metadata. Decide separately which media files warrant backup based on their replaceability and recovery cost.

Do not start with GitLab's complete cloud-native Helm deployment in a two- or three-machine lab. If GitLab's registry, CI, and integrated features are required, use GitLab Omnibus on a dedicated VM or Docker host and optionally run isolated CI runners in K3s. If those features are unnecessary, Forgejo or Gitea is the lower-resource choice and can run on a dedicated host or in K3s with persistent SSD storage.

A Git forge needs supported backups covering repositories, database, configuration, secrets, uploads, and registry data. Validate a complete restore before treating it as the authoritative home of infrastructure or application source.

## Verify before next phase

- Jellyfin reads the intended media mounts and hardware transcoding works on representative media.
- Jellyfin remains scheduled on, or directly hosted by, the designated media node.
- Jellyfin configuration and metadata can be restored from an independent backup.
- The selected Git forge stays within its assigned CPU, RAM, and storage budget.
- A test CI job runs with the documented runner isolation and permissions when runners are enabled.
- A restore test recovers representative repositories and the forge's required database, configuration, and secrets.

## See also

- [Jellyfin](../apps/jellyfin.md)
- [GitLab or a lighter forge](../apps/gitlab-or-forgejo.md)
- [Machine roles](../architecture/machine-roles.md)
- [Resource planning](../architecture/resources.md)
- [Storage strategy](../architecture/storage.md)

## Navigation

- Previous: [Phase 5 — stateful apps](phase-05-stateful-apps.md)
- Next: [Phase 7 — operations](phase-07-operations.md)
