# WireGuard

Status: Alternative

## Purpose

WireGuard provides conventional VPN access to the homelab network and private services. It preserves an administration path even when K3s is unavailable.

## Placement

If used, run WireGuard directly on a host rather than inside Kubernetes:

```text
Internet
   │
Router UDP port forwarding (requires a real public IPv4 — not CGNAT)
   │
WireGuard on infrastructure node
   │
Homelab LAN and private services
```

Keeping the VPN outside K3s ensures that cluster failures do not also remove remote access.

## WireGuard or Headscale

This lab chose **[Headscale](headscale.md)** (Tailscale clients + self-hosted control server) after discovering **IPv4 CGNAT** on the domestic ISP line. The control plane runs on an OVH VPS behind Nginx; the home PC acts as a subnet router for `<home-lan-cidr>`. Real LAN addresses live in gitignored `docs/inventory.local.md` and `docs/experiences/deployment-topology.local.md`.

Plain WireGuard remains a valid alternative when:

- the ISP provides inbound port forwarding on a public IPv4; and
- a small, manually managed peer set is enough.

## Backups and warnings

Back up host configuration and private keys in encrypted storage. Do not commit unencrypted private keys to this repository. On CGNAT, do not assume home router port forwards will work.

## See also

- [Headscale](headscale.md) — current Phase 2 VPN choice
- [Networking and exposure](../architecture/networking.md)
- [Phase 2 — VPN access](../guides/phase-02-vpn-access.md)
- [Experience: Headscale on OVH after CGNAT](../experiences/2026-07-19-headscale-ovh-cgnat.md)
