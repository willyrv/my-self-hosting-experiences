# Guide — Open WebUI on k3s + Cloudflare Tunnel (manual install)

Status: Planned (commands ready; not yet lived in this lab)  
Audience: You, on **teaching GPU host B**, in a terminal where `kubectl` talks to that cluster (the `jupyter2.willyrv.com` box).

This is the copy-paste runbook. Run the commands **on host B** (or any machine whose kubeconfig is that cluster). Do not run them against teaching GPU host A (Matomo / n8n) or the OpenProject mini PC.

Public URL this guide uses: `https://chat.willyrv.com`  
If you want a different hostname, change every `chat.willyrv.com` before you create the tunnel.

Upstream: [Kubernetes Deployment](https://docs.openwebui.com/deployment/kubernetes) (chart **16.5.0**, image **v0.11.3**). This guide follows that page’s **single-replica** path and publishes it with Cloudflare Tunnel + Access, the same edge as JupyterHub on this host. It does **not** follow the production path (PostgreSQL, Redis, S3, Tika, Ingress).

Never put the signing key, model API key, or tunnel token in git.

---

## What you are building

```text
You  →  Cloudflare Access  →  https://chat.willyrv.com
                │
                ▼
         Tunnel (outbound from host B)
                │
         k3s namespace openwebui
         ├── openwebui (Helm chart, 1 replica, SQLite on a local PVC)
         └── cloudflared
                │
                ▼
         an OpenAI-compatible model API you already have
         (not installed by this guide)
```

Open WebUI is the chat UI. The [official Kubernetes page](https://docs.openwebui.com/deployment/kubernetes) does not install Ollama, and the Open WebUI pod does not need a GPU. Host B’s GPU stays with JupyterHub.

The chart’s own defaults turn **Ollama, Pipelines, and Redis on**. The values below turn them off. If a rendered manifest still contains an Ollama Deployment, stop.

SQLite on this PVC is appropriate because host B’s default StorageClass is local disk (`local-path`), not NFS. The official page says not to put SQLite on NFS or SMB.

---

## 0. One-time locals (this shell)

You need an OpenAI-compatible base URL the pod can reach, including the `/v1` suffix. Example: `https://api.openai.com/v1` or your own server.

```bash
export OPENWEBUI_CHART_VERSION=16.5.0
export OPENWEBUI_IMAGE_TAG=v0.11.3
export CLOUDFLARED_IMAGE=docker.io/cloudflare/cloudflared:2026.9.0
export OPENAI_BASE_URL='https://models.example.com/v1'   # replace this
umask 077
mkdir -p ~/secrets ~/openwebui-helm
```

`CLOUDFLARED_IMAGE` is the current tag as of this guide (September 2026). Keep this terminal open, or re-export the variables if you start a new one.

---

## 1. Confirm the right cluster

```bash
kubectl config current-context
kubectl get nodes -o wide
kubectl get ns
kubectl get storageclass
export STORAGE_CLASS=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
echo "STORAGE_CLASS=${STORAGE_CLASS}"
helm version
curl -sI https://api.cloudflare.com | head -n 1
```

**Expect:** one `Ready` node; namespace `jhub`; a default StorageClass (often `local-path`); Helm 3; an HTTP header from Cloudflare.

If `STORAGE_CLASS` is empty:

```bash
export STORAGE_CLASS=local-path
```

Stop if you see namespace `matomo` or `n8n` (that is host A) or only OpenProject (wrong kubeconfig).

If `OPENAI_BASE_URL` is still `https://models.example.com/v1`, stop and set the real URL. The pod must be able to reach it.

---

## 2. Namespace and Helm repo

```bash
kubectl create namespace openwebui
helm repo add open-webui https://open-webui.github.io/helm-charts
helm repo update
```

If the namespace already exists, reuse it. Do not delete it.

---

## 3. Signing key and model API key

Generate the signing key once. Later restores need this same value. A lost key means existing sessions and encrypted data cannot be reused.

```bash
openssl rand -hex 32 | tee ~/secrets/openwebui-secret-key.txt >/dev/null
chmod 600 ~/secrets/openwebui-secret-key.txt

nano ~/secrets/openwebui-secrets.env
```

Put these two lines in that file. No quotes, no extra spaces. Replace the API key with the key for `OPENAI_BASE_URL`. A local server that ignores the key still needs a non-empty value.

```text
WEBUI_SECRET_KEY=<paste the contents of ~/secrets/openwebui-secret-key.txt>
OPENAI_API_KEY=<your model API key>
```

```bash
chmod 600 ~/secrets/openwebui-secrets.env

kubectl -n openwebui create secret generic openwebui-secrets \
  --from-env-file="$HOME/secrets/openwebui-secrets.env"

kubectl -n openwebui get secret openwebui-secrets
```

**Expect:** secret `openwebui-secrets`. Do not `kubectl get secret -o yaml` into chat or git.

---

## 4. Helm values (single replica)

Chart and application versions are separate. Both pins come from the official page.

```bash
cat > ~/openwebui-helm/values-common.yaml <<EOF
fullnameOverride: openwebui
workload:
  kind: Deployment
strategy:
  type: Recreate
image:
  repository: ghcr.io/open-webui/open-webui
  tag: ${OPENWEBUI_IMAGE_TAG}
ollama:
  enabled: false
pipelines:
  enabled: false
terminals:
  enabled: false
tika:
  enabled: false
service:
  type: ClusterIP
  port: 80
openaiBaseApiUrl: "${OPENAI_BASE_URL}"
openaiApiKeyExistingSecret: openwebui-secrets
openaiApiKeyExistingSecretKey: OPENAI_API_KEY
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: "2"
    memory: 4Gi
startupProbe:
  httpGet:
    path: /health
    port: http
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 60
readinessProbe:
  httpGet:
    path: /health/db
    port: http
  periodSeconds: 10
  timeoutSeconds: 5
livenessProbe:
  httpGet:
    path: /health
    port: http
  periodSeconds: 30
  timeoutSeconds: 5
  failureThreshold: 3
extraEnvVars:
  WEBUI_URL: https://chat.willyrv.com
  WEBUI_SECRET_KEY:
    valueFrom:
      secretKeyRef:
        name: openwebui-secrets
        key: WEBUI_SECRET_KEY
  UVICORN_WORKERS: "1"
EOF

cat > ~/openwebui-helm/values-single.yaml <<EOF
replicaCount: 1
websocket:
  enabled: true
  manager: ""
  redis:
    enabled: false
persistence:
  enabled: true
  provider: local
  storageClass: ${STORAGE_CLASS}
  accessModes:
    - ReadWriteOnce
  size: 10Gi
  annotations:
    helm.sh/resource-policy: keep
ingress:
  enabled: false
extraEnvVars:
  ENABLE_DB_MIGRATIONS: "true"
EOF

chmod 600 ~/openwebui-helm/values-common.yaml ~/openwebui-helm/values-single.yaml
```

`WEBUI_URL` has to be the public HTTPS hostname on the **first** start. Open WebUI stores many settings in its database after that, and a later environment change may not override them.

One replica and `UVICORN_WORKERS=1` stay at one. More than one writer on this SQLite file is the failure mode the official page warns about.

The `keep` annotation retains the PVC if you later `helm uninstall`.

---

## 5. Render, then install

Helm may warn that `extraEnvVars` coalesces a map onto the chart’s default list. Check the render before installing.

```bash
cd ~/openwebui-helm

helm template openwebui open-webui/open-webui \
  --version "${OPENWEBUI_CHART_VERSION}" --namespace openwebui \
  -f values-common.yaml -f values-single.yaml \
  --set replicaCount=1 --set ingress.enabled=false \
  --set-string extraEnvVars.ENABLE_DB_MIGRATIONS=true > rendered.yaml

grep -n 'WEBUI_SECRET_KEY\|OPENAI_API_KEY\|ENABLE_DB_MIGRATIONS\|storageClass:' rendered.yaml
echo "---- default key must be absent ----"
if grep -n '0p3n-w3bu!' rendered.yaml; then
  echo "STOP: chart default API key is in the render. Fix openaiApiKeyExistingSecret before install."
  exit 1
fi
echo "default API key absent"
```

**Expect:** `secretKeyRef` entries for `WEBUI_SECRET_KEY` and `OPENAI_API_KEY`, `ENABLE_DB_MIGRATIONS` true, and your StorageClass. No `0p3n-w3bu!` (that string is the chart’s built-in placeholder). No Ollama Deployment.

```bash
helm install openwebui open-webui/open-webui \
  --version "${OPENWEBUI_CHART_VERSION}" --namespace openwebui \
  -f values-common.yaml -f values-single.yaml \
  --set replicaCount=1 --set ingress.enabled=false \
  --set-string extraEnvVars.ENABLE_DB_MIGRATIONS=true \
  --wait --timeout 15m

kubectl -n openwebui rollout status deployment/openwebui --timeout=10m
kubectl -n openwebui get pods,pvc,services
```

**Expect:** one Ready pod, PVC `openwebui` Bound, Service `openwebui` ClusterIP port 80. The first pull from `ghcr.io` can take several minutes. The startup probe allows about 10 minutes.

If Helm says the release already exists, rerun the same command with `helm upgrade` instead of `helm install`. Do not add replicas.

---

## 6. First admin, before the hostname is public

Leave this running:

```bash
kubectl -n openwebui port-forward service/openwebui 3000:80
```

Open `http://127.0.0.1:3000` on the machine where that command runs (the host, or your laptop if `kubectl` is remote).

1. Create the first account. That user is the administrator.
2. In the admin settings, turn **off** open sign-up.
3. **Admin Panel → Settings → Connections**: confirm the model URL, pick a chat model, send one message.
4. Stop the port-forward (Ctrl-C).

If no models appear, the pod cannot reach `OPENAI_BASE_URL`, or the API key is wrong. Check logs (troubleshooting below). Do not put the tunnel up until this UI works and sign-up is off. Cloudflare Access is a second gate, not a replacement for a closed sign-up.

---

## 7. Cloudflare Tunnel + Access

Do this in the browser before `cloudflared` exists for this app. JupyterHub’s tunnel on this host stays as it is. This app gets its own tunnel.

### 7.1 Tunnel + token

1. Open [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) → **Networks** → **Tunnels** → **Create**.
2. Type: **Cloudflared**. Name: `homelab-openwebui`.
3. Copy the tunnel token (starts with `eyJ`).

```bash
nano ~/secrets/openwebui-tunnel-token.txt
# one line, no quotes
chmod 600 ~/secrets/openwebui-tunnel-token.txt
```

### 7.2 Public hostname

On that tunnel → **Public Hostname** → **Add**:

| Field | Value |
|-------|--------|
| Subdomain | `chat` |
| Domain | `willyrv.com` |
| Type | HTTP |
| URL | `openwebui.openwebui.svc.cluster.local:80` |

DNS for `chat.willyrv.com` should be **proxied** (orange cloud).

### 7.3 Access

**Access controls** → **Applications** → **Add** → **Self-hosted**.

| Field | Value |
|-------|--------|
| Application name | `openwebui` |
| Hostname | `chat.willyrv.com` |
| Path | *(leave empty)* |
| Session duration | 24 hours |
| Policy | **Allow** → Include → **Emails** → your address |
| Login | Google (or your existing IdP). Prefer Google over emailed one-time PIN if Gmail drops the PIN |

No Bypass apps. The whole UI stays behind Access.

```bash
dig +short chat.willyrv.com
```

**Expect:** Cloudflare anycast IPs, not your home public IP as the only answer.

### 7.4 cloudflared

The heredoc is unquoted so `${CLOUDFLARED_IMAGE}` expands. The backslash keeps `$(TUNNEL_TOKEN)` for the container.

```bash
cat > /tmp/openwebui-cloudflared.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: openwebui
  labels:
    app: cloudflared
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
          image: ${CLOUDFLARED_IMAGE}
          args:
            - tunnel
            - --no-autoupdate
            - run
            - --token
            - \$(TUNNEL_TOKEN)
          env:
            - name: TUNNEL_TOKEN
              valueFrom:
                secretKeyRef:
                  name: cloudflare-tunnel-token
                  key: token
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 256Mi
EOF

kubectl -n openwebui create secret generic cloudflare-tunnel-token \
  --from-literal=token="$(cat ~/secrets/openwebui-tunnel-token.txt)"

grep -n 'TUNNEL_TOKEN' /tmp/openwebui-cloudflared.yaml
kubectl apply -f /tmp/openwebui-cloudflared.yaml
rm -f /tmp/openwebui-cloudflared.yaml

kubectl -n openwebui rollout status deploy/cloudflared --timeout=120s
kubectl -n openwebui logs deploy/cloudflared --tail=40
```

**Expect:** `grep` shows `$(TUNNEL_TOKEN)`. Logs show the tunnel connected. Zero Trust → Tunnels → `homelab-openwebui` → **Healthy**.

```bash
curl -sI https://chat.willyrv.com/ | head -n 20
```

**Expect:** a redirect or challenge to Cloudflare Access, not the Open WebUI page with no login.

Private window: `https://chat.willyrv.com/` → Access → the account from section 6. Sign-up for a second account should be refused.

---

## 8. Persistence check

```bash
kubectl -n openwebui rollout restart deployment/openwebui
kubectl -n openwebui rollout status deployment/openwebui --timeout=10m
```

Open the site again. The account and the chat from section 6 are still there.

A Ready pod only means `/health` and `/health/db` passed. It does not prove the model API is up.

---

## 9. Backup (host disk, not git)

Keep the signing key with the data. The PVC is not a backup.

```bash
kubectl -n openwebui exec deploy/openwebui -c open-webui -- \
  tar -C /app/backend/data -cf - . \
  > ~/secrets/openwebui-data-$(date +%Y%m%d).tar

chmod 600 ~/secrets/openwebui-data-*.tar ~/secrets/openwebui-secret-key.txt ~/secrets/openwebui-secrets.env ~/secrets/openwebui-tunnel-token.txt
ls -la ~/secrets/openwebui-data-*.tar ~/secrets/openwebui-secret-key.txt ~/secrets/openwebui-tunnel-token.txt
```

Also keep `~/openwebui-helm/values-common.yaml` and `values-single.yaml` (they contain the public URL and StorageClass, not the API key).

---

## 10. Done checklist

```text
[ ] kubectl is teaching GPU host B (namespace jhub, not matomo/n8n)
[ ] helm release openwebui, one Ready pod, PVC openwebui Bound
[ ] ollama / pipelines / redis were not installed
[ ] first admin created via port-forward; open sign-up is off
[ ] one chat completed against OPENAI_BASE_URL
[ ] curl https://chat.willyrv.com/ is an Access challenge
[ ] dashboard needs Access AND the Open WebUI account
[ ] chat still present after rollout restart
[ ] ~/secrets has the data tar, signing key, API key file, and tunnel token
```

When that list is true, tell me what happened (model URL type, StorageClass, any Helm warning). I will then mark `docs/apps/openwebui.md` implemented and update topology.

---

## Troubleshooting

**Wrong cluster.** `kubectl get ns` shows `matomo` or `n8n` → host A. Only OpenProject → wrong kubeconfig.

**Pending pod or PVC.** `kubectl -n openwebui describe pod -l app.kubernetes.io/name=open-webui` and `kubectl -n openwebui get pvc`. StorageClass name must match `STORAGE_CLASS`. This profile needs a local or block volume, not NFS.

**ImagePullBackOff.** The node must reach `ghcr.io`. Tag is `v0.11.3`. Init container `copy-app-data` failures show up in `kubectl -n openwebui describe pod`.

**Helm timeout.** `helm status openwebui -n openwebui`, then `kubectl -n openwebui logs deployment/openwebui -c open-webui --tail=100`. First start can sit on the startup probe while the image unpacks.

**`0p3n-w3bu!` in a render.** The Secret reference did not apply. Fix `openaiApiKeyExistingSecret` and template again before `helm install`.

**No models / chat errors.** Admin → Settings → Connections, and pod logs. `OPENAI_BASE_URL` must include `/v1` and be reachable from the pod, not only from your laptop.

**Login loop after restart.** The signing key in the Secret changed, or `WEBUI_URL` was not `https://chat.willyrv.com` on first boot.

**Tunnel not Healthy.** Token file is one line, no quotes. Live args must contain `$(TUNNEL_TOKEN)`. Host must reach `https://api.cloudflare.com`.

**Access OTP never arrives.** Use Google as the Access login method.

---

## Updates (later)

Do not `helm upgrade` to a newer chart or image as part of this install. When you do upgrade, follow [Updates and Recovery](https://docs.openwebui.com/deployment/kubernetes) on the official page: scale to zero, back up the PVC and the signing key, then upgrade with **one** migration-enabled replica. Helm rollback does not undo database migrations.

Uninstall, when you mean it:

```bash
helm uninstall openwebui --namespace openwebui
kubectl -n openwebui get pvc openwebui
```

The keep annotation should leave PVC `openwebui`. Deleting the namespace deletes that PVC and the Secrets.
