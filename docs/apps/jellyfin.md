# Jellyfin

Status: Recommended

## Purpose

Jellyfin serves personal media libraries and can use a GPU or integrated GPU for hardware transcoding. Its dependence on local media disks and hardware makes placement more important than cluster portability.

## Placement

Run Jellyfin either with Docker Compose directly on the media node or in K3s permanently pinned to that node. If you use K3s, label the media node and select it explicitly:

```yaml
nodeSelector:
  feature: jellyfin-transcoding
```

## Storage and devices

Mount:

```text
/config         → SSD
/cache          → SSD
/media/movies   → large HDD
/media/tv       → large HDD
/dev/dri        → container, for Intel/AMD hardware acceleration
```

Do not replicate the full media library through Longhorn. Keep bulk media on local disks or purpose-built shared storage, as described in [Storage strategy](../architecture/storage.md).

## Backups

Back up Jellyfin configuration and metadata. Decide whether to back up each media collection according to how replaceable the files are and the cost of recreating them.

## Planned

- Choose between host-level Compose and a node-pinned K3s deployment.
- Validate hardware acceleration and device permissions on the media node.
- Document media mounts, configuration backups, upgrades, and restore steps.

## See also

- [Machine roles](../architecture/machine-roles.md)
- [Storage strategy](../architecture/storage.md)
- [Phase 6 — media and Git](../guides/phase-06-media-and-git.md)
