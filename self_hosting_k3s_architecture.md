# Self-hosting architecture for 2–3 computers

Yes. **K3s is a reasonable choice**, particularly because this project can grow and because JupyterHub, OpenProject, and marimo fit Kubernetes well.

However, with only two or three machines, I would avoid putting absolutely everything inside Kubernetes.

My preferred design would be a **hybrid homelab architecture**:

- K3s for web applications and computational workloads;
- dedicated host-level services for storage-sensitive or hardware-sensitive applications;
- infrastructure managed through Git;
- off-site backups independent of the cluster.

---

# 1. Three possible architectures

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

- Easy to understand and debug;
- few moving parts;
- straightforward GPU and media-device access;
- applications are isolated from failures on other computers.

### Disadvantages

- No automatic rescheduling when a machine fails;
- configuration gradually becomes fragmented;
- deployments and upgrades are less standardized;
- networking and certificates must be managed separately.

This is appropriate when the main objective is **running services reliably**, rather than learning Kubernetes.

---

## Option B — Everything on K3s

With three machines, you could create a three-server K3s cluster using embedded etcd:

```text
node-1: K3s server + workloads
node-2: K3s server + workloads
node-3: K3s server + workloads
```

K3s requires an odd number of server nodes for an embedded-etcd high-availability cluster. Its documented high-availability architecture starts with three server nodes.

A two-server embedded-etcd cluster does not provide useful quorum-based fault tolerance.

### Advantages

- One deployment model;
- automatic workload rescheduling;
- access to Helm charts and Kubernetes operators;
- good environment for learning Kubernetes;
- easier GitOps and configuration versioning.

### Disadvantages

- Distributed storage becomes the hardest part;
- databases require careful backup and recovery procedures;
- Jellyfin hardware acceleration is more complicated;
- GitLab is a particularly heavy Kubernetes application;
- cluster failure can affect nearly every service simultaneously.

I would only choose this after becoming comfortable operating Kubernetes storage and recovering etcd.

---

## Option C — Hybrid K3s architecture

This is the approach I recommend.

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

This gives you Kubernetes where it is useful, while avoiding unnecessary complexity for stateful and hardware-bound services.

---

# 2. Suggested machine roles

Assuming three computers:

## Machine 1 — Infrastructure node

```text
K3s server
Ingress controller
cert-manager
DNS-related services
Monitoring
VPN endpoint or Headscale
```

Use an SSD and ideally a UPS.

## Machine 2 — Application and compute node

```text
K3s server
OpenProject
Marimo
JupyterHub
Other future applications
```

This should be the node with the most CPU and RAM.

## Machine 3 — Storage and media node

```text
K3s server
Jellyfin pinned to this node
Large HDDs
Backup repository
Cloud file data
```

If this machine has an Intel iGPU, NVIDIA GPU, or suitable AMD GPU, use it for Jellyfin transcoding.

Even when using all three computers as K3s servers, you can use labels and node affinity:

```bash
kubectl label node node-1 role=infrastructure
kubectl label node node-2 role=compute
kubectl label node node-3 role=storage
kubectl label node node-3 feature=jellyfin-transcoding
```

This prevents Kubernetes from placing hardware-dependent applications arbitrarily.

---

# 3. Recommended infrastructure stack

## Operating system

Use the same minimal Linux distribution on all machines:

- Debian 13; or
- Ubuntu Server LTS.

Avoid mixing operating systems unless there is a specific reason.

Configure:

- static DHCP leases;
- consistent hostnames;
- SSH keys only;
- automatic security updates;
- a firewall on every host;
- NTP synchronization;
- a UPS where possible.

---

## Kubernetes distribution

Use **K3s**.

For three stable machines:

```text
3 × K3s server/control-plane nodes
Embedded etcd
Workloads allowed on all nodes
```

For only two machines, start with:

```text
1 × K3s server
1 × K3s agent
```

This is not control-plane high availability, but it is simpler and more predictable than attempting a two-member etcd deployment.

---

## Ingress and TLS

K3s includes Traefik by default. You can either:

- keep Traefik, which is entirely adequate for this project; or
- disable it and install ingress-nginx if you strongly prefer Nginx semantics.

Add **cert-manager** for TLS certificates.

For applications exposed publicly:

```text
service.example.net
cloud.example.net
projects.example.net
git.example.net
```

For private-only applications:

```text
jupyter.internal.example.net
marimo.internal.example.net
grafana.internal.example.net
```

Private applications should be available only through the VPN.

---

## Bare-metal service IP addresses

K3s includes ServiceLB, which may be enough initially.

Alternatively, install MetalLB and reserve a small range on your LAN:

```text
192.168.1.220–192.168.1.230
```

Do not include these addresses in your router’s normal DHCP allocation range.

---

# 4. Storage strategy

Storage is more important than Kubernetes itself.

You have three principal choices.

## Choice 1 — Local persistent volumes

Each application’s data stays on a specific machine.

```text
Jellyfin media  → node-3 local disks
GitLab data     → node-2 local SSD
OpenProject DB  → node-1 local SSD
```

### Advantages

- Simple;
- fast;
- easy to understand;
- no distributed storage overhead.

### Disadvantages

- The application cannot transparently move to another node;
- node failure means downtime until recovery.

For a small self-hosted installation, this is often the best initial choice.

Use Kubernetes node affinity to ensure that pods remain on the node containing their data.

---

## Choice 2 — Longhorn

Longhorn provides replicated block storage across Kubernetes nodes.

Possible design:

```text
Each node
├── OS SSD
└── Dedicated Longhorn SSD
```

Use Longhorn for:

- PostgreSQL volumes;
- application configuration;
- Jupyter home directories;
- small and medium application data.

Do not automatically use it for:

- a multi-terabyte Jellyfin media library;
- large disposable datasets;
- backup storage;
- frequently rewritten large media files.

Replication multiplies storage consumption.

For example, a 500 GB volume with three replicas can consume approximately 1.5 TB before overhead and snapshots.

---

## Choice 3 — Central NFS storage

One machine exports storage through NFS.

```text
Storage node
└── ZFS/Btrfs/ext4 filesystems
    ├── /exports/cloud
    ├── /exports/jupyter
    └── /exports/media
```

### Advantages

- Simple centralized storage;
- easy to inspect and back up;
- appropriate for media and shared notebooks.

### Disadvantages

- The storage node becomes a single point of failure;
- database performance and locking may be problematic;
- network speed becomes important.

A practical combination is:

```text
Databases and configuration → local SSD or Longhorn
Cloud user files             → NFS or dedicated local disks
Jupyter home directories     → NFS
Jellyfin media               → local storage on media node
Backups                      → independent disk + off-site copy
```

---

# 5. Application-by-application recommendations

## OpenProject

OpenProject publishes an official Helm chart, so it is a good K3s workload.

Recommended deployment:

```text
OpenProject web/workers → Kubernetes
PostgreSQL              → Kubernetes with persistent SSD storage
Attachments             → persistent volume
Redis                   → Kubernetes
```

Back up both:

- PostgreSQL database dumps;
- attachment storage.

---

## Jellyfin

I would run Jellyfin either:

- directly through Docker Compose on the media node; or
- in K3s but pinned permanently to the media node.

Example conceptual Kubernetes configuration:

```yaml
nodeSelector:
  feature: jellyfin-transcoding
```

Mount:

```text
/config         → SSD
/cache          → SSD
/media/movies   → large HDD
/media/tv       → large HDD
/dev/dri        → container, for Intel/AMD hardware acceleration
```

Do not replicate your full media library through Longhorn.

Back up Jellyfin configuration and metadata, but treat media backups according to how replaceable the files are.

---

## Cloud service

### Nextcloud

Nextcloud is the broadest option:

- file synchronization;
- calendar and contacts;
- WebDAV;
- sharing;
- collaborative applications;
- large application ecosystem.

It is PHP-based, not Python or Rust.

Choose Nextcloud when you want a complete personal collaboration platform.

### Seafile

Seafile is more focused on file synchronization and libraries.

Choose Seafile when you primarily want:

- fast file synchronization;
- large file collections;
- fewer collaboration features;
- a lighter operational footprint than a fully extended Nextcloud installation.

Although parts of Seafile’s ecosystem use Python, I would select it based on functionality and data architecture rather than implementation language.

### Rust-based options

There is not currently an obvious mature Rust-based product that completely replaces Nextcloud, including:

- desktop synchronization;
- mobile clients;
- file sharing;
- calendars;
- contacts;
- collaborative applications;
- a large plugin ecosystem.

For this service, prioritize:

1. reliable clients;
2. upgrade and migration procedures;
3. data recovery;
4. file-format independence;
5. community longevity.

My likely choice would be:

- **Seafile** for file synchronization only;
- **Nextcloud** for an integrated personal cloud.

---

## VPN service

Use **WireGuard** when you want a conventional VPN into your network.

Recommended layout:

```text
Internet
   │
Router UDP port forwarding
   │
WireGuard on infrastructure node
   │
Homelab LAN and private services
```

Run WireGuard directly on the host rather than inside Kubernetes.

This ensures that you can still reach the machines when Kubernetes is broken.

A more advanced alternative is **Headscale**, a self-hosted implementation of the Tailscale control server.

Use:

- plain WireGuard for simplicity and complete control;
- Headscale for easy mesh networking between laptops, servers, phones, and remote locations.

I would begin with WireGuard.

---

## Marimo

Marimo can be deployed in two different modes:

```text
marimo-edit
└── Private, VPN-only, persistent workspace

marimo-app-project-a
└── Read-only or restricted web application

marimo-app-project-b
└── Separate deployment and dependency image
```

Do not expose the editable server directly to the public Internet.

Put it behind authentication and preferably behind the VPN.

---

## Jupyter server

For a single trusted user, a normal JupyterLab container may be sufficient.

For several users, isolated environments, teaching, or configurable notebook images, use **JupyterHub**.

Suggested design:

```text
JupyterHub
├── Hub pod
├── Proxy
├── User pod: scientific Python
├── User pod: PyTorch/GPU
└── User pod: lightweight teaching environment
```

Store user home directories on persistent volumes and place temporary computation in ephemeral storage.

Set resource limits:

```yaml
singleuser:
  cpu:
    guarantee: 0.5
    limit: 4
  memory:
    guarantee: 1G
    limit: 8G
```

Do not run both an independent Jupyter server and JupyterHub unless they serve different purposes.

JupyterHub can become your primary Jupyter service.

---

## GitLab

GitLab is the application that most changes the architecture.

Its Kubernetes deployment is not a small single-container application. It requires several components and substantial resources.

For a 2–3-machine homelab, I suggest one of the following approaches.

### GitLab Omnibus on a dedicated VM

```text
GitLab VM
├── GitLab web
├── PostgreSQL
├── Redis
├── repositories
└── registry
```

Then optionally put GitLab Runner inside K3s.

This is the best compromise:

```text
GitLab application → VM or dedicated Docker host
GitLab CI runners  → K3s
```

### Lighter Git forge

When you do not specifically need GitLab’s complete ecosystem, consider:

- Forgejo;
- Gitea.

These provide Git hosting with a much smaller resource footprint.

For your machines, I would not initially deploy the complete cloud-native GitLab Helm chart.

---

# 6. Authentication

As the service list grows, use centralized authentication.

Possible identity-provider choices:

- Authentik;
- Keycloak;
- Authelia combined with an LDAP or OIDC provider.

A possible flow:

```text
Browser
   │
Ingress
   │
Authentication portal
   │
OIDC
   ├── OpenProject
   ├── Grafana
   ├── JupyterHub
   ├── GitLab
   └── Headscale
```

Do not add centralized authentication on day one.

First deploy two or three services, then introduce it once you understand their native authentication models.

---

# 7. GitOps and repository organization

Once the cluster works, manage it with Flux.

Flux keeps Kubernetes resources synchronized with configuration stored in Git, giving you a declarative and version-controlled cluster state.

Example repository:

```text
homelab/
├── clusters/
│   └── home/
│       ├── infrastructure/
│       └── applications/
├── infrastructure/
│   ├── cert-manager/
│   ├── ingress/
│   ├── metallb/
│   ├── longhorn/
│   ├── monitoring/
│   └── external-secrets/
├── applications/
│   ├── openproject/
│   ├── jupyterhub/
│   ├── marimo/
│   └── cloud/
└── docs/
    ├── architecture.md
    ├── disaster-recovery.md
    └── inventory.md
```

Do not store plaintext passwords in Git.

Initially, use SOPS with age encryption.

Later, you could add a secrets manager such as Vault, but Vault itself introduces substantial operational complexity.

---

# 8. Monitoring

Start with a modest stack:

```text
Prometheus       → metrics
Grafana          → dashboards
Loki             → logs
Alertmanager     → alerts
Uptime Kuma      → external-style availability checks
```

Monitor at minimum:

- node CPU;
- node RAM;
- temperatures;
- disk space;
- disk SMART status;
- Kubernetes pod restarts;
- certificate expiration;
- HTTP availability;
- PostgreSQL backup age;
- backup job success;
- UPS status;
- Internet connectivity;
- RAID, ZFS, or Btrfs health where applicable.

Keep monitoring lightweight initially.

Full Prometheus retention can consume considerable storage.

---

# 9. Backup design

Replication is not backup.

Use a 3-2-1-inspired structure:

```text
Primary data
    │
    ├── Local scheduled backup
    │      └── separate physical disk
    │
    └── Encrypted off-site backup
           └── S3-compatible provider or remote server
```

Suggested tools:

- Restic or Borg for files;
- native `pg_dump` for PostgreSQL;
- application-specific exports;
- K3s etcd snapshots;
- Velero for Kubernetes resources and selected persistent volumes.

Do not rely exclusively on volume snapshots.

For every database:

```text
Database backup = logical dump + volume-level backup
```

Your recovery documentation should explain how to rebuild the system from:

1. fresh Linux installations;
2. your GitOps repository;
3. encrypted secrets;
4. database dumps;
5. persistent file backups.

Test restoring one application before considering the backup strategy complete.

---

# 10. Network exposure policy

Divide services into three groups.

## Public services

Only expose services that genuinely require public access:

```text
Cloud file sharing
GitLab, when external collaborators need it
Public marimo applications
OpenProject, when clients need it
```

## VPN-only services

```text
JupyterHub
Editable marimo
Grafana
Prometheus
Longhorn UI
Kubernetes dashboard
Administration interfaces
SSH
```

## LAN-only services

```text
Jellyfin, unless remote streaming is required
Storage administration
Router and UPS interfaces
Internal databases
```

Never expose directly:

- Kubernetes API;
- etcd;
- PostgreSQL;
- Redis;
- Longhorn management UI;
- Prometheus;
- container runtime sockets.

---

# 11. Resource planning

A comfortable starting point would be approximately:

| Machine | Suggested role | CPU | RAM | Storage |
|---|---|---:|---:|---|
| Node 1 | Infrastructure | 4–8 cores | 16 GB | 500 GB SSD |
| Node 2 | Compute/apps | 8+ cores | 32–64 GB | 1 TB SSD/NVMe |
| Node 3 | Media/storage | 4–8 cores | 16–32 GB | SSD + large HDDs |

The RAM-heavy workloads will probably be:

- GitLab;
- Jupyter user environments;
- OpenProject;
- Nextcloud with many extensions;
- monitoring with long data retention.

Jellyfin depends more on media storage and hardware transcoding than RAM.

With less than approximately 48 GB of aggregate RAM, I would strongly consider replacing GitLab with a lighter forge or putting GitLab on a separate machine with strict resource limits.

---

# 12. Recommended implementation sequence

## Phase 1 — Hardware and base operating system

```text
Install Debian or Ubuntu
Configure static DHCP leases
Configure SSH keys
Configure firewall
Configure disk mounts
Configure SMART monitoring
Document hardware inventory
```

## Phase 2 — Private management access

```text
Install WireGuard on one host
Test remote access
Remove public SSH exposure
Configure internal DNS
```

## Phase 3 — Initial K3s cluster

```text
Install K3s
Configure three server nodes, or one server plus agents
Test node failure
Configure storage classes
Configure ingress
Configure cert-manager
```

## Phase 4 — First low-risk applications

Start with:

```text
Uptime Kuma
Marimo
A simple test web application
```

These applications will validate routing, TLS, persistence, and deployment procedures without risking critical data.

## Phase 5 — Stateful applications

Deploy:

```text
OpenProject
JupyterHub
Seafile or Nextcloud
```

For every application, create and test its backup before moving to the next one.

## Phase 6 — Hardware-sensitive and heavy applications

```text
Jellyfin on storage/media node
GitLab on dedicated VM or host
GitLab Runner on K3s
```

## Phase 7 — Operations

```text
Flux GitOps
Monitoring
Centralized logs
Encrypted off-site backups
Restore testing
Centralized authentication
```

---

# Final concrete recommendation

I would build the following architecture:

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

The central principle is:

> **Use Kubernetes to manage applications, but do not make Kubernetes the sole guardian of your data or your emergency access path.**
