# Cloud service: Nextcloud or Seafile

Status: Recommended

## Purpose

Nextcloud and Seafile are mature options for self-hosted file access and synchronization. Choose between them by required features, data architecture, and recovery characteristics rather than implementation language.

## Placement

Deploy the chosen service in K3s on the application or storage node, with node affinity when its data uses local disks. Put cloud user files on NFS or dedicated local storage and keep application databases on SSD-backed persistent storage.

## Choosing a service

### Nextcloud

Nextcloud is the broadest option:

- File synchronization
- Calendar and contacts
- WebDAV
- Sharing
- Collaborative applications
- A large application ecosystem

Nextcloud is PHP-based, not Python or Rust. Choose it when you want a complete personal collaboration platform.

### Seafile

Seafile focuses on file synchronization and libraries. Choose it when you primarily want:

- Fast file synchronization
- Large file collections
- Fewer collaboration features
- A lighter operational footprint than a fully extended Nextcloud installation

Although parts of Seafile's ecosystem use Python, select it based on functionality and data architecture.

### Rust-based options

There is no obvious mature Rust-based product that completely replaces Nextcloud's combination of desktop and mobile synchronization, sharing, calendars, contacts, collaboration, and plugin ecosystem. Prioritize reliable clients, upgrade and migration procedures, data recovery, file-format independence, and community longevity.

The likely choice is Seafile for file synchronization only or Nextcloud for an integrated personal cloud.

## Backups and warnings

Back up the application database, configuration, and user files independently. Confirm that file data remains recoverable without a running cluster, and test the application's documented restore sequence.

## Planned

- Select Nextcloud or Seafile after testing the required clients and features.
- Validate the deployment method and persistent-volume layout.
- Document ingress, secrets, upgrades, database backups, and full data recovery.

## See also

- [Storage strategy](../architecture/storage.md)
- [Backup design](../architecture/backups.md)
- [Phase 5 — stateful apps](../guides/phase-05-stateful-apps.md)
