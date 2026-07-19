# Machine roles

Status: Recommended

This page assigns infrastructure, compute, and storage responsibilities across a three-machine homelab.

## Machine 1 — Infrastructure node

```text
K3s server
Ingress controller
cert-manager
DNS-related services
Monitoring
VPN endpoint or Headscale
```

Use an SSD and, ideally, a UPS.

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

## Scheduling labels

Even when all three computers are K3s servers, labels and node affinity can keep workloads near required data and hardware:

```bash
kubectl label node node-1 role=infrastructure
kubectl label node node-2 role=compute
kubectl label node node-3 role=storage
kubectl label node node-3 feature=jellyfin-transcoding
```

These labels are illustrative naming conventions, not an install runbook. Workload selectors and affinity rules should prevent Kubernetes from placing hardware-dependent applications arbitrarily.

## See also

- [Architecture overview](overview.md)
- [Resource planning](resources.md)
- [Storage strategy](storage.md)
- [Phase 1 — base OS](../guides/phase-01-base-os.md)
- [Jellyfin](../apps/jellyfin.md)
- [JupyterHub](../apps/jupyterhub.md)
