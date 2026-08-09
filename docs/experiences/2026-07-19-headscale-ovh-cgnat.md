# Headscale on OVH after discovering home CGNAT

Date: 2026-07-19  
Status: Accepted

## Context

I wanted a private VPN into my homelab: mesh between my own devices, plus access to the home LAN (`<home-lan-cidr>`). I already had a small Ubuntu Server PC at home with Headscale installed, a domain on Cloudflare (`headscale.willyrv.com`), and a domestic internet line. The handbook originally leaned toward host-level WireGuard or Headscale on that infrastructure machine, with router port forwards.

Real addresses live in gitignored `docs/inventory.local.md` and `docs/experiences/deployment-topology.local.md`.

## What I tried first

I followed a “Headscale at home” plan: DNS for `headscale.willyrv.com`, native Let’s Encrypt on the PC, and forwards for TCP 443, UDP WireGuard, and STUN.

On the Ubuntu box the basics looked fine — Headscale **v0.29.2** was active, the LAN address was `<home-subnet-router-lan-ip>`, and `curl` to public IP checkers returned an IPv4 address. I also learned how to verify DNS with `dig +short headscale.willyrv.com A` after creating the Cloudflare A record.

Then I opened the ISP router UI to set port forwards and hit a wall.

## The blocker: IPv4 CGNAT

The router reported something like **“IPv6 & IPv4 CGNAT”** and offered no useful port-forwarding. That means my ISP puts the home line behind carrier-grade NAT: outbound internet works, but I cannot reliably publish inbound services on IPv4 to the home PC.

So the original Approach 1 (control plane + DERP + WireGuard inbound on the home box) was not viable without buying a public IPv4 from the ISP or relying on fragile IPv6-only exposure.

## Pivot: control plane on the OVH VPS

I already had a small OVH VPS with Nginx and Certbot. Ports 80/443 were in use, which at first looked like a conflict with Headscale.

The workable pattern was:

1. Point `headscale.willyrv.com` (Cloudflare **DNS only**) at the **VPS** public IP — never orange-cloud / Tunnel for Headscale.
2. Run Headscale on the VPS listening on `127.0.0.1:8080` without terminating TLS itself.
3. Add an Nginx vhost for `headscale.willyrv.com` that reverse-proxies to Headscale, with WebSocket-friendly headers and a long read timeout, then run Certbot for that hostname alongside any other vhosts on the VPS.
4. Open **UDP 3478** on the VPS for embedded DERP STUN (host `ufw` and/or OVH network firewall).
5. Keep the **home** PC as a Tailscale client that **advertises** `<home-lan-cidr>` (subnet router), with IP forwarding enabled — no inbound ports required at home.

Sharing 443 with websites is normal: Nginx selects the backend by `server_name`. Headscale does not need exclusive ownership of the port.

## CLI surprise on Headscale v0.29

Older docs and my first draft plan mentioned `headscale routes …`. On **v0.29**, that top-level command is gone. Route listing and approval live under nodes:

```bash
headscale nodes list-routes
headscale nodes approve-routes --identifier NODE_ID --routes <home-lan-cidr>
```

Once I used those, approving the home LAN route worked.

## Outcome

The setup is working: clients log in against `https://headscale.willyrv.com` on the OVH VPS, and the home machine routes into `<home-lan-cidr>`.

Central lesson for this lab:

> On a CGNAT home line, put the Headscale control plane on a host with a real public IPv4 (here, the OVH VPS behind Nginx), and use the home PC as a subnet router — not as the publicly reachable coordination server.

## Follow-ups

- Keep Cloudflare grey-cloud for the Headscale hostname.
- Back up Headscale’s SQLite/config and Certbot material off the VPS.
- Later: tighter ACLs, optional exit node, DDNS only if the VPS IP ever becomes dynamic (it should not on OVH).
- Stop/disable the unused Headscale service on the home PC if it is still enabled, so only one control plane exists.

## See also

- Canonical runbook: [Headscale](../apps/headscale.md)
- [Phase 2 — VPN access](../guides/phase-02-vpn-access.md)
- Earlier architecture decision: [hybrid K3s](2026-07-18-architecture-decision.md)
