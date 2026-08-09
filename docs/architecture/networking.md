# Networking and exposure

Status: Recommended

This page defines the host baseline, K3s networking components, private access path, and exposure policy for the homelab.

## Host and cluster baseline

Use the same minimal Linux distribution on every machine: Debian 13 or Ubuntu Server LTS. Configure static DHCP leases, consistent hostnames, SSH keys, automatic security updates, per-host firewalls, NTP synchronization, and a UPS where possible. The planned checklist belongs in [Phase 1 — base OS](../guides/phase-01-base-os.md).

Use K3s for the cluster:

```text
Three stable machines:
3 × K3s server/control-plane nodes
Embedded etcd
Workloads allowed on all nodes

Two machines:
1 × K3s server
1 × K3s agent
```

The two-machine design is not control-plane high availability, but it is simpler and more predictable than a two-member etcd deployment.

## Ingress and TLS

K3s includes Traefik by default. Keep it unless there is a strong reason to install ingress-nginx for Nginx semantics. Add cert-manager for TLS certificates.

Public applications can use placeholder names such as:

```text
cloud.example.net
projects.example.net
git.example.net
```

Private applications can use:

```text
jupyter.internal.example.net
marimo.internal.example.net
grafana.internal.example.net
```

Private applications should be reachable only through the VPN.

## Bare-metal service addresses

K3s ServiceLB may be enough initially. MetalLB is an alternative when services need addresses from a reserved LAN range. Keep that range outside the router's normal DHCP allocation.

## Private access

This lab uses **[Headscale](../apps/headscale.md)** for mesh VPN and home LAN access. Because the domestic ISP uses **IPv4 CGNAT**, the control plane runs on an OVH VPS behind Nginx (DNS-only Cloudflare hostname); the home PC joins as a subnet router for `<home-lan-cidr>`. Plain [WireGuard](../apps/wireguard.md) remains an alternative when inbound home port forwards are available. See [Phase 2 — VPN access](../guides/phase-02-vpn-access.md). Real LAN addresses live in gitignored `docs/inventory.local.md` and `docs/experiences/deployment-topology.local.md`.

## Cloudflare Tunnel and Access (alternate gate)

For selected applications (starting with [n8n](../apps/n8n.md)), Cloudflare Tunnel can publish HTTPS without opening inbound ports on the homelab. Cloudflare Access then enforces allowlisted users on the editor UI. This complements host-level WireGuard: WireGuard remains the break-glass admin path when the cluster or Cloudflare path is unavailable; Tunnel + Access is acceptable for app UIs that should not use Traefik/cert-manager public Ingress on day one.

## Exposure policy

Classify each service before deployment.

### Public

Expose only services that genuinely require public access:

- Cloud file sharing
- GitLab when external collaborators need it
- Public marimo applications
- OpenProject when clients need it

### VPN-only

- JupyterHub
- Editable marimo
- Grafana
- Prometheus
- Longhorn UI
- Kubernetes dashboard
- Administration interfaces
- SSH

### LAN-only

- Jellyfin unless remote streaming is required
- Storage administration
- Router and UPS interfaces
- Internal databases

### Never expose directly

- Kubernetes API
- etcd
- PostgreSQL
- Redis
- Longhorn management UI
- Prometheus
- Container runtime sockets

## See also

- [Architecture overview](overview.md)
- [Authentication](auth.md)
- [Monitoring](monitoring.md)
- [Phase 3 — K3s cluster](../guides/phase-03-k3s-cluster.md)
- [marimo](../apps/marimo.md)
