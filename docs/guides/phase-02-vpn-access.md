# Phase 2 — Private management access

Status: Planned

## Goal

Establish a private administration path that remains available when K3s is stopped or unhealthy, then remove public SSH exposure.

## Checklist

- Install WireGuard directly on the infrastructure host.
- Configure the router's UDP forwarding rule for the WireGuard endpoint.
- Enroll an initial remote peer and test access from outside the LAN.
- Confirm that the peer can reach host administration and intended private services.
- Remove public SSH exposure.
- Configure internal DNS for private service names.
- Back up the WireGuard configuration and private keys in encrypted storage.

## Details

Place WireGuard on the infrastructure host rather than in Kubernetes. This keeps emergency access independent of cluster networking, ingress, and application health. Limit the router forwarding rule to the VPN endpoint and keep SSH, the Kubernetes API, dashboards, and other administration interfaces private.

Begin with plain WireGuard for a small, controlled peer set. Headscale can be evaluated later if the lab needs easier mesh networking across many devices or sites. Document peer enrollment, key rotation, routes, and recovery as those procedures are validated.

Use internal DNS names for VPN-only services and decide each service's exposure class before deployment. Notebook editors, monitoring dashboards, storage administration, SSH, and Kubernetes administration should remain VPN-only even if authentication is added later. Never commit unencrypted WireGuard private keys to Git.

## Verify before next phase

- A remote peer connects through the public Internet and reaches all intended host addresses.
- Administration remains possible through WireGuard while K3s is stopped or absent.
- Public scans or router rules no longer expose SSH.
- Internal DNS resolves the planned private service names only through the intended private path.
- Encrypted recovery copies of the VPN configuration and keys exist outside the endpoint host.

## See also

- [WireGuard](../apps/wireguard.md)
- [Networking and exposure](../architecture/networking.md)
- [Machine roles](../architecture/machine-roles.md)

## Navigation

- Previous: [Phase 1 — base OS](phase-01-base-os.md)
- Next: [Phase 3 — K3s cluster](phase-03-k3s-cluster.md)
