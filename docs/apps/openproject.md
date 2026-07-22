# OpenProject

Status: Recommended

## Purpose

[OpenProject](https://www.openproject.org/) provides project planning, issue tracking, and team collaboration. This lab runs it on **single-node k3s** at home, published at `https://projects.willyrv.com` via **Cloudflare Tunnel + Access** (required because the home ISP uses **IPv4 CGNAT** and cannot accept inbound port forwards).

## Placement (validated)

| Role | Where |
|------|--------|
| k3s + OpenProject Helm | Home mini PC `192.168.1.11` (Ubuntu 24.04, ~8 GB RAM / 4 CPU) |
| Public HTTPS + identity gate | Cloudflare Tunnel + Cloudflare Access |
| Private / break-glass access | LAN or Headscale via subnet router `192.168.1.12` (`192.168.1.0/24`) |

```text
Internet
   │
Cloudflare Access  →  Cloudflare Tunnel
   │
cloudflared (Deployment in k3s)
   │
Service openproject:8080 (ClusterIP)
   │
OpenProject + PostgreSQL + Memcached (+ Hocuspocus)
   │
local-path PVs on 192.168.1.11

Also:  outside Tailscale client
          → Headscale (OVH)
          → 192.168.1.12 (subnet router)
          → 192.168.1.11 (no Tailscale required on this box)
```

Do **not** put Headscale itself behind a Cloudflare Tunnel. Tunnels are appropriate for HTTP apps such as OpenProject.

---

## 1. Base host

On a fresh Ubuntu Server (example hostname `minipc-server`):

- Static DHCP lease for `192.168.1.11`
- Enough disk for PVs (SSD preferred)
- Optional: leave Docker unused; k3s uses containerd

```bash
hostname
free -h
nproc
ip -4 addr show
```

---

## 2. Install single-node k3s + Helm

```bash
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
sudo systemctl status k3s --no-pager

mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER:$USER" ~/.kube/config
export KUBECONFIG=$HOME/.kube/config

kubectl get nodes -o wide
kubectl get pods -A

# Helm 3 (prefer official script over snap)
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

If `kubectl` talks to `localhost:8080`, the kubeconfig is missing — fix with the `~/.kube/config` steps above (or use `sudo k3s kubectl …`).

---

## 3. Deploy OpenProject (Helm)

Official chart: [OpenProject Helm documentation](https://www.openproject.org/docs/installation-and-operations/installation/helm-chart/) / [charts.openproject.org](https://charts.openproject.org/).

On a **single-node** cluster, `ReadWriteOnce` + `local-path` is acceptable (web and worker share the same node). Set `https: true` / `OPENPROJECT_HTTPS=true` even though TLS terminates at Cloudflare.

```bash
helm repo add openproject https://charts.openproject.org
helm repo update

mkdir -p ~/openproject
# Create values.yaml — set a strong admin password and your email
```

Example `~/openproject/values.yaml` (adjust secrets; do not commit real passwords):

```yaml
openproject:
  https: true
  admin_user:
    password: "CHANGE_ME_STRONG_PASSWORD"
    password_reset: "true"
    mail: "you@example.com"

environment:
  OPENPROJECT_HOST__NAME: "projects.willyrv.com"
  OPENPROJECT_HTTPS: "true"
  OPENPROJECT_HSTS: "true"

resources:
  requests:
    memory: 512Mi
    cpu: 250m
  limits:
    memory: 2Gi
    cpu: "2"

ingress:
  enabled: false

persistence:
  enabled: true
  storageClassName: local-path
  accessModes:
    - ReadWriteOnce
  size: 20Gi

postgresql:
  primary:
    persistence:
      enabled: true
      storageClass: local-path
      size: 10Gi
```

```bash
helm upgrade --install openproject openproject/openproject \
  --namespace openproject \
  --create-namespace \
  -f ~/openproject/values.yaml \
  --timeout 15m \
  --wait=false

kubectl -n openproject get pods
kubectl -n openproject get svc
```

Expected Service (validated):

```text
openproject    ClusterIP    …    8080/TCP
```

Plus PostgreSQL, Memcached, and related services. First boot can take several minutes.

---

## 4. Cloudflare Tunnel

1. [Zero Trust](https://one.dash.cloudflare.com/) → **Networks** → **Tunnels** → create a **Cloudflared** tunnel (e.g. `openproject-home`).
2. Add public hostname:

| Field | Value |
|-------|--------|
| Hostname | `projects.willyrv.com` |
| Type | HTTP |
| Service | `openproject.openproject.svc.cluster.local:8080` |

That service URL requires `cloudflared` **inside** the cluster (same DNS as other pods).

3. Deploy the connector with the tunnel **token** (store as a Secret; never commit):

```bash
kubectl create namespace cloudflared 2>/dev/null || true
kubectl -n cloudflared create secret generic tunnel-token \
  --from-literal=token='YOUR_TUNNEL_TOKEN'

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflared
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:latest
          args: ["tunnel", "--no-autoupdate", "run", "--token", "$(TUNNEL_TOKEN)"]
          env:
            - name: TUNNEL_TOKEN
              valueFrom:
                secretKeyRef:
                  name: tunnel-token
                  key: token
EOF

kubectl -n cloudflared get pods
kubectl -n cloudflared logs deploy/cloudflared --tail=50
```

DNS for `projects` may show as **proxied** (orange cloud) when managed by the tunnel — expected for Tunnels (unlike Headscale, which must stay DNS-only).

---

## 5. Cloudflare Access

1. Zero Trust → **Access** → **Applications** → **Self-hosted** for `projects.willyrv.com`.
2. **Allow** policy: your email(s) and/or Google login.
3. Prefer **Google** (or another IdP) over email one-time PIN if Gmail does not reliably receive Cloudflare OTP messages.

Flow: browser → Access → Tunnel → OpenProject → OpenProject’s own admin login.

---

## 6. Private access without Tailscale on `.11`

If `192.168.1.12` advertises `192.168.1.0/24` to Headscale and remote clients **accept routes**, they can reach `192.168.1.11` for SSH or LAN-side checks **without** installing Tailscale on the OpenProject node. Public users still use `projects.willyrv.com`.

---

## Backups

Back up:

- PostgreSQL logical dumps (and/or volume snapshots)
- Attachment / persistent volume data
- Helm values (without secrets in git) and tunnel/Access notes

Test a restore before relying on the service; see [Backup design](../architecture/backups.md).

## Hardening notes

- Strong OpenProject admin password; force reset on first login if desired.
- Cloudflare Access in front of the public hostname.
- Do not expose PostgreSQL/Memcached outside the cluster.
- Keep the Headscale subnet router (`192.168.1.12`) highly available for private access.

## See also

- [Headscale](headscale.md) — VPN / CGNAT context
- [Phase 5 — stateful apps](../guides/phase-05-stateful-apps.md)
- [Networking](../architecture/networking.md)
- [Storage](../architecture/storage.md)
- [Experience: OpenProject on k3s + Cloudflare Tunnel](../experiences/2026-07-22-openproject-cloudflare-tunnel.md)
- Upstream Helm: https://www.openproject.org/docs/installation-and-operations/installation/helm-chart/
