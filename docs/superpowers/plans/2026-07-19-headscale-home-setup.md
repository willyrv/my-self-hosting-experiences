# Headscale Home Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring up Headscale on the existing Ubuntu Server PC at `https://headscale.willyrv.com` with native Let’s Encrypt, Cloudflare DNS-only + DDNS, mesh VPN, and subnet routing for `<home-lan-cidr>`, then document it in this repository.

**Architecture:** Single home node terminates TLS itself (no reverse proxy). Cloudflare grey-cloud A record tracks a dynamic public IP. Router forwards TCP 443, UDP 41641, and UDP 3478. Embedded DERP + STUN; host advertises `<home-lan-cidr>`. Official Tailscale clients use `--login-server=https://headscale.willyrv.com`.

**Tech Stack:** Headscale (DEB preferred), Tailscale clients, Cloudflare DNS API DDNS, Ubuntu Server firewall (`ufw` or `nftables`), systemd.

## Global Constraints

- Hostname: `headscale.willyrv.com` (Cloudflare-managed).
- Cloudflare: **DNS only** (grey cloud). Never Proxy or Tunnel for Headscale.
- TLS: Headscale native Let’s Encrypt; **no reverse proxy**.
- Challenge type: `TLS-ALPN-01` with `listen_addr: 0.0.0.0:443` (avoids needing WAN TCP 80).
- LAN route to advertise: `<home-lan-cidr>`.
- WireGuard client/default port assumption: UDP `41641` (`randomize_client_port: false`).
- STUN for embedded DERP: UDP `3478`.
- MagicDNS `dns.base_domain` must **differ** from the Headscale hostname domain — use `ts.willyrv.com` (or another unused subdomain under `willyrv.com`).
- No secrets in git (API tokens, preauth keys, private keys, real public IPs).
- VPN stays on the host, not in Kubernetes.
- Map config keys to the **installed** Headscale version’s schema (`/usr/share/doc/headscale/examples/config-example.yaml` or upstream example for that version).

## File Structure (repository)

| Path | Responsibility |
|------|----------------|
| `docs/apps/headscale.md` | Canonical Headscale runbook for this lab |
| `docs/apps/wireguard.md` | Point to Headscale as chosen Phase 2 path |
| `docs/guides/phase-02-vpn-access.md` | Phase 2 checklist updated for Headscale |
| `docs/architecture/networking.md` | Brief Headscale pointer if needed |
| `docs/experiences/YYYY-MM-DD-headscale-home-setup.md` | Dated live setup notes |
| Host paths (not in git) | `/etc/headscale/config.yaml`, DDNS unit/config, firewall |

## Operator note

Tasks 1–5 run on the Ubuntu Headscale host and home router/Cloudflare account. The coding agent cannot complete them without your shell access; execute them with the operator (guided) or paste command output back. Tasks 6–7 update this git repository after the service works.

---

### Task 1: Preflight — reachability, DNS, port forwards

**Files:**
- None in git
- Operator: Cloudflare DNS, home router, Ubuntu host

**Interfaces:**
- Consumes: public IP of home connection; Cloudflare zone `willyrv.com`
- Produces: DNS-only A record for `headscale.willyrv.com`; router forwards ready; confirmed not hard-CGNAT (or documented blocker)

- [ ] **Step 1: Discover current public IPv4 on the Ubuntu PC**

```bash
curl -4 -s https://ifconfig.me; echo
curl -4 -s https://api.ipify.org; echo
```

Record the address locally (do not commit it).

- [ ] **Step 2: Create Cloudflare DNS A record**

In Cloudflare DNS for `willyrv.com`:

- Type: `A`
- Name: `headscale`
- Content: current public IPv4
- Proxy status: **DNS only** (grey cloud)
- TTL: Automatic or 5 minutes

Verify:

```bash
dig +short headscale.willyrv.com A
```

Expected: the same public IPv4 (not a Cloudflare anycast proxy IP).

- [ ] **Step 3: Confirm inbound port forwarding is possible**

From the router admin UI, prepare forwards to the Ubuntu PC’s **LAN** IP (static DHCP lease recommended):

| WAN proto/port | LAN target |
|----------------|------------|
| TCP 443 | `<headscale-lan-ip>:443` |
| UDP 41641 | `<headscale-lan-ip>:41641` |
| UDP 3478 | `<headscale-lan-ip>:3478` |

If the WAN address is in CGNAT (`100.64.0.0/10` or ISP says no inbound), **stop** and escalate — Approach 1 cannot work without a public inbound path.

- [ ] **Step 4: Commit checkpoint (optional operator note only)**

No git commit required. If blocked by CGNAT, write that into the experience note later and do not proceed to Task 2.

---

### Task 2: Configure and start Headscale with native TLS

**Files:**
- Host: `/etc/headscale/config.yaml` (and systemd/unit capabilities as needed)
- Reference: installed example config

**Interfaces:**
- Consumes: working DNS A record from Task 1
- Produces: `https://headscale.willyrv.com/health` OK with valid certificate

- [ ] **Step 1: Confirm Headscale package and version**

```bash
headscale version
systemctl status headscale --no-pager || true
ls -la /etc/headscale/config.yaml
```

If missing, install the official `.deb` from [Headscale releases](https://github.com/juanfont/headscale/releases) per https://headscale.net/stable/setup/install/official/

- [ ] **Step 2: Back up the current config**

```bash
sudo cp -a /etc/headscale/config.yaml "/etc/headscale/config.yaml.bak.$(date +%Y%m%d)"
```

- [ ] **Step 3: Apply production settings**

Edit `/etc/headscale/config.yaml` so these values are set (merge into the full example; do not delete unrelated required keys). Adjust paths if your package differs:

```yaml
server_url: https://headscale.willyrv.com

listen_addr: 0.0.0.0:443
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 127.0.0.1:50443

# ACME / native TLS (TLS-ALPN-01 — matches design port list, no WAN :80)
acme_email: "YOUR_EMAIL@example.com"   # operator email for Let’s Encrypt
tls_letsencrypt_hostname: headscale.willyrv.com
tls_letsencrypt_cache_dir: /var/lib/headscale/cache
tls_letsencrypt_challenge_type: TLS-ALPN-01
tls_cert_path: ""
tls_key_path: ""

derp:
  server:
    enabled: true
    region_id: 999
    region_code: "home"
    region_name: "Home Embedded DERP"
    stun_listen_addr: "0.0.0.0:3478"
    automatically_add_embedded_derp_region: true
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  auto_update_enabled: true

dns:
  magic_dns: true
  # MUST differ from headscale.willyrv.com's parent usage for MagicDNS hostnames
  base_domain: ts.willyrv.com
  override_local_dns: false
  nameservers:
    global:
      - 1.1.1.1
      - 1.0.0.1

randomize_client_port: false
```

Create ACME cache dir if needed:

```bash
sudo mkdir -p /var/lib/headscale/cache
sudo chown -R headscale:headscale /var/lib/headscale
```

- [ ] **Step 4: Allow binding privileged port 443**

Headscale’s systemd service typically runs as user `headscale`. Grant bind capability to the binary (path may vary):

```bash
HEADSCALE_BIN="$(command -v headscale)"
sudo setcap 'cap_net_bind_service=+ep' "$HEADSCALE_BIN"
getcap "$HEADSCALE_BIN"
```

If `setcap` is reset on package upgrade, re-apply or use a systemd `AmbientCapabilities=CAP_NET_BIND_SERVICE` drop-in:

```bash
sudo mkdir -p /etc/systemd/system/headscale.service.d
sudo tee /etc/systemd/system/headscale.service.d/override.conf <<'EOF'
[Service]
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
EOF
sudo systemctl daemon-reload
```

- [ ] **Step 5: Open host firewall**

Example with `ufw`:

```bash
sudo ufw allow 443/tcp comment 'headscale-https'
sudo ufw allow 41641/udp comment 'tailscale-wireguard'
sudo ufw allow 3478/udp comment 'headscale-stun'
sudo ufw status numbered
```

- [ ] **Step 6: Restart and verify Headscale**

```bash
sudo systemctl enable --now headscale
sudo systemctl restart headscale
sudo systemctl status headscale --no-pager
journalctl -u headscale -n 80 --no-pager
```

Expected: service active; logs show TLS/ACME success (not repeated bind/ACME failures).

- [ ] **Step 7: Health check from the host and (if possible) from the Internet**

```bash
curl -fsS https://headscale.willyrv.com/health
echo
```

Expected: HTTP 200 / healthy response with a valid public certificate (browser or `curl -v` shows Let’s Encrypt).

If ACME fails: confirm DNS-only A record, WAN TCP 443 forward, and that nothing else binds `:443` (`sudo ss -tlnp | grep ':443'`).

---

### Task 3: Cloudflare DDNS on the Headscale host

**Files:**
- Host: DDNS tool config + systemd timer/service (not committed)
- Optional local secrets file outside git

**Interfaces:**
- Consumes: Cloudflare API token (DNS edit for zone `willyrv.com` only)
- Produces: A record updates when public IP changes

- [ ] **Step 1: Create a Cloudflare API token**

Permissions: Zone → DNS → Edit, limited to zone `willyrv.com`. Store the token only on the host (e.g. `/etc/headscale/cloudflare-ddns.env` mode `600`).

- [ ] **Step 2: Install a small DDNS updater**

Preferred options (pick one):

1. `timothymiller/cloudflare-ddns` container, or
2. A simple script + systemd timer using Cloudflare API v4

Minimal script approach (`/usr/local/sbin/cloudflare-ddns.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source /etc/headscale/cloudflare-ddns.env
# Required env: CF_API_TOKEN, CF_ZONE_ID, CF_RECORD_NAME=headscale.willyrv.com
IPV4="$(curl -4 -fsS https://api.ipify.org)"
RECORD_ID="$(curl -fsS -X GET \
  "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?type=A&name=${CF_RECORD_NAME}" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json" \
  | python3 -c 'import sys,json; r=json.load(sys.stdin); print(r["result"][0]["id"])')"
curl -fsS -X PUT \
  "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json" \
  --data "{\"type\":\"A\",\"name\":\"${CF_RECORD_NAME}\",\"content\":\"${IPV4}\",\"ttl\":300,\"proxied\":false}" \
  >/dev/null
echo "Updated ${CF_RECORD_NAME} -> ${IPV4} (proxied=false)"
```

```bash
sudo chmod 700 /usr/local/sbin/cloudflare-ddns.sh
sudo chmod 600 /etc/headscale/cloudflare-ddns.env
```

- [ ] **Step 3: systemd timer every 5 minutes**

`/etc/systemd/system/cloudflare-ddns.service`:

```ini
[Unit]
Description=Update Cloudflare DNS for headscale.willyrv.com
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/cloudflare-ddns.sh
```

`/etc/systemd/system/cloudflare-ddns.timer`:

```ini
[Unit]
Description=Run Cloudflare DDNS every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now cloudflare-ddns.timer
sudo systemctl start cloudflare-ddns.service
sudo journalctl -u cloudflare-ddns.service -n 20 --no-pager
```

Expected: log line showing update with `proxied=false`.

- [ ] **Step 4: Verify grey cloud preserved**

Re-check in Cloudflare UI that the record is still DNS-only after DDNS runs.

---

### Task 4: User, server node, and subnet router `<home-lan-cidr>`

**Files:**
- Host networking (`sysctl`), Tailscale client on the Headscale PC

**Interfaces:**
- Consumes: healthy Headscale from Task 2
- Produces: approved route `<home-lan-cidr>` via the server node

- [ ] **Step 1: Create Headscale user**

```bash
sudo headscale users create <headscale-user>
sudo headscale users list
```

(Use your preferred username; avoid trailing `@`.)

- [ ] **Step 2: Enable IPv4 forwarding**

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-headscale-forward.conf
sudo sysctl --system | grep ip_forward
```

Expected: `net.ipv4.ip_forward = 1`

- [ ] **Step 3: Install Tailscale client on the Headscale host and join**

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo headscale preauthkeys create --user <headscale-user> --reusable --expiration 24h
```

Replace `<headscale-user>` with the user id/name your CLI expects (`headscale preauthkeys create --help`).

```bash
sudo tailscale up \
  --login-server=https://headscale.willyrv.com \
  --authkey=YOUR_PREAUTH_KEY \
  --advertise-routes=<home-lan-cidr> \
  --accept-dns=false
sudo tailscale status
```

Do not commit the preauth key.

- [ ] **Step 4: Approve the advertised route in Headscale**

```bash
sudo headscale nodes list
sudo headscale routes list
```

Enable/approve the `<home-lan-cidr>` route for the server node using the commands shown by your Headscale version (`headscale routes --help` or `headscale nodes approve-routes --help`).

Example pattern (v0.22-style; prefer `--help` on your build):

```bash
sudo headscale routes enable -r ROUTE_ID
# or:
# sudo headscale nodes approve-routes --identifier NODE_ID --routes <home-lan-cidr>
sudo headscale routes list
```

Expected: route `<home-lan-cidr>` listed as enabled/approved.

- [ ] **Step 5: Confirm LAN side**

From the Headscale host:

```bash
ip route | head
ping -c 2 <home-gateway-ip> || true
```

---

### Task 5: Remote client verification

**Files:** None in git

**Interfaces:**
- Consumes: approved subnet route from Task 4
- Produces: proof that an off-LAN client can reach `<home-lan-cidr>`

- [ ] **Step 1: Enroll a laptop or phone outside the home Wi-Fi/LAN**

Use mobile data or another network. Install Tailscale; login server = `https://headscale.willyrv.com`.

Linux example:

```bash
sudo tailscale up \
  --login-server=https://headscale.willyrv.com \
  --accept-routes \
  --accept-dns=true
```

Approve/register the node if using interactive auth:

```bash
sudo headscale nodes list
# sudo headscale auth register --user <headscale-user> --auth-id <AUTH_ID>   # if required by version
```

- [ ] **Step 2: Verify mesh**

On the remote client:

```bash
tailscale status
```

Expected: Headscale server node visible/online.

- [ ] **Step 3: Verify LAN routing**

From the remote client, reach a known LAN host (router or another PC):

```bash
ping -c 3 <home-gateway-ip>
# or SSH to a LAN host you control
```

Expected: replies succeed while still off the home LAN.

- [ ] **Step 4: Record results for the experience note**

Note: Headscale version, what worked, any NAT/DERP fallback observations, DDNS behavior. No secrets.

---

### Task 6: Repository documentation — Headscale app page

**Files:**
- Create: `docs/apps/headscale.md`
- Modify: `docs/apps/wireguard.md`
- Modify: `docs/guides/phase-02-vpn-access.md`
- Modify: `docs/architecture/networking.md` (short cross-link only if VPN paragraph still says WireGuard-first without Headscale)

**Interfaces:**
- Consumes: verified setup from Tasks 1–5
- Produces: canonical docs matching reality

- [ ] **Step 1: Create `docs/apps/headscale.md`**

Use this structure (fill versions/commands from the live host; keep placeholders for secrets):

```markdown
# Headscale

Status: In progress → Recommended (once verified)

## Purpose

Self-hosted Tailscale control server for mesh VPN between personal devices and access to the home LAN (`<home-lan-cidr>`).

## Placement

Run on the Ubuntu infrastructure host (not in Kubernetes), with native TLS on `https://headscale.willyrv.com`.

## Design choices

- Cloudflare DNS-only (never Proxy/Tunnel)
- Headscale terminates Let’s Encrypt (`TLS-ALPN-01`, listen `:443`)
- Embedded DERP + STUN UDP 3478
- Subnet router advertises `<home-lan-cidr>`
- DDNS via Cloudflare API on the host

## Ports

| Port | Proto | Role |
|------|-------|------|
| 443 | TCP | HTTPS control + ACME ALPN |
| 41641 | UDP | WireGuard (default client port) |
| 3478 | UDP | STUN (embedded DERP) |

## Client login

```bash
tailscale up --login-server=https://headscale.willyrv.com
```

## See also

- [Phase 2 — VPN access](../guides/phase-02-vpn-access.md)
- [Networking](../architecture/networking.md)
- Upstream: https://headscale.net/
- Experience notes under `../experiences/`
```

Expand with the concrete config snippets and verification commands from Tasks 2–5 (no tokens).

- [ ] **Step 2: Update `docs/apps/wireguard.md`**

Change the “WireGuard or Headscale” section to state this lab chose **Headscale**, link to `headscale.md`, and keep plain WireGuard as an alternative if Headscale is unavailable.

- [ ] **Step 3: Update `docs/guides/phase-02-vpn-access.md`**

Replace WireGuard-first checklist items with Headscale + DDNS + port forwards + subnet route + remote verification. Keep Status accurate (`In progress` or `Recommended`).

- [ ] **Step 4: Soft-update networking overview**

In `docs/architecture/networking.md`, ensure the VPN paragraph links to Headscale as the active choice.

- [ ] **Step 5: Commit**

```bash
git add docs/apps/headscale.md docs/apps/wireguard.md docs/guides/phase-02-vpn-access.md docs/architecture/networking.md
git commit -m "$(cat <<'EOF'
Document Headscale as the Phase 2 VPN control plane.

Record native TLS, DNS-only Cloudflare, and LAN subnet routing for the home lab.
EOF
)"
```

---

### Task 7: Experience note and final verification in git

**Files:**
- Create: `docs/experiences/2026-07-19-headscale-home-setup.md` (adjust date if setup finishes another day)
- Modify: `docs/experiences/README.md` (add entry link)
- Modify: `README.md` only if Apps list should include Headscale

**Interfaces:**
- Consumes: operator notes from Task 5
- Produces: dated experience entry + green `./scripts/verify-docs.sh`

- [ ] **Step 1: Write the experience entry**

Include: context (dynamic IP, Cloudflare, Ubuntu PC), decision (Approach 1), what was configured, verification results, follow-ups (ACLs, exit node later). Link to `../apps/headscale.md`.

- [ ] **Step 2: Link from experiences README and optionally root README Apps section**

- [ ] **Step 3: Run verification**

```bash
./scripts/verify-docs.sh
```

If `verify-docs.sh` has a hard-coded file list that must include new pages, add `docs/apps/headscale.md` and the experience file to `required_files` in the same commit.

- [ ] **Step 4: Commit**

```bash
git add docs/experiences/ docs/apps/headscale.md scripts/verify-docs.sh README.md
git commit -m "$(cat <<'EOF'
Add Headscale home setup experience notes.

Capture the live VPN bring-up and keep docs verification in sync.
EOF
)"
```

- [ ] **Step 5: Push when the operator requests**

```bash
git push origin HEAD
```

---

## Self-review (plan author)

1. **Spec coverage:** DNS-only Cloudflare, native ACME, ports, DDNS, subnet `<home-lan-cidr>`, client enrollment, docs updates, no secrets — mapped to Tasks 1–7. TLS-ALPN-01 chosen so WAN TCP 80 is not required (consistent with design port list).
2. **Placeholder scan:** Operator-specific values marked (`YOUR_EMAIL`, keys, LAN IP); no TBD steps.
3. **Consistency:** Hostname `headscale.willyrv.com`, MagicDNS base `ts.willyrv.com`, route `<home-lan-cidr>` used throughout.

## Execution handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-19-headscale-home-setup.md`. Two execution options:**

**1. Guided inline (recommended for Tasks 1–5)** — walk through host/router/Cloudflare steps in this session; you run commands on the Ubuntu PC and paste output when needed.

**2. Docs-first** — implement Tasks 6–7 stubs from the design now, then do Tasks 1–5 guided when you are at the machine.

**Which approach?**
