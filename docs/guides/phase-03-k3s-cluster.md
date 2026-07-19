# Phase 3 — Initial K3s cluster

Status: Planned

## Goal

Build the initial K3s platform and validate control-plane behavior, workload routing, TLS, and the storage choices needed by later applications.

## Checklist

- Install K3s on the prepared hosts.
- Configure three server/control-plane nodes with embedded etcd, or one server plus agents for a smaller lab.
- Test the expected behavior during a node failure.
- Assign and document node roles and scheduling labels.
- Configure storage classes for the selected local, NFS, or replicated storage.
- Configure ingress.
- Configure cert-manager.
- Select K3s ServiceLB initially or reserve a LAN range for MetalLB.

## Details

For three stable machines, use three K3s server nodes with embedded etcd and allow workloads on all nodes. With only two machines, use one server and one agent; a two-member etcd deployment is not control-plane high availability.

Keep the default Traefik ingress controller unless Nginx-specific behavior is required. Add cert-manager for certificates. K3s ServiceLB is sufficient for an initial deployment; MetalLB is an alternative when services need addresses from a reserved LAN range outside the router's DHCP pool. Keep the Kubernetes API and administrative interfaces private.

Choose storage by workload instead of declaring one universal backend. Local persistent volumes are a simple initial choice for node-bound data, NFS suits shared notebooks and cloud files, and Longhorn is best reserved for data where block replication justifies its capacity and operational cost. Backups must remain independent of every storage class.

Node labels can express the planned roles. These commands are illustrative naming conventions from the architecture design:

```bash
kubectl label node node-1 role=infrastructure
kubectl label node node-2 role=compute
kubectl label node node-3 role=storage
kubectl label node node-3 feature=jellyfin-transcoding
```

Pair labels with selectors or affinity for workloads tied to local data or hardware.

## Verify before next phase

- All expected nodes report healthy and have their documented role labels.
- The cluster behaves as documented when one tested node becomes unavailable.
- A test workload receives persistent storage from each storage class intended for early applications.
- A test service is reachable through ingress at its intended private or public route.
- cert-manager can issue and renew a test certificate through the selected issuer path.
- Cluster administration remains reachable only through the LAN or VPN.

## See also

- [Architecture overview](../architecture/overview.md)
- [Storage strategy](../architecture/storage.md)
- [Networking and exposure](../architecture/networking.md)
- [Machine roles](../architecture/machine-roles.md)

## Navigation

- Previous: [Phase 2 — VPN access](phase-02-vpn-access.md)
- Next: [Phase 4 — low-risk apps](phase-04-low-risk-apps.md)
