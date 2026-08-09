# JupyterHub

Status: Recommended

## Purpose

[JupyterHub](https://jupyter.org/hub) gives each user an isolated JupyterLab (or Notebook) environment. This lab uses it for **teaching**: a small class (e.g. three students) on a powerful single-node k3s host, each with their own home volume and resource limits.

For one trusted user only, a plain JupyterLab container may be enough. Prefer JupyterHub whenever you need separate accounts and quotas. Use [marimo](marimo.md) for reactive notebooks or published apps — not as the multi-user classroom platform.

## Placement (validated)

| Role | Where |
|------|--------|
| k3s + Zero to JupyterHub (Z2JH) | Powerful host (example: Ubuntu, 24 cores / ~128 GB RAM, RTX 4090), hostname `guest1`, LAN `172.16.0.136` |
| Public HTTPS + identity gate | Cloudflare Tunnel + Cloudflare Access → `https://jupyter.willyrv.com` |
| Hub auth (classroom bootstrap) | DummyAuthenticator + allow-list (`admin`, `student1`–`student3`) behind Access |
| Optional GPU notebooks | NVIDIA Container Toolkit + device plugin; `singleuser` requests `nvidia.com/gpu` |

```text
Internet
   │
Cloudflare Access  →  Cloudflare Tunnel
   │
cloudflared (in k3s)
   │
Service proxy-public:80  (JupyterHub configurable-http-proxy)
   │
hub + per-user pods (scipy-notebook) + local-path home PVCs
```

**Network note:** If this host is **not** on `192.168.1.0/24`, the existing Headscale subnet router on `192.168.1.12` will not reach it automatically. Join this machine to Headscale as its own Tailscale client, or advertise the correct LAN route. Public Tunnel access does not depend on that.

Do not expose an editable Hub to the open Internet without Access (or VPN-only).

---

## 1. Base host + k3s

```bash
# sanity
free -h && nproc && df -h /

curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER:$USER" ~/.kube/config
export KUBECONFIG=$HOME/.kube/config

kubectl get nodes -o wide
kubectl get pods -A

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

If `kubectl` hits `localhost:8080`, kubeconfig is not loaded — fix with the steps above.

---

## 2. Install JupyterHub (Helm / Z2JH)

Chart: [Zero to JupyterHub with Kubernetes](https://z2jh.jupyter.org/) (`jupyterhub/jupyterhub`).

```bash
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
helm repo update
```

Example `~/jupyterhub/values.yaml` (change the password; do not commit secrets):

```yaml
proxy:
  service:
    type: ClusterIP
  https:
    enabled: false   # TLS at Cloudflare

hub:
  config:
    Authenticator:
      admin_users:
        - admin
      allowed_users:
        - admin
        - student1
        - student2
        - student3
    DummyAuthenticator:
      password: "CHANGE_ME_TEACHING_PASSWORD"
    JupyterHub:
      authenticator_class: dummy
      tornado_settings:
        xsrf_cookies: true
  db:
    type: sqlite-pvc
    pvc:
      storageClassName: local-path
      storage: 2Gi

singleuser:
  image:
    name: quay.io/jupyter/scipy-notebook
    tag: latest   # pin a digest/tag in production
  storage:
    type: dynamic
    capacity: 20Gi
    dynamic:
      storageClass: local-path
  cpu:
    guarantee: 1
    limit: 4
  memory:
    guarantee: 2G
    limit: 16G
  defaultUrl: /lab
  # Optional GPU (requires §6 first). One GPU on the node → one GPU user at a time.
  # extraPodConfig:
  #   runtimeClassName: nvidia
  # extraResource:
  #   limits:
  #     nvidia.com/gpu: "1"
  #   guarantees:
  #     nvidia.com/gpu: "1"

scheduling:
  userScheduler:
    enabled: false   # single-node

cull:
  enabled: true
  timeout: 3600
  every: 300

ingress:
  enabled: false
```

```bash
helm upgrade --install jhub jupyterhub/jupyterhub \
  --namespace jhub \
  --create-namespace \
  --version=4.2.0 \
  -f ~/jupyterhub/values.yaml \
  --timeout 20m \
  --wait=false

# Use the version shown by: helm search repo jupyterhub/jupyterhub

kubectl -n jhub get pods
kubectl -n jhub get svc
```

Expected core pods: `hub`, `proxy`, `continuous-image-puller`.  
Expected Service for the tunnel: **`proxy-public`** on port **80**.

**Important:** editing `~/jupyterhub/values.yaml` alone does nothing. Always apply with `helm upgrade ... -f values.yaml`, then confirm with `helm get values jhub -n jhub`. Restart user servers (delete `jupyter-<user>` pods) so new `singleuser` settings take effect.

Optional local check:

```bash
kubectl -n jhub port-forward svc/proxy-public 8080:80
# browse http://127.0.0.1:8080
```

---

## 3. Cloudflare Tunnel

1. Zero Trust → **Tunnels** → create (e.g. `jupyter-guest1`).
2. Public hostname:

| Field | Value |
|-------|--------|
| Hostname | `jupyter.willyrv.com` |
| Type | HTTP |
| URL | `proxy-public.jhub.svc.cluster.local:80` |

3. Deploy `cloudflared` in-cluster with the tunnel token (Secret; never commit):

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
kubectl -n cloudflared logs deploy/cloudflared --tail=40
```

---

## 4. Cloudflare Access

1. Access application for `jupyter.willyrv.com` (self-hosted).
2. Allow instructor + student emails (or Google IdP). Prefer **Google** over email OTP if Gmail drops Cloudflare codes.
3. Flow: Access → JupyterHub login → per-user Lab.

---

## 5. Student logins (DummyAuthenticator)

After Access:

| Username | Password |
|----------|----------|
| `admin` | value of `DummyAuthenticator.password` |
| `student1` / `student2` / `student3` | **same** shared Dummy password |

Only allow-listed usernames work. First login for each student starts a user pod and a home PVC.

```bash
kubectl -n jhub get pods
# e.g. jupyter-student1-... Running
```

Dummy auth is acceptable for a tiny class **behind Access**. For per-student passwords, move to NativeAuthenticator or OAuth later.

---

## 6. NVIDIA GPU for notebooks (validated on guest1)

Host example: **RTX 4090**, driver **595.x**, `nvidia-smi` reports **CUDA Version: 13.2**.  
Symptom if GPU is not passed into the pod: `nvidia-smi: command not found`, CuPy `driver 0` / `cudaErrorInsufficientDriver`.

### 6.1 Host driver (must work outside k3s)

```bash
nvidia-smi   # on the node, not in a pod
```

### 6.2 NVIDIA Container Toolkit

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
which nvidia-ctk nvidia-container-runtime
```

### 6.3 Wire the runtime into k3s

```bash
sudo systemctl restart k3s
sudo grep nvidia /var/lib/rancher/k3s/agent/etc/containerd/config.toml
```

If `grep` finds nothing, set default runtime in `/etc/rancher/k3s/config.yaml`:

```yaml
default-runtime: nvidia
```

then `sudo systemctl restart k3s` again. Confirm RuntimeClasses:

```bash
sudo k3s kubectl get runtimeclass
```

### 6.4 Device plugin

Until the node advertises `nvidia.com/gpu`, no pod can consume a GPU.

```bash
sudo k3s kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.1/deployments/static/nvidia-device-plugin.yml

# Often required on k3s so the plugin itself runs with the NVIDIA runtime:
sudo k3s kubectl -n kube-system patch ds nvidia-device-plugin-daemonset \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/runtimeClassName","value":"nvidia"}]'

sudo k3s kubectl -n kube-system delete pod -l name=nvidia-device-plugin-ds
sudo k3s kubectl describe node | grep -i nvidia.com/gpu
```

Success looks like Capacity/Allocatable `nvidia.com/gpu: 1` (and Allocated `0` until a user pod claims it).

Smoke test:

```bash
sudo k3s kubectl run gpu-test --rm -it --restart=Never \
  --image=nvidia/cuda:12.6.0-base-ubuntu22.04 \
  --overrides='{"spec":{"runtimeClassName":"nvidia","containers":[{"name":"gpu-test","image":"nvidia/cuda:12.6.0-base-ubuntu22.04","command":["nvidia-smi"],"resources":{"limits":{"nvidia.com/gpu":"1"}}}]}}'
```

### 6.5 Give JupyterHub user pods the GPU

In `~/jupyterhub/values.yaml` under `singleuser`, enable:

```yaml
singleuser:
  extraPodConfig:
    runtimeClassName: nvidia
  extraResource:
    limits:
      nvidia.com/gpu: "1"
    guarantees:
      nvidia.com/gpu: "1"
```

Apply and recycle the user server:

```bash
helm upgrade jhub jupyterhub/jupyterhub -n jhub -f ~/jupyterhub/values.yaml
helm get values jhub -n jhub   # must show the GPU keys
sudo k3s kubectl -n jhub delete pod jupyter-admin   # or jupyter-student1, etc.
```

Inside the new notebook pod:

```bash
nvidia-smi
```

### 6.6 CuPy tip

Match the CuPy wheel to the **host** CUDA major from `nvidia-smi` (e.g. CUDA 13.x → `pip install cupy-cuda13x`). The wheel only ships a CUDA **runtime**; the **driver** must come from the host via the steps above. Prefer diagnosing with:

```python
from cupy.cuda import runtime
print(runtime.runtimeGetVersion(), runtime.driverGetVersion())  # driver must be > 0
```

With a single GPU, schedule only one GPU notebook at a time (or use time-slicing / MIG if you add that later).

---

## Resource guidance (large host)

On ~24 CPU / ~128 GB RAM, limits like **4 CPU / 16 GiB per student** leave ample headroom for three concurrent users. Raise or lower `singleuser.cpu` / `singleuser.memory` in values and `helm upgrade`.

Enable **culling** so idle servers release capacity.

## Backups

- User home PVCs (notebooks, data)
- Hub DB PVC (sqlite) if used
- Helm values (redact secrets)

See [Backup design](../architecture/backups.md).

## See also

- [marimo](marimo.md) — reactive / published apps, not multi-user Hub
- [OpenProject](openproject.md) — same Tunnel + Access pattern
- [Headscale](headscale.md) — VPN / CGNAT
- [Phase 5 — stateful apps](../guides/phase-05-stateful-apps.md)
- [Guide: JupyterHub with GPU on k3s + Cloudflare](../guides/jupyterhub-gpu-k3s-cloudflare.md) — end-to-end GUEST2 / `jupyter2` path including local CuPy image
- [Experience: JupyterHub teaching stack + GPU](../experiences/2026-07-22-jupyterhub-cloudflare-tunnel.md)
- [Experience: GPU JupyterHub on GUEST2](../experiences/2026-08-09-jupyterhub-gpu-guest2.md)
- Upstream: https://z2jh.jupyter.org/
