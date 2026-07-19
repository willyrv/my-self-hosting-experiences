# Architecture overview

Status: Recommended

This page summarizes the recommended hybrid architecture for a self-hosted environment running on two or three computers.

## Recommendation

K3s is a reasonable foundation for a homelab that may grow to include JupyterHub, OpenProject, marimo, and similar applications. With only two or three machines, however, putting every service inside Kubernetes makes storage-sensitive and hardware-sensitive workloads unnecessarily difficult.

The recommended design is therefore a **hybrid homelab architecture**:

- K3s for web applications and computational workloads
- Dedicated host-level services, or carefully pinned workloads, for storage-sensitive and hardware-sensitive applications
- Infrastructure managed through Git
- Off-site backups that remain independent of the cluster

The [architecture options](options.md) page compares this approach with per-host Docker Compose and an all-in-K3s design.

## Hybrid design

```text
                        Internet
                           │
                    Router / firewall
                           │
                ┌──────────┴──────────┐
                │                     │
          Public HTTPS             WireGuard
                │                     │
       Ingress / reverse proxy      Private access
                │
        ┌───────┴────────┐
        │   K3s cluster  │
        └───────┬────────┘
                │
   ┌────────────┼────────────┐
   │            │            │
OpenProject   JupyterHub    Marimo
Cloud UI     Small apps     Monitoring

Outside Kubernetes or pinned to one node:
├── Jellyfin + media disks + GPU/iGPU
├── Primary backup repository
└── Possibly GitLab
```

This uses Kubernetes where scheduling and a consistent deployment model add value without making the cluster the only route to data or administration.

## Final concrete recommendation

```text
Three physical Debian machines
│
├── Three-node K3s control plane
│   ├── Traefik
│   ├── cert-manager
│   ├── MetalLB or K3s ServiceLB
│   ├── OpenProject
│   ├── JupyterHub
│   ├── Marimo
│   ├── Uptime Kuma
│   └── Later: monitoring and identity provider
│
├── Storage
│   ├── Local SSD volumes initially
│   ├── NFS for shared notebook/file data
│   ├── Dedicated media disks
│   └── Longhorn later, only where replication is valuable
│
├── Outside Kubernetes or specially pinned
│   ├── WireGuard on the host
│   ├── Jellyfin on the GPU/media node
│   └── GitLab Omnibus on a dedicated VM or host
│
└── Operations
    ├── Flux
    ├── SOPS + age
    ├── Restic or Borg
    ├── PostgreSQL dumps
    ├── K3s etcd snapshots
    └── Encrypted off-site backups
```

> **Use Kubernetes to manage applications, but do not make Kubernetes the sole guardian of your data or your emergency access path.**

## See also

- [Architecture options](options.md)
- [Machine roles](machine-roles.md)
- [Storage strategy](storage.md)
- [Phase 3 — K3s cluster](../guides/phase-03-k3s-cluster.md)
- [WireGuard](../apps/wireguard.md)
