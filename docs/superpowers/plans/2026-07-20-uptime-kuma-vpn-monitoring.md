# Uptime Kuma VPN Monitoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy public Uptime Kuma on the OVH VPS (Docker + Nginx) to monitor Headscale `/health` and the home PC’s Tailscale IP, plus CrowdSec on Nginx and a Headscale journal watcher for abuse/auth failures; document everything in this repository.

**Architecture:** Compose/Nginx on the existing OVH VPS (no K3s/Rancher). VPS joins Headscale as a probe client. Kuma stays publicly reachable on `status.willyrv.com` (DNS-only Cloudflare). CrowdSec protects Headscale and status vhosts; a small script alerts on Headscale auth/registration failures via ntfy/Telegram.

**Tech Stack:** Docker Compose, Uptime Kuma, Nginx, Certbot, Tailscale client, CrowdSec + firewall bouncer, systemd timer + bash for journal watch, ntfy and/or Telegram.

## Global Constraints

- Host: OVH VPS already running Nginx, Certbot, Headscale behind `headscale.willyrv.com`.
- Kuma hostname: `status.willyrv.com` (Cloudflare **DNS only**).
- Kuma exposure: **public long-term** with strong unique admin password.
- Home check: Tailscale ping/TCP from VPS to home PC Tailscale IP (not push heartbeat).
- VPS Tailscale client: no subnet/exit routes advertised.
- Abuse: CrowdSec on Nginx (headscale + status) **and** Headscale journal auth/registration alerts.
- No secrets in git (passwords, tokens, webhook URLs with secrets, real Tailscale IPs optional as placeholders).
- No Rancher/K3s on this VPS for this plan.

## File Structure

| Path | Responsibility |
|------|----------------|
| Host: `~/hosting/uptime-kuma/docker-compose.yml` (or `/opt/uptime-kuma/`) | Kuma container |
| Host: `/etc/nginx/sites-available/status` | Public reverse proxy for Kuma |
| Host: CrowdSec config + bouncer | Nginx abuse protection |
| Host: `/usr/local/sbin/headscale-auth-watch.sh` + systemd units | Auth failure alerts |
| `docs/apps/uptime-kuma.md` | Canonical runbook |
| `docs/apps/headscale.md` | Cross-link to monitoring |
| `docs/architecture/monitoring.md` | Point to Kuma for VPN availability |
| `docs/experiences/2026-07-20-uptime-kuma-vpn-monitoring.md` | First-person notes |
| `scripts/verify-docs.sh` | Add new required files |

## Operator note

Tasks 1–5 run on the OVH VPS (and briefly the home PC for Tailscale IP / disconnect tests). Tasks 6–7 update this git repository after the stack works.

---

### Task 1: Join OVH VPS to Headscale as probe client

**Files:** None in git (host Tailscale)

**Interfaces:**
- Consumes: working `https://headscale.willyrv.com`, Headscale user/preauth key
- Produces: VPS node online on the tailnet; home PC Tailscale IP known for Kuma

- [ ] **Step 1: Install Tailscale on the VPS if missing**

```bash
command -v tailscale || curl -fsSL https://tailscale.com/install.sh | sh
```

- [ ] **Step 2: Create a preauth key on the VPS (Headscale CLI)**

```bash
sudo headscale users list
sudo headscale preauthkeys create --user USER_ID --reusable --expiration 24h
```

- [ ] **Step 3: Join without advertising routes**

```bash
sudo tailscale up \
  --login-server=https://headscale.willyrv.com \
  --authkey=YOUR_PREAUTH_KEY \
  --accept-dns=false \
  --advertise-routes=
sudo tailscale status
```

Expected: VPS and home nodes listed; VPS has a `100.x` address.

- [ ] **Step 4: Record home PC Tailscale IPv4**

```bash
# on VPS
tailscale status
# note the home PC's 100.x.y.z — use in Kuma monitor (do not commit secrets; IP is semi-private OK as placeholder in docs)
ping -c 2 HOME_TAILSCALE_IP
```

Expected: ping succeeds while home subnet router is online.

---

### Task 2: Deploy Uptime Kuma with Docker Compose + public Nginx

**Files:**
- Host: compose project + Nginx site
- Cloudflare DNS for `status.willyrv.com`

**Interfaces:**
- Consumes: Docker Engine on VPS; Nginx/Certbot pattern from Headscale
- Produces: `https://status.willyrv.com` serving Kuma login

- [ ] **Step 1: DNS**

Cloudflare A record `status` → VPS IPv4, **DNS only**. Verify:

```bash
dig +short status.willyrv.com A
```

- [ ] **Step 2: Install Docker if needed**

```bash
docker --version || (curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker "$USER")
docker compose version
```

- [ ] **Step 3: Compose file**

```bash
sudo mkdir -p /opt/uptime-kuma
sudo tee /opt/uptime-kuma/docker-compose.yml <<'EOF'
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    restart: unless-stopped
    volumes:
      - uptime-kuma-data:/app/data
    ports:
      - "127.0.0.1:3001:3001"

volumes:
  uptime-kuma-data:
EOF

cd /opt/uptime-kuma && sudo docker compose up -d
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3001
```

Expected: HTTP 200 or 302 from localhost:3001.

- [ ] **Step 4: Nginx vhost (HTTP first)**

```bash
sudo tee /etc/nginx/sites-available/status <<'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name status.willyrv.com;

    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/status /etc/nginx/sites-enabled/status
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d status.willyrv.com
curl -fsS -o /dev/null -w '%{http_code}\n' https://status.willyrv.com
```

- [ ] **Step 5: Create Kuma admin**

Open `https://status.willyrv.com`, set a **strong unique** admin password (not reused). Do not commit it.

---

### Task 3: Configure Kuma monitors and notifications

**Files:** None in git (Kuma UI / data volume)

**Interfaces:**
- Consumes: Kuma up; home Tailscale IP from Task 1
- Produces: two monitors + alert channel wired

- [ ] **Step 1: Notification**

In Kuma → Settings → Notifications: add **ntfy** and/or **Telegram**. Send a test notification.

- [ ] **Step 2: Monitor — Headscale health**

- Type: HTTP(s)
- URL: `https://headscale.willyrv.com/health`
- Interval: 60s (or 30s)
- Attach notification

- [ ] **Step 3: Monitor — home Tailscale IP**

- Type: Ping (preferred) or TCP port 22/whatever is open on home over tailnet
- Hostname: `HOME_TAILSCALE_IP`
- Interval: 60s
- Attach same notification

If ping is blocked inside Docker network namespace, either:

```bash
# give container NET_ADMIN/NET_RAW or use host network for ICMP — or switch monitor to TCP
```

Practical fallback: run Kuma with `network_mode: host` **or** use TCP check to a port reachable on the home node via Tailscale. Update compose if ping from bridge network fails:

```yaml
# optional adjustment if ICMP from container fails
    network_mode: host
    # then remove ports: mapping; Kuma listens on host :3001
```

If switching to `network_mode: host`, change Nginx `proxy_pass` still to `127.0.0.1:3001` and recreate the container.

- [ ] **Step 4: Verify alert paths**

```bash
# Headscale monitor: briefly stop headscale
sudo systemctl stop headscale
# wait for Kuma alert, then:
sudo systemctl start headscale
```

```bash
# Home monitor: on home PC briefly
sudo tailscale down
# wait for alert, then:
sudo tailscale up --login-server=https://headscale.willyrv.com --accept-dns=false --advertise-routes=192.168.1.0/24
# re-approve routes on VPS if needed
```

Expected: down then up notifications for both monitors.

---

### Task 4: CrowdSec for Nginx (Headscale + status)

**Files:** Host CrowdSec packages/config (not committed with secrets)

**Interfaces:**
- Consumes: Nginx access logs for both vhosts
- Produces: bans/alerts on abusive HTTP; whitelist for operator IP

- [ ] **Step 1: Install CrowdSec + Nginx collection + firewall bouncer**

Follow current CrowdSec docs for Ubuntu, roughly:

```bash
curl -s https://install.crowdsec.net | sudo bash
sudo apt install -y crowdsec crowdsec-firewall-bouncer-iptables
sudo cscli collections install crowdsecurity/nginx
sudo systemctl reload crowdsec
sudo cscli collections list
sudo cscli bouncers list
```

Adjust package names if the installer recommends `nftables` bouncer instead.

- [ ] **Step 2: Ensure Nginx log paths are acquired**

Confirm CrowdSec acquis includes `/var/log/nginx/access.log` (and error.log). Reload CrowdSec after edits.

- [ ] **Step 3: Whitelist your admin IP(s)**

```bash
sudo cscli parsers install crowdsecurity/whitelists
# add your public IP to local whitelist per CrowdSec docs — avoid locking yourself out
sudo systemctl reload crowdsec
```

- [ ] **Step 4: Notifications (optional plugin)**

Configure CrowdSec notification to ntfy/Telegram if desired (HTTP plugin). Otherwise rely on `cscli metrics` / dashboard and Kuma for uptime; minimum is active bouncer.

- [ ] **Step 5: Controlled probe**

From a **non-critical IP** (not your only admin path), generate obvious scanner noise against `https://headscale.willyrv.com/does-not-exist` in a loop, or use CrowdSec’s test tools. Confirm decisions appear:

```bash
sudo cscli decisions list
sudo tail -n 50 /var/log/crowdsec.log
```

Do not ban your own IP; use OVH console if locked out.

---

### Task 5: Headscale journal watcher → ntfy/Telegram

**Files:**
- Host: `/usr/local/sbin/headscale-auth-watch.sh`
- Host: `/etc/headscale/auth-watch.env` (mode 600; not in git)
- Host: systemd service + timer

**Interfaces:**
- Consumes: `journalctl -u headscale`
- Produces: alert when auth/registration failure patterns exceed threshold

- [ ] **Step 1: Env file**

```bash
sudo tee /etc/headscale/auth-watch.env <<'EOF'
# NTFY_URL=https://ntfy.sh/your-secret-topic
# or TELEGRAM_BOT_TOKEN= / TELEGRAM_CHAT_ID=
WINDOW_MINUTES=15
THRESHOLD=3
EOF
sudo chmod 600 /etc/headscale/auth-watch.env
```

- [ ] **Step 2: Watcher script**

```bash
sudo tee /usr/local/sbin/headscale-auth-watch.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source /etc/headscale/auth-watch.env
WINDOW_MINUTES="${WINDOW_MINUTES:-15}"
THRESHOLD="${THRESHOLD:-3}"
PATTERN='(?i)(invalid|expired|unknown).*(auth[[:space:]]*key|preauth)|authkey|rejected.*regist|failed to register|unauthorized'
COUNT="$(journalctl -u headscale --since "${WINDOW_MINUTES} minutes ago" --no-pager 2>/dev/null | grep -Eic "$PATTERN" || true)"
if [[ "$COUNT" -ge "$THRESHOLD" ]]; then
  MSG="Headscale auth/registration failures: ${COUNT} matches in last ${WINDOW_MINUTES}m on $(hostname)"
  if [[ -n "${NTFY_URL:-}" ]]; then
    curl -fsS -d "$MSG" "$NTFY_URL" >/dev/null
  fi
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" -d "text=${MSG}" >/dev/null
  fi
  logger -t headscale-auth-watch "$MSG"
fi
EOF
sudo chmod 700 /usr/local/sbin/headscale-auth-watch.sh
```

- [ ] **Step 3: systemd timer every 5 minutes**

```bash
sudo tee /etc/systemd/system/headscale-auth-watch.service <<'EOF'
[Unit]
Description=Alert on Headscale auth/registration failures
After=network-online.target

[Service]
Type=oneshot
EnvironmentFile=/etc/headscale/auth-watch.env
ExecStart=/usr/local/sbin/headscale-auth-watch.sh
EOF

sudo tee /etc/systemd/system/headscale-auth-watch.timer <<'EOF'
[Unit]
Description=Run Headscale auth watch every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now headscale-auth-watch.timer
```

- [ ] **Step 4: Dry-run test**

Temporarily lower `THRESHOLD=1`, trigger a failed client auth with a bad key from a test device, wait for the timer (or run the script once), confirm notification, then restore threshold.

---

### Task 6: Repository documentation — Uptime Kuma app page

**Files:**
- Create: `docs/apps/uptime-kuma.md`
- Modify: `docs/apps/headscale.md` (See also + short monitoring pointer)
- Modify: `docs/architecture/monitoring.md` (VPN availability via Kuma)
- Modify: `docs/guides/phase-04-low-risk-apps.md` if it still treats Uptime Kuma as only future stub
- Modify: `README.md` Apps list
- Modify: `scripts/verify-docs.sh` required_files

**Interfaces:**
- Consumes: verified host setup from Tasks 1–5
- Produces: handbook pages without secrets

- [ ] **Step 1: Write `docs/apps/uptime-kuma.md`**

Include: purpose; public `status.willyrv.com`; Compose + Nginx; monitors (Headscale health + home Tailscale IP); hardening; CrowdSec + journal watcher summary; links to Headscale and experience note. Use placeholders for IPs/tokens.

- [ ] **Step 2: Cross-link Headscale + monitoring architecture + README**

- [ ] **Step 3: Update `verify-docs.sh` required_files**

Add `docs/apps/uptime-kuma.md` (experience file added in Task 7).

- [ ] **Step 4: Commit**

```bash
git add docs/apps/uptime-kuma.md docs/apps/headscale.md docs/architecture/monitoring.md docs/guides/phase-04-low-risk-apps.md README.md scripts/verify-docs.sh
git commit -m "$(cat <<'EOF'
Document public Uptime Kuma monitoring for Headscale and the home bridge.

Describe Compose/Nginx deployment, Tailscale probes, and abuse-alert hooks.
EOF
)"
```

---

### Task 7: Experience note and final verification

**Files:**
- Create: `docs/experiences/2026-07-20-uptime-kuma-vpn-monitoring.md`
- Modify: `docs/experiences/README.md`
- Modify: `scripts/verify-docs.sh` (add experience path)

**Interfaces:**
- Consumes: operator notes from bring-up
- Produces: green `./scripts/verify-docs.sh`

- [ ] **Step 1: Write first-person experience entry**

Cover: why Compose not Rancher/K3s on VPS; public Kuma choice; Tailscale ping; CrowdSec + journal watch; verification tests.

- [ ] **Step 2: Link from experiences README; run verify-docs**

```bash
./scripts/verify-docs.sh
```

- [ ] **Step 3: Commit and push when operator requests**

```bash
git add docs/experiences/ scripts/verify-docs.sh
git commit -m "$(cat <<'EOF'
Add experience notes for Uptime Kuma VPN monitoring bring-up.

Record the Compose/Nginx path and CGNAT-era Headscale dependency checks.
EOF
)"
```

---

## Self-review (plan author)

1. **Spec coverage:** Public Kuma, Tailscale home probe, CrowdSec Nginx, Headscale journal alerts, docs — Tasks 1–7. No K3s/Rancher.
2. **Placeholder scan:** Secrets/IPs marked for operator; compose and nginx configs provided in full.
3. **Consistency:** Hostnames `status.willyrv.com` / `headscale.willyrv.com`; DNS-only Cloudflare; probe node without routes.

## Execution handoff

**Plan complete and saved to `docs/superpowers/plans/2026-07-20-uptime-kuma-vpn-monitoring.md`. Two execution options:**

**1. Guided inline (recommended)** — walk Tasks 1–5 on the OVH VPS with you pasting outputs; then Tasks 6–7 in the repo.

**2. Docs-first** — write handbook stubs now; live bring-up when you are at the VPS.

**Which approach?**
