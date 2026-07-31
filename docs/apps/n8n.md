# n8n

Status: Implemented (single-node K3s)

## Purpose

[n8n](https://github.com/n8n-io/n8n) is an open-source workflow automation platform. It is useful for personal automation and teaching: notifications, light integrations, and demos that glue self-hosted services together without putting critical paths solely in a SaaS tool.

## Placement

Validated on a **single-node K3s** cluster (namespace `n8n`) with:

- PostgreSQL in-cluster (Helm) for workflow state
- n8n Helm chart with a data PVC
- Cloudflare Tunnel (`cloudflared`) to the n8n ClusterIP Service
- Cloudflare Access protecting the editor UI

When the lab grows to multiple nodes, schedule n8n on the compute node; keep the same namespace and Service names so the Tunnel URL does not change.

Do **not** publish n8n or Postgres via NodePort / host ports. Public HTTPS terminates at Cloudflare.

## Architecture

```text
Internet users (allowlisted via Cloudflare Access)
        │
        ▼
Cloudflare Access
        │
        ▼
Cloudflare Edge (HTTPS)
        │
        ▼
Cloudflare Tunnel (outbound from the cluster)
        │
        ▼
cloudflared Pod  ──►  n8n Service :5678
                         │
           ┌─────────────┴─────────────┐
           ▼                           ▼
    PostgreSQL PVC              n8n data PVC
```

| Piece | Choice |
|-------|--------|
| Namespace | `n8n` |
| n8n | 8gears Helm chart (`oci://8gears.container-registry.com/library/n8n`) |
| PostgreSQL | Bitnami PostgreSQL Helm chart (standalone); see fallback note below |
| Storage | Default StorageClass (often `local-path` on K3s) |
| Tunnel | `cloudflared` Deployment + Secret (tunnel token) |
| Auth | Cloudflare Access on the hostname |
| Secrets | Kubernetes Secrets (not committed to Git) |

Design reference: [2026-07-31 n8n K3s Cloudflare design](../superpowers/specs/2026-07-31-n8n-k3s-cloudflare-design.md).

## Exposure policy

- **Editor UI:** Cloudflare Tunnel + Cloudflare Access (email allowlist / OTP). Suitable for personal use and invited teaching accounts.
- **Webhooks (v1):** Same Access gate, or unused. A separate public webhook hostname needs its own design (auth, rate limits) before production use.
- **Break-glass admin:** Host SSH / future WireGuard remain independent of Cloudflare.

## Install guide (single-node K3s)

Replace `n8n.example.net` with your Access-protected hostname. Never commit real tokens, passwords, or encryption keys.

### 1. Prerequisites

```bash
kubectl get nodes -o wide
helm version
kubectl get storageclass
curl -sI https://api.cloudflare.com | head -n 1

export STORAGE_CLASS=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
echo "STORAGE_CLASS=${STORAGE_CLASS}"
```

Expect one Ready node, Helm 3.x, a default StorageClass (e.g. `local-path`), and outbound HTTPS to Cloudflare.

### 2. Cloudflare Tunnel and Access

In [Cloudflare Zero Trust](https://one.dash.cloudflare.com/):

1. **Networks → Tunnels → Create** (Cloudflared). Save the tunnel token locally only:

```bash
umask 077
mkdir -p ~/secrets
nano ~/secrets/n8n-tunnel-token.txt   # paste eyJ... token, one line
chmod 600 ~/secrets/n8n-tunnel-token.txt
```

2. **Public hostname** on the tunnel:

| Field | Value |
|-------|--------|
| Hostname | `n8n.example.net` |
| Type | HTTP |
| URL | `n8n.n8n.svc.cluster.local:5678` |

3. **Access → Applications → Self-hosted** on `n8n.example.net`, Allow policy for your email(s), One-time PIN (or IdP).

DNS for the hostname should resolve to Cloudflare anycast IPs (proxied). No router port forwards are required.

### 3. Namespace and Secrets

```bash
kubectl create namespace n8n

umask 077
mkdir -p ~/secrets
openssl rand -hex 32 | tee ~/secrets/n8n-encryption-key.txt >/dev/null
openssl rand -hex 24 | tee ~/secrets/n8n-db-password.txt >/dev/null

kubectl -n n8n create secret generic n8n-db-auth \
  --from-literal=postgres-password="$(cat ~/secrets/n8n-db-password.txt)" \
  --from-literal=password="$(cat ~/secrets/n8n-db-password.txt)" \
  --from-literal=username=n8n \
  --from-literal=database=n8n

kubectl -n n8n create secret generic n8n-app-secrets \
  --from-literal=N8N_ENCRYPTION_KEY="$(cat ~/secrets/n8n-encryption-key.txt)"

kubectl -n n8n create secret generic cloudflare-tunnel-token \
  --from-literal=token="$(cat ~/secrets/n8n-tunnel-token.txt)"

kubectl -n n8n get secrets
```

### 4. PostgreSQL (Helm)

```bash
export STORAGE_CLASS=local-path   # or your default from step 1

helm show chart oci://registry-1.docker.io/bitnamicharts/postgresql | sed -n '1,20p'
export BITNAMI_PG_CHART_VERSION='PASTE_VERSION_HERE'

cat > ~/secrets/n8n-postgresql-values.yaml <<EOF
architecture: standalone
auth:
  username: n8n
  database: n8n
  existingSecret: n8n-db-auth
  secretKeys:
    adminPasswordKey: postgres-password
    userPasswordKey: password
primary:
  persistence:
    enabled: true
    storageClass: ${STORAGE_CLASS}
    size: 20Gi
  resources:
    requests:
      cpu: "250m"
      memory: 512Mi
    limits:
      cpu: "1"
      memory: 2Gi
EOF

helm upgrade --install n8n-postgresql \
  oci://registry-1.docker.io/bitnamicharts/postgresql \
  --version "${BITNAMI_PG_CHART_VERSION}" \
  --namespace n8n \
  --values ~/secrets/n8n-postgresql-values.yaml \
  --wait --timeout 10m

kubectl -n n8n get pods,svc,pvc
```

If the Postgres pod stays in `ImagePullBackOff` (Bitnami registry login), uninstall and use a chart that pulls the official `postgres` image (e.g. [groundhog2k/postgres](https://artifacthub.io/packages/helm/groundhog2k/postgres)), keeping Service name `n8n-postgresql` and user/database `n8n` where possible. See the [implementation plan](../superpowers/plans/2026-07-31-n8n-k3s-cloudflare.md) fallback section.

Smoke test (password stays on the host; prefer non-interactive attach if your kubectl version warns about `-it`):

```bash
kubectl -n n8n run psql-smoke --rm -it --restart=Never \
  --image=docker.io/library/postgres:16-alpine \
  --env="PGPASSWORD=$(cat ~/secrets/n8n-db-password.txt)" \
  --command -- psql -h n8n-postgresql -U n8n -d n8n -c 'SELECT 1;'
```

### 5. n8n (Helm)

```bash
export POSTGRES_HOST=n8n-postgresql.n8n.svc.cluster.local

helm show chart oci://8gears.container-registry.com/library/n8n | sed -n '1,25p'
export N8N_CHART_VERSION='PASTE_VERSION_HERE'
helm show values oci://8gears.container-registry.com/library/n8n --version "${N8N_CHART_VERSION}" | sed -n '1,120p'

ENCRYPTION_KEY=$(cat ~/secrets/n8n-encryption-key.txt)
DB_PASSWORD=$(cat ~/secrets/n8n-db-password.txt)

cat > ~/secrets/n8n-values.yaml <<EOF
fullnameOverride: n8n

image:
  repository: n8nio/n8n
  pullPolicy: IfNotPresent

ingress:
  enabled: false

main:
  config:
    n8n:
      host: "n8n.example.net"
      protocol: "https"
      editor_base_url: "https://n8n.example.net/"
      webhook_url: "https://n8n.example.net/"
      port: 5678
      proxy_hops: 1
      secure_cookie: true
      diagnostics_enabled: false
    db:
      type: postgresdb
      postgresdb:
        host: "${POSTGRES_HOST}"
        port: 5432
        database: n8n
        user: n8n
  secret:
    n8n:
      encryption_key: "${ENCRYPTION_KEY}"
    db:
      postgresdb:
        password: "${DB_PASSWORD}"
  persistence:
    enabled: true
    type: dynamic
    storageClass: "${STORAGE_CLASS}"
    size: 10Gi
    accessModes:
      - ReadWriteOnce
  resources:
    requests:
      cpu: "500m"
      memory: 1Gi
    limits:
      cpu: "2"
      memory: 4Gi
  service:
    type: ClusterIP
    port: 5678
EOF

helm upgrade --install n8n \
  oci://8gears.container-registry.com/library/n8n \
  --version "${N8N_CHART_VERSION}" \
  --namespace n8n \
  --values ~/secrets/n8n-values.yaml \
  --wait --timeout 10m

kubectl -n n8n get pods,svc,pvc,deploy
kubectl -n n8n logs deploy/n8n --tail=50
```

Logs should show successful migrations and something like `Editor is now accessible via: https://n8n.example.net`. Adapt `main.config` / `main.secret` keys if your chart version renames them (`helm show values`).

### 6. cloudflared

```bash
kubectl -n n8n apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: n8n
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
          image: cloudflare/cloudflared:2025.8.1
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

kubectl -n n8n rollout status deploy/cloudflared --timeout=120s
kubectl -n n8n logs deploy/cloudflared --tail=40
```

Confirm the Tunnel is **Healthy** in Zero Trust. Open `https://n8n.example.net` in a private window: Access challenge first, then n8n setup/login.

### 7. Verify and back up

- Create a small workflow in the UI, delete the n8n pod, confirm the workflow remains after restart.
- Keep offline copies of `~/secrets/n8n-encryption-key.txt`, the DB password, the tunnel token, and periodic Postgres dumps:

```bash
kubectl -n n8n exec statefulset/n8n-postgresql -- \
  env PGPASSWORD="$(cat ~/secrets/n8n-db-password.txt)" \
  pg_dump -U n8n -d n8n > ~/secrets/n8n-pg-dump-$(date +%Y%m%d).sql
```

(Adjust the exec target if your Postgres workload is not a StatefulSet named `n8n-postgresql`.)

Without the encryption key, credential fields inside workflows cannot be decrypted after restore.

## Follow-ups

- Public webhook hostname with authentication and rate limiting
- Shared Tunnel in front of Traefik for many apps
- CloudNativePG instead of Bitnami/standalone Postgres
- SOPS + Flux when a separate GitOps repo exists
- Address n8n env deprecations (`N8N_RUNNERS_ENABLED`, security-related defaults) when convenient

## See also

- [Networking and exposure](../architecture/networking.md)
- [GitOps layout](../architecture/gitops-layout.md)
- [Phase 4 — low-risk apps](../guides/phase-04-low-risk-apps.md)
- [Phase 7 — operations](../guides/phase-07-operations.md)
- [Experience: n8n on single-node K3s](../experiences/2026-07-31-n8n-k3s-cloudflare.md)
- Design: [2026-07-31-n8n-k3s-cloudflare-design.md](../superpowers/specs/2026-07-31-n8n-k3s-cloudflare-design.md)
- Plan: [2026-07-31-n8n-k3s-cloudflare.md](../superpowers/plans/2026-07-31-n8n-k3s-cloudflare.md)
- Upstream: https://github.com/n8n-io/n8n
