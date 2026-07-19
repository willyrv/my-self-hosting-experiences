# Architecture decision: hybrid K3s

Date: 2026-07-18
Status: Accepted

## Context

I want a self-hosting setup on two or three computers that can grow toward JupyterHub, OpenProject, marimo, media, and related services. Pure Docker Compose is simple, but configuration tends to fragment. Putting absolutely everything in Kubernetes makes storage, GitLab, and hardware-bound media workloads harder than they need to be on a small cluster.

## Decision

Adopt a **hybrid homelab architecture**:

- K3s for web applications and computational workloads
- Host-level (or node-pinned) services for storage-sensitive and hardware-sensitive apps
- Infrastructure managed through Git later (Flux in a separate repo)
- Off-site backups independent of the cluster

Central principle: use Kubernetes to manage applications, but do not make Kubernetes the sole guardian of data or emergency access.

## Alternatives considered

1. **Docker Compose on each machine** — best for simplicity; weak rescheduling and standardization.
2. **Everything on K3s** — one deployment model; distributed storage and heavy apps (GitLab, Jellyfin HA paths) dominate the operational cost too early.
3. **Hybrid K3s (chosen)** — Kubernetes where it helps; WireGuard/Jellyfin/GitLab Omnibus (or a lighter forge) kept outside or carefully pinned.

## Consequences

- Documentation is organized as architecture (why), phase guides (how), and app notes (depth).
- WireGuard stays on the host so cluster breakage does not remove remote admin access.
- Initial storage favors local PVs / NFS over rushing into Longhorn for multi-terabyte media.
- This docs repository does not yet hold Flux manifests; see [GitOps layout](../architecture/gitops-layout.md).

## See also

- [Architecture overview](../architecture/overview.md)
- [Architecture options](../architecture/options.md)
- Original working note: [`self_hosting_k3s_architecture.md`](../../self_hosting_k3s_architecture.md)
