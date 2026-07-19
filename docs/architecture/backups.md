# Backup design

Status: Recommended

This page defines a cluster-independent backup and recovery model for applications, databases, and persistent files.

Replication is not backup. Use a 3-2-1-inspired structure:

```text
Primary data
    │
    ├── Local scheduled backup
    │      └── separate physical disk
    │
    └── Encrypted off-site backup
           └── S3-compatible provider or remote server
```

## Tools by data type

- Restic or Borg for files
- Native `pg_dump` for PostgreSQL
- Application-specific exports
- K3s etcd snapshots
- Velero for Kubernetes resources and selected persistent volumes

Do not rely exclusively on volume snapshots. For every database:

```text
Database backup = logical dump + volume-level backup
```

## Recovery inputs

Recovery documentation should explain how to rebuild the system from:

1. Fresh Linux installations
2. The separate GitOps repository
3. Encrypted secrets
4. Database dumps
5. Persistent file backups

Test restoring at least one application before considering the backup strategy complete.

## See also

- [Storage strategy](storage.md)
- [GitOps layout](gitops-layout.md)
- [Monitoring](monitoring.md)
- [Phase 5 — stateful apps](../guides/phase-05-stateful-apps.md)
- [Phase 7 — operations](../guides/phase-07-operations.md)
- [OpenProject](../apps/openproject.md)
