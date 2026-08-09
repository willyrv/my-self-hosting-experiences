# Guide — JupyterHub with GPU on k3s + Cloudflare Tunnel

Status: Recommended  
Audience: Single-node home lab with an NVIDIA GPU (validated path: discrete NVIDIA GPU, driver **595.x**, host CUDA **13.x**)

## Goal

Run **JupyterHub** on a fresh Ubuntu host with:

- per-user JupyterLab servers and home volumes;
- **GPU acceleration** inside notebooks (`nvidia-smi`, CuPy/PyTorch, etc.);
- public URL via **Cloudflare Tunnel + Access** (no home port forwards; works with ISP CGNAT);
- **CuPy preinstalled** in a **local** container image (no Docker Hub / GHCR required).

Example public hostname used in this lab: `https://jupyter2.willyrv.com` on teaching GPU host B (`<guest2-hostname>`).

For app-level notes and the earlier teaching-box (`jupyter.willyrv.com` / teaching GPU host A) details, see also [JupyterHub](../apps/jupyterhub.md).

Real addresses live in gitignored `docs/inventory.local.md` and `docs/experiences/deployment-topology.local.md`.

---

## Architecture

```text
Internet
   │
Cloudflare Access  →  Cloudflare Tunnel
   │
cloudflared (Deployment in k3s)
   │
Service proxy-public:80  (JupyterHub)
   │
hub + per-user pods
   │  runtimeClassName: nvidia
   │  resources: nvidia.com/gpu: 1
   │  image: scipy-notebook-cupy13:local  (optional baked CuPy)
   ▼
Host NVIDIA driver (e.g. 595.x) + Container Toolkit + device plugin
```

**One physical GPU ⇒ one GPU notebook at a time** unless you add time-slicing/MIG later.

If the host is **not** on `<home-lan-cidr>`, the Headscale subnet router on that LAN does not reach it automatically. Public Tunnel access still works; for VPN/SSH, join the host to Headscale or advertise the correct route.

---

## 1. Base host + NVIDIA driver

```bash
hostname
free -h
nproc
df -h /
ip -4 addr show | awk '/inet /{print $2,$NF}'

lspci | grep -i nvidia
nvidia-smi
```

`nvidia-smi` must show the GPU and a **CUDA Version** line (driver-reported). If missing:

```bash
sudo apt update
ubuntu-drivers devices
sudo ubuntu-drivers autoinstall
sudo reboot
# then: nvidia-smi
```

Prefer a static DHCP lease for the host LAN IP.

---

## 2. NVIDIA Container Toolkit

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

---

## 3. Single-node k3s + NVIDIA default runtime

```bash
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

sudo mkdir -p /etc/rancher/k3s
echo 'default-runtime: nvidia' | sudo tee /etc/rancher/k3s/config.yaml
sudo systemctl restart k3s

mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER:$USER" ~/.kube/config
export KUBECONFIG=$HOME/.kube/config

kubectl get nodes -o wide
kubectl get pods -A
kubectl get runtimeclass

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

If `kubectl` targets `localhost:8080`, kubeconfig is not loaded — fix with the copy steps above.

---

## 4. NVIDIA device plugin

Until the node advertises `nvidia.com/gpu`, no pod can use the GPU.

```bash
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.1/deployments/static/nvidia-device-plugin.yml

# Often required on k3s so the plugin runs with the NVIDIA runtime:
kubectl -n kube-system patch ds nvidia-device-plugin-daemonset \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/runtimeClassName","value":"nvidia"}]'

kubectl -n kube-system delete pod -l name=nvidia-device-plugin-ds
kubectl -n kube-system get pods | grep nvidia
kubectl describe node | grep -i nvidia.com/gpu
```

Success: Capacity/Allocatable `nvidia.com/gpu: 1` (Allocated `0` until a user pod claims it).

Smoke test:

```bash
kubectl run gpu-test --rm -it --restart=Never \
  --image=nvidia/cuda:12.6.0-base-ubuntu22.04 \
  --overrides='{"spec":{"runtimeClassName":"nvidia","containers":[{"name":"gpu-test","image":"nvidia/cuda:12.6.0-base-ubuntu22.04","command":["nvidia-smi"],"resources":{"limits":{"nvidia.com/gpu":"1"}}}]}}'
```

---

## 5. Custom Jupyter image with CuPy (local, no registry)

Match the CuPy wheel to the **host** CUDA major from `nvidia-smi` (CUDA 13.x → `cupy-cuda13x`). The wheel ships a CUDA **runtime**; the **driver** must come from the host via §§2–4.

### 5.1 Build with Docker

```bash
docker --version || (curl -fsSL https://get.docker.com | sh && sudo usermod -aG docker "$USER")
# log out/in or: newgrp docker

mkdir -p ~/jupyter-gpu-image && cd ~/jupyter-gpu-image
cat > Dockerfile <<'EOF'
FROM quay.io/jupyter/scipy-notebook:latest

USER ${NB_UID}
RUN pip install --no-cache-dir cupy-cuda13x
EOF

docker build -t scipy-notebook-cupy13:local .
docker images | grep scipy-notebook-cupy13
```

### 5.2 Import into k3s containerd

```bash
docker save scipy-notebook-cupy13:local | sudo k3s ctr images import -
sudo k3s ctr images ls | grep scipy-notebook-cupy13
```

Note the exact image name (often `docker.io/library/scipy-notebook-cupy13:local`).

### 5.3 Rebuild later

```bash
cd ~/jupyter-gpu-image
docker build -t scipy-notebook-cupy13:local .
docker save scipy-notebook-cupy13:local | sudo k3s ctr images import -
kubectl -n jhub delete pod -l component=singleuser-server --wait=false
```

**Alternative (not permanent for all users):** `pip install --user cupy-cuda13x` inside one user’s home PVC. Prefer the custom image for a shared teaching GPU box.

---

## 6. Install JupyterHub (Zero to JupyterHub)

```bash
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
helm repo update
helm search repo jupyterhub/jupyterhub

mkdir -p ~/jupyterhub
```

Example `~/jupyterhub/values.yaml` (change the password; do not commit secrets):

```yaml
# Public example: jupyter2.willyrv.com

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
    name: scipy-notebook-cupy13
    tag: local
    pullPolicy: IfNotPresent
  storage:
    type: dynamic
    capacity: 20Gi
    dynamic:
      storageClass: local-path
  cpu:
    guarantee: 1
    limit: 8
  memory:
    guarantee: 4G
    limit: 24G
  defaultUrl: /lab
  extraPodConfig:
    runtimeClassName: nvidia
  extraResource:
    limits:
      nvidia.com/gpu: "1"
    guarantees:
      nvidia.com/gpu: "1"

scheduling:
  userScheduler:
    enabled: false

cull:
  enabled: true
  timeout: 3600
  every: 300

ingress:
  enabled: false
```

If pods hit **ImagePullBackOff**, set `singleuser.image.name` to the full name from `k3s ctr images ls` (e.g. `docker.io/library/scipy-notebook-cupy13`).

```bash
# Use the chart version from: helm search repo jupyterhub/jupyterhub
helm upgrade --install jhub jupyterhub/jupyterhub \
  --namespace jhub \
  --create-namespace \
  --version=4.2.0 \
  -f ~/jupyterhub/values.yaml \
  --timeout 20m \
  --wait=false

kubectl -n jhub get pods
kubectl -n jhub get svc
helm get values jhub -n jhub | grep -A8 -E 'extraPodConfig|extraResource|image:|nvidia'
```

Confirm release values include `runtimeClassName: nvidia`, `nvidia.com/gpu: "1"`, and the local image.

Expected Service for the tunnel: **`proxy-public`** port **80**.

Optional local check before Cloudflare:

```bash
kubectl -n jhub port-forward svc/proxy-public 8080:80
# http://127.0.0.1:8080
```

---

## 7. Cloudflare Tunnel + Access

### 7.1 Tunnel (dashboard)

1. [Zero Trust](https://one.dash.cloudflare.com/) → **Networks** → **Tunnels** → create (e.g. `jupyter-guest2`).
2. Public hostname:

| Field | Value |
|-------|--------|
| Hostname | `jupyter2.willyrv.com` (or your FQDN) |
| Type | HTTP |
| URL | `proxy-public.jhub.svc.cluster.local:80` |

3. Copy the tunnel **token** (never commit it).

### 7.2 Access

1. **Access** → **Applications** → Self-hosted → same hostname.
2. Allow instructor/student identities. Prefer **Google** login over email one-time PIN if Gmail drops Cloudflare OTP mail.

### 7.3 cloudflared in-cluster

```bash
kubectl create namespace cloudflared 2>/dev/null || true
kubectl -n cloudflared create secret generic tunnel-token \
  --from-literal=token='YOUR_TUNNEL_TOKEN' \
  --dry-run=client -o yaml | kubectl apply -f -

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
          args:
            - tunnel
            - --no-autoupdate
            - run
            - --token
            - $(TUNNEL_TOKEN)
          env:
            - name: TUNNEL_TOKEN
              valueFrom:
                secretKeyRef:
                  name: tunnel-token
                  key: token
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
EOF

kubectl -n cloudflared get pods
kubectl -n cloudflared logs deploy/cloudflared --tail=40
```

---

## 8. Student / admin login

1. Open the public URL → pass **Cloudflare Access**.
2. JupyterHub form (DummyAuthenticator bootstrap):

| Username | Password |
|----------|----------|
| `admin` | `DummyAuthenticator.password` from values |
| `student1` / `student2` / `student3` | **same** shared Dummy password |

Only allow-listed usernames work. First login creates a user pod + home PVC.

```bash
kubectl -n jhub get pods
```

---

## 9. Verify GPU + permanent CuPy

In JupyterLab (terminal or notebook), **without** `pip install`:

```bash
nvidia-smi
python -c "import cupy; print('cupy', cupy.__version__); print('driver', cupy.cuda.runtime.driverGetVersion())"
```

- `nvidia-smi` must see the host GPU.
- CuPy `driver` must be **non-zero**. If `driver` is `0`, the GPU is not passed into the pod — revisit §§2–4 and `helm get values` / recycle the user pod.

On the host:

```bash
kubectl describe node | grep -i nvidia.com/gpu
```

While a GPU notebook is running, Allocated should show the GPU in use.

---

## 10. Operations checklist

| Task | Command / action |
|------|------------------|
| Change Hub config | Edit `values.yaml` → `helm upgrade jhub ... -f values.yaml` |
| Apply GPU/image changes to a user | Stop server in UI or `kubectl -n jhub delete pod -l component=singleuser-server` |
| Rebuild CuPy image | §5.3 |
| Backups | User home PVCs, hub DB PVC, redacted values file — see [Backups](../architecture/backups.md) |

Editing `values.yaml` alone does **not** change the cluster — always `helm upgrade`, then confirm with `helm get values`.

---

## Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| `kubectl` → `localhost:8080` | Missing `KUBECONFIG` / `~/.kube/config` |
| Node has no `nvidia.com/gpu` | Device plugin not patched / not Ready |
| Host `nvidia-smi` OK, pod `driver 0` | No `runtimeClassName: nvidia` or GPU resources on singleuser; values not applied |
| ImagePullBackOff for `:local` | Image not imported, wrong name, or `pullPolicy` not `IfNotPresent` |
| Access OTP email never arrives | Use Google IdP for Access (see OpenProject experience) |
| Helm values missing GPU keys | Forgot `helm upgrade` after editing the file |

---

## See also

- [JupyterHub app page](../apps/jupyterhub.md)
- [Phase 5 — stateful apps](phase-05-stateful-apps.md)
- [OpenProject + Tunnel](../apps/openproject.md) — same edge pattern
- [Headscale](../apps/headscale.md) — VPN / CGNAT
- [Experience: GPU JupyterHub on teaching GPU host B](../experiences/2026-08-09-jupyterhub-gpu-guest2.md)
- Upstream Z2JH: https://z2jh.jupyter.org/
