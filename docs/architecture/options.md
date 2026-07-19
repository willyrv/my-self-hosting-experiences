# Architecture options

Status: Recommended

This page compares three deployment models and explains why the hybrid K3s architecture is recommended.

## Option A — Docker Compose on each machine

This is the simplest starting point.

```text
Machine 1
├── Reverse proxy
├── OpenProject
├── Cloud service
└── VPN

Machine 2
├── Jellyfin
├── Marimo
└── Jupyter

Machine 3
├── GitLab
├── Monitoring
└── Backups
```

### Advantages

- Easy to understand and debug
- Few moving parts
- Straightforward GPU and media-device access
- Applications are isolated from failures on other computers

### Disadvantages

- No automatic rescheduling when a machine fails
- Configuration gradually becomes fragmented
- Deployments and upgrades are less standardized
- Networking and certificates must be managed separately

Choose this when the priority is running services simply rather than learning Kubernetes.

## Option B — Everything on K3s

With three machines, an embedded-etcd cluster can use three server nodes:

```text
node-1: K3s server + workloads
node-2: K3s server + workloads
node-3: K3s server + workloads
```

K3s requires an odd number of server nodes for useful embedded-etcd high availability. A two-server embedded-etcd cluster does not provide useful quorum-based fault tolerance.

### Advantages

- One deployment model
- Automatic workload rescheduling
- Access to Helm charts and Kubernetes operators
- A good environment for learning Kubernetes
- Easier GitOps and configuration versioning

### Disadvantages

- Distributed storage becomes the hardest part
- Databases require careful backup and recovery
- Jellyfin hardware acceleration is more complicated
- GitLab is a particularly heavy Kubernetes application
- Cluster failure can affect nearly every service simultaneously

Choose this only after becoming comfortable operating Kubernetes storage and recovering etcd.

## Option C — Hybrid K3s architecture

This is the recommended approach.

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

Option C keeps the standard deployment and scheduling benefits of Kubernetes for suitable applications while avoiding unnecessary complexity for stateful and hardware-bound services.

## See also

- [Architecture overview](overview.md)
- [Storage strategy](storage.md)
- [Machine roles](machine-roles.md)
- [Phase 3 — K3s cluster](../guides/phase-03-k3s-cluster.md)
- [Jellyfin](../apps/jellyfin.md)
- [GitLab or a lighter forge](../apps/gitlab-or-forgejo.md)
