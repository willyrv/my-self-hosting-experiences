# Uptime Kuma VPN monitoring — design

Date: 2026-07-20  
Status: Approved for planning

## Purpose

Monitor availability of the Headscale-based remote-access path and detect unauthorized or abusive traffic against the public Headscale endpoint.

## Goals

1. **Headscale availability** — know when `https://headscale.willyrv.com` (control plane via Nginx) is down.
2. **Home bridge availability** — know when the home Ubuntu PC is offline on the tailnet (so LAN access via subnet router would fail).
3. **Abuse / unauthorized attempts** — alert on:
   - suspicious HTTP traffic to the Headscale vhost (Nginx): scanners, path probing, 4xx floods;
   - Headscale auth/registration failures (invalid/expired keys, rejected joins).
4. Document the setup in this repository (no secrets in git).

## Decisions (approved)

| Topic | Choice |
|-------|--------|
| Availability tool | Uptime Kuma on the OVH VPS (Docker) |
| Home check method | Tailscale ping/TCP from the VPS to the home PC’s Tailscale IP |
| Abuse monitoring | CrowdSec on Nginx **and** Headscale journal/auth failure alerts |
| Kuma exposure | **Public long-term** (`status.willyrv.com` or similar), not VPN-only |
| Alert channel | ntfy and/or Telegram (same channel for Kuma + CrowdSec/log alerts) |

## Architecture

```text
OVH VPS
├── Headscale (:8080 localhost) + Nginx (:443)
├── Tailscale client → joins same Headscale tailnet (probe node only)
├── Uptime Kuma (Docker) — PUBLIC via Nginx + Certbot
│     ├── Monitor 1: HTTPS https://headscale.willyrv.com/health
│     └── Monitor 2: Ping/TCP to home PC Tailscale IP (100.x)
└── CrowdSec (+ firewall bouncer) + Headscale log watcher
      ├── Nginx logs for headscale.willyrv.com (and status vhost)
      └── journalctl -u headscale → auth/registration failure alerts

Home PC
└── Tailscale always on + subnet router <home-lan-cidr>
```

## Component design

### Uptime Kuma (public)

- Deploy with Docker on the OVH VPS.
- Expose via Nginx + Certbot on a dedicated hostname (e.g. `status.willyrv.com`), Cloudflare **DNS only**.
- **Public long-term** (operator preference): the status UI remains reachable from the Internet.
- Hardening for public exposure:
  - strong unique admin password (and 2FA if/when Kuma supports it in the installed version);
  - do not reuse Headscale or host passwords;
  - optionally restrict which monitor details appear on any public status page;
  - include the status vhost in CrowdSec/Nginx protection;
  - keep Kuma’s data volume backed up; treat session cookies as sensitive.
- Monitors:
  1. HTTPS GET `https://headscale.willyrv.com/health` (expect success).
  2. ICMP ping and/or TCP check to the home node’s Tailscale IP (from VPS, which must be on the same tailnet).
- Notifications: ntfy topic and/or Telegram bot on down/up.

### VPS Tailscale client

- Join `https://headscale.willyrv.com` as a normal node.
- Do **not** advertise subnet routes or exit-node unless intentionally required later.
- Purpose: allow Kuma on the VPS to reach the home PC over the tailnet.

### CrowdSec (Nginx abuse)

- Install CrowdSec with Nginx collection on the VPS.
- Ensure logs for `headscale.willyrv.com` (and the public status vhost) are parsed.
- Enable a firewall bouncer so repeated offenders can be blocked at the host.
- Notify on bans / relevant alerts via the same channel as Kuma when practical.

### Headscale auth/registration failures

- Watch `journalctl -u headscale` (or Headscale log file) for patterns such as invalid/expired/unknown auth key and rejected registration.
- v1: script or simple log shipper → ntfy/Telegram on threshold (e.g. N events in M minutes).
- Later: optional CrowdSec custom scenario if the script proves noisy or insufficient.
- Out of scope for classification: benign DERP/Noise protocol noise; focus on HTTP edge + registration/auth failures.

## Implementation sequence

1. Join OVH VPS to Headscale (probe client).
2. Install Uptime Kuma (Docker); Nginx + Certbot for public `status.*` hostname.
3. Configure monitors + notification channel; verify alert paths.
4. Install CrowdSec + Nginx collection + bouncer; verify against Headscale (and status) vhosts.
5. Add Headscale journal watcher → same notification channel.
6. Document in repo: `docs/apps/uptime-kuma.md`, abuse/CrowdSec notes (or section), experience entry.

## Verification criteria

- Stopping Headscale or breaking `/health` triggers Kuma alert; recovery clears it.
- Disconnecting home Tailscale triggers home-monitor alert; recovery clears it.
- Controlled probe of scanner-like requests or a bad auth attempt produces CrowdSec and/or Headscale-log notification without locking out the operator’s admin access.
- Public Kuma URL loads over HTTPS with admin login required for configuration.

## Documentation deliverables

- `docs/apps/uptime-kuma.md` — canonical runbook (public exposure + hardening called out).
- Cross-links from `docs/apps/headscale.md` and Phase 4 / monitoring architecture pages as appropriate.
- `docs/experiences/YYYY-MM-DD-uptime-kuma-vpn-monitoring.md` — first-person bring-up notes.
- No tokens, webhook URLs with secrets, or passwords in git.

## Non-goals (v1)

- Full Prometheus / Grafana / Loki stack.
- VPN-only restriction of Kuma (explicitly rejected — Kuma stays public).
- Perfect IDS for all Tailscale protocol errors.
- Automatic remediation beyond CrowdSec bans for HTTP abuse.

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Public Kuma UI attacked or credential-stuffed | Strong password; CrowdSec on status vhost; keep software updated; no password reuse |
| False positives on Headscale logs | Thresholds; whitelist operator IPs in CrowdSec where needed |
| VPS Tailscale down → false “home down” | Separate Headscale `/health` monitor; document dependency |
| Lockout via CrowdSec ban of own IP | Whitelist; console/OVH rescue path; careful test probes |

## Success criteria

- Both availability monitors and both abuse signals are live with notifications.
- Operator can see Headscale and home-bridge status from outside without VPN.
- Docs in this repo describe the setup without secrets.

## Implementation next step

After this spec is reviewed, produce an implementation plan via the writing-plans skill, then execute (guided on the OVH VPS / home PC as needed).
