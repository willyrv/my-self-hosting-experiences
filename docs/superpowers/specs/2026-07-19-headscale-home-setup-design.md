# Headscale home setup — design

Date: 2026-07-19  
Status: Approved for planning

## Purpose

Configure a self-hosted **Headscale** control server on an existing Ubuntu Server PC so personal devices form a mesh VPN and can reach the home LAN (`<home-lan-cidr>`). The public hostname is `headscale.willyrv.com` (Cloudflare DNS). The ISP public IP may be dynamic.

This replaces the earlier “start with plain WireGuard” Phase 2 default for this lab with Headscale, while keeping the VPN **on the host** (not inside Kubernetes).

## Goals

- Headscale reachable at `https://headscale.willyrv.com` with valid Let’s Encrypt certificates.
- Headscale terminates TLS itself (no reverse proxy).
- Cloudflare DNS for the hostname is **DNS-only** (grey cloud); never Cloudflare Proxy or Tunnel for Headscale.
- Dynamic public IP kept in sync via Cloudflare API DDNS from the Headscale host.
- Router port-forwards the required TCP/UDP ports to the Ubuntu PC.
- Official Tailscale clients join the private coordination server.
- The Headscale host advertises `<home-lan-cidr>` as a subnet router so remote clients can reach the LAN.
- Document the validated setup in this repository (no secrets in git).

## Non-goals

- Reverse proxy (Caddy/Nginx) in front of Headscale.
- Cloudflare orange-cloud proxy or Cloudflare Tunnel for the control plane.
- Exit node configuration.
- Complex ACLs / OIDC / SSO (beyond a single user and default allow).
- Running Headscale inside K3s.
- Multi-site DERP on a separate VPS (deferred unless home NAT proves insufficient).

## Decisions (approved)

| Topic | Choice |
|-------|--------|
| Primary use | Mesh between devices **and** LAN access (`<home-lan-cidr>`) |
| DNS exposure | Cloudflare **DNS only** + DDNS |
| TLS | Headscale built-in Let’s Encrypt |
| Topology | Single home node (Approach 1) |
| LAN CIDR | `<home-lan-cidr>` |

### Why no reverse proxy

Headscale documents reverse proxies for shared port 443, but warns they add Tailscale Control Protocol / WebSocket complexity and asks operators to test without a proxy before filing issues. Cloudflare Proxy/Tunnel is explicitly unsupported. For a dedicated Headscale host, native TLS is the preferred path.

## Architecture

```text
Internet clients (Tailscale app)
        │
        │  DNS: headscale.willyrv.com  (Cloudflare DNS-only)
        │  A record maintained by host DDNS (Cloudflare API)
        ▼
Home router (public IP, possibly dynamic)
        │
        ├── TCP 443      → Ubuntu PC :443   (Headscale HTTPS + ACME)
        ├── UDP 41641    → Ubuntu PC :41641 (WireGuard; confirm in config)
        └── UDP 3478     → Ubuntu PC :3478  (STUN for embedded DERP)
        ▼
Ubuntu PC (Headscale + embedded DERP + subnet router)
        │
        └── advertises <home-lan-cidr> to the tailnet
```

## Component design

### Headscale

- `server_url: https://headscale.willyrv.com`
- Let’s Encrypt hostname: `headscale.willyrv.com`
- Empty/disabled separate TLS cert paths when using ACME (per installed Headscale version’s config schema)
- Public HTTPS listen (typically `:443`)
- Fixed WireGuard port (default plan: `41641`) for stable router forwarding
- Embedded DERP enabled; STUN on `udp/3478`
- Metrics and gRPC remain localhost-only
- One Headscale user for personal devices; nodes via preauth keys and/or interactive login

Exact config keys depend on the installed Headscale version; the implementation plan must map these requirements to that version’s `config.yaml` schema.

### Cloudflare DNS + DDNS

- A record for `headscale.willyrv.com` pointing at the current public IPv4 address
- Proxy status: **DNS only**
- API token: zone DNS edit only (least privilege)
- DDNS updater runs on the Ubuntu PC and refreshes the A record when the public IP changes

### Host networking

- Enable IPv4 forwarding on the Ubuntu PC
- Host firewall allows inbound TCP 443, UDP 41641, UDP 3478 from WAN (and established/related); deny other unsolicited WAN ingress
- Register this host as a Tailscale/Headscale node
- Advertise route `<home-lan-cidr>` and approve it in Headscale

### Clients

- Official Tailscale clients with `--login-server=https://headscale.willyrv.com` (or equivalent UI setting)
- Validate with at least one client **outside** the home network

## Implementation sequence

1. Confirm inbound reachability is possible (not hard-NATed / CGNAT without port forwards).
2. Create DNS-only A record + install/configure Cloudflare DDNS on the host.
3. Configure router port forwards (TCP 443, UDP 41641, UDP 3478).
4. Configure and start Headscale with native ACME; open host firewall.
5. Create user and credentials; join server node; enable forwarding; advertise and approve `<home-lan-cidr>`.
6. Enroll a remote client; verify mesh + LAN access.
7. Update repository docs (`docs/apps/headscale.md`, experience note, Phase 2 / WireGuard cross-links). Commit no secrets.

## Verification criteria

- `https://headscale.willyrv.com` presents a valid certificate and Headscale responds.
- A remote Tailscale client joins the tailnet and sees registered nodes.
- From that client, a host on `<home-lan-cidr>` is reachable.
- After a public IP change (or forced DDNS refresh), DNS updates and clients can reconnect.

## Documentation deliverables

- `docs/apps/headscale.md` — canonical how/why for this lab’s Headscale deployment
- Update `docs/apps/wireguard.md` and `docs/guides/phase-02-vpn-access.md` to point to Headscale as the chosen Phase 2 path
- `docs/experiences/YYYY-MM-DD-headscale-home-setup.md` — dated notes from the live configuration
- No API tokens, preauth keys, private keys, or real inventory IPs in git (use placeholders)

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| CGNAT / ISP blocks inbound | Test port forwards early; fall back to VPS DERP or VPS-hosted Headscale only if needed |
| Dynamic IP lag | DDNS with short TTL; document client reconnect after IP change |
| Misconfigured WebSockets if proxy added later | Keep native TLS; do not introduce Cloudflare proxy |
| Accidental LAN exposure | Advertise only `<home-lan-cidr>`; no exit node in v1; tighten ACLs later if needed |

## Success criteria

- Approach 1 is running and verified from outside the home network.
- Docs in this repo describe the setup without secrets.
- Phase 2 guidance reflects Headscale as the active choice for this lab.

## Implementation next step

After this spec is reviewed and approved, produce an implementation plan via the writing-plans skill (host configuration steps + documentation updates), then execute with operator access to the Ubuntu PC and Cloudflare account.
