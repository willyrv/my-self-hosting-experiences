# Watching the VPN path with Uptime Kuma

Date: 2026-07-20  
Status: Accepted

## Context

After moving Headscale to the OVH VPS (because of home IPv4 CGNAT) and using the home Ubuntu PC as a Tailscale subnet router into `192.168.1.0/24`, I wanted something simple to answer two questions when I’m away:

1. Is Headscale on the VPS up?
2. Is the home PC still on the tailnet (so I can reach the LAN)?

I also wanted visibility into abuse: noisy scanners on the public Headscale hostname, and failed join/auth attempts against Headscale.

## Why not Rancher + K3s on the VPS

I considered deploying the monitoring stack with K3s and Rancher on OVH, since I expect more services there later. For a small VPS that already runs Nginx and Headscale, that felt like the wrong next step: Rancher is heavy, and if availability tooling only lives inside a cluster on the same box, a cluster/ingress failure can take down both the control plane path and the alerts.

I stuck with **Docker Compose + the existing Nginx** for Uptime Kuma. Kubernetes (and maybe a lighter UI than full Rancher) still belongs in the longer-term home lab plan.

## What I deployed

On the OVH VPS:

1. **Joined Tailscale** to my Headscale instance as a probe node (`100.64.0.2`), without needing `--accept-routes` just to ping the home node.
2. Confirmed the home bridge (`nuc2-ingress` at `100.64.0.1`) answered ICMP over the tailnet.
3. Ran **Uptime Kuma** in Docker, published only on `127.0.0.1:3001`, and put **Nginx + Certbot** in front at `https://status.willyrv.com` (Cloudflare DNS-only).
4. Kept the status UI **public on purpose**, with a strong unique admin password — handy from anywhere, with the understanding that the UI needs the same edge hygiene as any other public admin surface.

Monitors that matter:

- HTTP(s) → `https://headscale.willyrv.com/health`
- Ping (or TCP if Docker bridge blocks ICMP) → `100.64.0.1`

Notifications go out through ntfy/Telegram so a Headscale outage or a dead home bridge wakes me up.

## Abuse monitoring (same design pass)

Availability alone is not enough on a public coordination URL. The plan also includes:

- **CrowdSec** on Nginx for `headscale.willyrv.com` and `status.willyrv.com`
- A small **journal watcher** on `headscale.service` for invalid/expired auth keys and rejected registrations, alerting on a threshold

Those sit beside Kuma rather than replacing it: Kuma answers “is it up?”, CrowdSec/logs answer “is someone hammering the door?”.

## Outcome

The availability side is working: I can open `status.willyrv.com` from outside, see Headscale and the home bridge, and get alerts when something drops.

Lesson for this lab:

> For VPN path health on a small multi-site setup, prefer a tiny public checker next to Headscale (Compose + Nginx) over putting monitoring behind a new Kubernetes control plane on the same VPS.

## Follow-ups

- Finish hardening CrowdSec whitelists and the Headscale auth-watch timer if not already live.
- Back up the Kuma Docker volume.
- Later: richer metrics (Prometheus/Grafana) on the home cluster — not required for this VPN heartbeat.

## See also

- Runbook: [Uptime Kuma](../apps/uptime-kuma.md)
- [Headscale](../apps/headscale.md)
- [Experience: Headscale on OVH after CGNAT](2026-07-19-headscale-ovh-cgnat.md)
- Design: `docs/superpowers/specs/2026-07-20-uptime-kuma-vpn-monitoring-design.md`
