# OpenProject on k3s behind CGNAT with Cloudflare Tunnel

Date: 2026-07-22  
Status: Accepted

## Context

I wanted OpenProject on a dedicated home mini PC (~8 GB RAM / 4 CPUs, Ubuntu 24.04; LAN `<openproject-lan-ip>`) using **k3s**, while still reaching it from outside. My ISP line is **IPv4 CGNAT**, so classic port forwarding to the house is not an option. I already had Headscale on an OVH VPS and a subnet router on `<home-subnet-router-lan-ip>` advertising `<home-lan-cidr>`.

Real addresses live in gitignored `docs/inventory.local.md` and `docs/experiences/deployment-topology.local.md`.

## What I decided

- **App on home k3s** — matches the hybrid homelab plan (stateful app on a compute node).
- **Public URL** `https://projects.willyrv.com` via **Cloudflare Tunnel + Access** — tunnels are fine for OpenProject’s HTTP traffic (unlike Headscale, which must not sit behind Cloudflare Proxy/Tunnel).
- **Private path** — keep using Headscale: as long as `.12` is online with the LAN route approved, I can reach `.11` from outside **without** installing Tailscale on the OpenProject box.

I briefly considered only VPN access; I chose Tunnel + Access so collaborators get a normal HTTPS hostname with an identity gate before OpenProject’s own login.

## Bring-up highlights

1. Installed single-node **k3s** and fixed the usual `kubectl` → `localhost:8080` mistake by copying `/etc/rancher/k3s/k3s.yaml` to `~/.kube/config`.
2. Installed **Helm** with the official script (not snap).
3. Deployed OpenProject with the **official Helm chart**, ClusterIP on port **8080**, local-path disks, `OPENPROJECT_HOST__NAME=projects.willyrv.com`, and HTTPS flags set because Cloudflare terminates TLS.
4. Ran **cloudflared** as a Deployment in cluster, pointing the tunnel at `openproject.openproject.svc.cluster.local:8080`.
5. Put **Cloudflare Access** in front of the hostname.

## Snag: Access one-time PIN email

Access asked for my Gmail and showed the “enter your code” page, but the OTP never arrived (not just spam delay). Switching to **Google as the login method** for Access fixed it immediately. Lesson: for Gmail users, prefer Google IdP over emailed one-time pins.

## Outcome

`https://projects.willyrv.com` works: Access challenge, then OpenProject. The home node stays private to the LAN; the tunnel connector is the only path Cloudflare needs. VPN still covers break-glass and LAN tooling via `.12`.

## Follow-ups

- Documented restore for PostgreSQL + attachments.
- Uptime Kuma monitor for `projects.willyrv.com` (after Access, may need a bypass or tunnel health check).
- Pin chart/app versions and plan upgrades.

## See also

- Runbook: [OpenProject](../apps/openproject.md)
- [Headscale / CGNAT](../apps/headscale.md)
- [Experience: Headscale on OVH after CGNAT](2026-07-19-headscale-ovh-cgnat.md)
