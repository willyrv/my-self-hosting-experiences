# Phase 2 — Private management access

Status: Recommended

## Goal

Establish a private administration path that remains available when K3s is stopped or unhealthy, then keep SSH and other admin interfaces off the public Internet.

## Checklist

- Confirm whether the home ISP allows inbound IPv4 (watch for **CGNAT**).
- If CGNAT (this lab): run **Headscale** on a VPS with a public IP; put Nginx + Certbot in front; DNS-only on Cloudflare.
- Join the home infrastructure PC as a Tailscale client and advertise `192.168.1.0/24`.
- Approve the subnet route in Headscale (`nodes approve-routes` on v0.29+).
- Enroll a remote peer off the home LAN and test LAN reachability.
- Remove or avoid public SSH exposure.
- Configure private naming (MagicDNS / internal DNS) for VPN-only services.
- Back up Headscale config/DB and TLS material off-box (encrypted).

## Details

This lab’s validated path is documented in [Headscale](../apps/headscale.md): control plane on an OVH VPS behind Nginx, home PC as subnet router. Domestic **IPv4 CGNAT** blocked the earlier idea of hosting Headscale (or plain WireGuard) with router port forwards on the home line.

Keep the VPN outside Kubernetes so emergency access does not depend on the cluster. Do not put Headscale behind Cloudflare Proxy or Tunnel. Prefer DNS-only records for the coordination hostname.

Use internal or MagicDNS names for VPN-only services. Notebook editors, monitoring dashboards, storage administration, SSH, and Kubernetes administration should remain VPN-only even if an identity provider is added later. Never commit preauth keys or private keys to Git.

Plain [WireGuard](../apps/wireguard.md) remains an alternative if a real public IPv4 and a tiny peer set are enough.

## Verify before next phase

- A remote client joins `https://headscale.willyrv.com` (or your login server) from outside the home LAN.
- The client can reach intended hosts on `192.168.1.0/24` with `--accept-routes`.
- Administration remains possible while K3s is stopped or absent.
- Public exposure of SSH is removed or never enabled.
- Encrypted recovery copies of Headscale/TLS configuration exist outside the VPS.

## See also

- [Headscale](../apps/headscale.md)
- [WireGuard](../apps/wireguard.md)
- [Networking and exposure](../architecture/networking.md)
- [Experience: Headscale on OVH after CGNAT](../experiences/2026-07-19-headscale-ovh-cgnat.md)

## Navigation

- Previous: [Phase 1 — base OS](phase-01-base-os.md)
- Next: [Phase 3 — K3s cluster](phase-03-k3s-cluster.md)
