# JupyterHub

Status: Recommended

## Purpose

JupyterHub provides isolated notebook environments for several users, teaching, or workloads that need configurable images. For one trusted user, a normal JupyterLab container may be sufficient.

## Placement

Deploy JupyterHub in K3s on the application and compute node. Store user home directories on persistent volumes, place temporary computation in ephemeral storage, and keep the service VPN-only.

## Deployment sketch

```text
JupyterHub
├── Hub pod
├── Proxy
├── User pod: scientific Python
├── User pod: PyTorch/GPU
└── User pod: lightweight teaching environment
```

Set resource guarantees and limits so one user cannot consume the cluster:

```yaml
singleuser:
  cpu:
    guarantee: 0.5
    limit: 4
  memory:
    guarantee: 1G
    limit: 8G
```

Do not run both an independent Jupyter server and JupyterHub unless they serve different purposes. JupyterHub can become the primary Jupyter service.

## Backups

Back up user home directories and any shared notebooks. Treat reproducible environments and disposable computation separately from persistent user work.

## Planned

- Validate the JupyterHub chart and user images on K3s.
- Choose NFS, local SSD, or Longhorn-backed home directories.
- Document authentication, image updates, quotas, backups, and restore tests.

## See also

- [Storage strategy](../architecture/storage.md)
- [Resource planning](../architecture/resources.md)
- [Phase 5 — stateful apps](../guides/phase-05-stateful-apps.md)
