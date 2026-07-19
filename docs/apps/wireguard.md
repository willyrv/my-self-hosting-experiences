# WireGuard

Status: Recommended

## Purpose

WireGuard provides conventional VPN access to the homelab network and private services. It preserves an administration path even when K3s is unavailable.

## Placement

Run WireGuard directly on the infrastructure host rather than inside Kubernetes:

```text
Internet
   │
Router UDP port forwarding
   │
WireGuard on infrastructure node
   │
Homelab LAN and private services
```

Keeping the VPN outside K3s ensures that cluster failures do not also remove remote access.

## WireGuard or Headscale

Begin with plain WireGuard for simplicity and complete control. Headscale, a self-hosted implementation of the Tailscale control server, is a later alternative when you need easier mesh networking among laptops, servers, phones, and remote locations.

## Backups and warnings

Back up the host configuration and private keys in encrypted storage. Do not commit unencrypted private keys to this repository, and keep the router's UDP forwarding rule limited to the WireGuard endpoint.

## Planned

- Validate host installation and firewall rules on the selected Linux distribution.
- Document peer enrollment, key rotation, routing, and recovery.
- Test access to private services while K3s is stopped.

## See also

- [Networking and exposure](../architecture/networking.md)
- [Machine roles](../architecture/machine-roles.md)
- [Phase 2 — VPN access](../guides/phase-02-vpn-access.md)
