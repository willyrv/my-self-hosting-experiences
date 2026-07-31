# n8n on single-node K3s + Cloudflare Tunnel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy personal/teaching n8n on the existing single-node K3s cluster with PostgreSQL, Cloudflare Tunnel, and Cloudflare Access, then update the handbook to match.

**Architecture:** Namespace `n8n` holds a PostgreSQL Helm release, an n8n Helm release (8gears OCI chart) with PVCs, and a `cloudflared` Deployment that dials the n8n ClusterIP Service. Cloudflare terminates HTTPS and Access gates the editor UI. No Traefik Ingress for n8n in v1.

**Tech Stack:** K3s, Helm 3, 8gears n8n chart (`oci://8gears.container-registry.com/library/n8n`), PostgreSQL via Bitnami chart with groundhog2k/postgres fallback (official `postgres` image), `cloudflare/cloudflared`, Cloudflare Zero Trust Tunnel + Access.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-31-n8n-k3s-cloudflare-design.md`
- Single-node K3s already installed; do not reinstall K3s.
- Namespace: `n8n`.
- Secrets (tunnel token, DB password, `N8N_ENCRYPTION_KEY`) stay in Kubernetes Secrets — never commit real values.
- Handbook placeholders only: `n8n.example.net`, `you@example.com` — no real domains/emails/tokens in git.
- Cloudflare Access is mandatory for the editor hostname in v1.
- No public unauthenticated webhooks in v1.
- No Traefik / cert-manager path for n8n in v1.
- No Flux/SOPS yet; in-cluster Secrets are acceptable.
- This docs repo remains documentation-first: example YAML in `docs/apps/n8n.md` uses placeholders; do not add a live GitOps `clusters/` tree.
- Prefer exact commands an engineer can copy; pin chart versions discovered at install time into the handbook notes.

## File Structure

| Path | Responsibility |
|------|----------------|
| `docs/apps/n8n.md` | Lived app runbook: Helm values examples, Tunnel+Access, PVCs, backups, verify steps |
| `docs/architecture/networking.md` | Short Cloudflare Tunnel + Access alternate exposure note + link to n8n |
| `docs/experiences/2026-07-31-n8n-k3s-cloudflare.md` | Dated personal log after successful install (optional if install happens same session) |
| Cluster (not in git) | Namespace, Secrets, Helm releases, `cloudflared` Deployment |

Working directory for handbook edits:

```bash
cd /media/willy/DATA1/github_willyrv/my-self-hosting-experiences
```

Cluster commands assume `kubectl` talks to the single-node K3s API (default kubeconfig).

---

### Task 1: Verify cluster prerequisites

**Files:**
- Modify: none (read-only cluster checks)
- Test: shell verification commands below

**Interfaces:**
- Consumes: existing K3s install
- Produces: confirmed StorageClass name (record as `STORAGE_CLASS`), Helm 3 available, node Ready

- [ ] **Step 1: Confirm node and API health**

```bash
kubectl get nodes -o wide
kubectl get --raw='/readyz?verbose' | head
```

Expected: one node `Ready`; readyz reports `ok` / healthy handlers.

- [ ] **Step 2: Confirm Helm and default StorageClass**

```bash
helm version
kubectl get storageclass
```

Expected: Helm v3.x. Note the default StorageClass (often `local-path` on K3s). Export it:

```bash
export STORAGE_CLASS=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
echo "STORAGE_CLASS=${STORAGE_CLASS}"
```

If empty, set explicitly: `export STORAGE_CLASS=local-path` (or the name you intend to use).

- [ ] **Step 3: Confirm outbound HTTPS from the node (Tunnel requirement)**

```bash
curl -sI https://api.cloudflare.com | head -n 1
```

Expected: an HTTP response header line (not a connection failure).

- [ ] **Step 4: Commit nothing**

No repo changes in this task.

---

### Task 2: Create Cloudflare Tunnel, DNS hostname, and Access policy

**Files:**
- Modify: none in git (Cloudflare dashboard / `cloudflared` login on operator machine)
- Test: Cloudflare Zero Trust UI shows tunnel + hostname + Access app

**Interfaces:**
- Consumes: Cloudflare account with domain already onboarded
- Produces: Tunnel token string (operator keeps offline); public hostname `n8n.<your-domain>` routed to `http://n8n.n8n.svc.cluster.local:5678`; Access allowlist

- [ ] **Step 1: Create a Tunnel in Cloudflare Zero Trust**

In Zero Trust → Networks → Tunnels → Create a tunnel:

1. Choose **Cloudflared**.
2. Name it `homelab-n8n` (or similar).
3. Copy the **tunnel token** (starts with `eyJ...`) into a local scratch file that is **not** in the git repo, e.g. `~/secrets/n8n-tunnel-token.txt` with mode `600`.

- [ ] **Step 2: Add a public hostname on the Tunnel**

In the tunnel’s Public Hostname tab:

| Field | Value |
|-------|-------|
| Subdomain | `n8n` |
| Domain | your Cloudflare zone |
| Type | HTTP |
| URL | `n8n.n8n.svc.cluster.local:5678` |

Save. DNS CNAME for `n8n.<domain>` should be created automatically (proxied).

Note: The Kubernetes Service `n8n` in namespace `n8n` does not exist yet; that is expected until Task 5. The Tunnel connector will reconnect once the Service is up.

- [ ] **Step 3: Create Cloudflare Access application**

Zero Trust → Access → Applications → Add an application → Self-hosted:

| Field | Value |
|-------|-------|
| Application name | `n8n` |
| Session duration | e.g. 24 hours |
| Application domain | `n8n.<your-domain>` |

Policy (Allow):

- Include → Emails → your address (and teaching invitees later)
- Or Include → Emails ending in → your domain if appropriate

Authentication: One-time PIN (email OTP) is enough for v1 unless you already use an IdP.

- [ ] **Step 4: Sanity-check DNS**

```bash
# Replace with your real hostname locally; do not commit the real name
dig +short n8n.YOUR_DOMAIN_HERE
```

Expected: Cloudflare anycast IPs (proxied), not your home public IP alone as the only story.

- [ ] **Step 5: Commit nothing**

---

### Task 3: Namespace and Kubernetes Secrets

**Files:**
- Cluster only (Secrets not committed)
- Test: `kubectl get secret -n n8n`

**Interfaces:**
- Consumes: tunnel token file; generated encryption key and DB password
- Produces: namespace `n8n`; secrets `n8n-db-auth`, `n8n-app-secrets`, `cloudflare-tunnel-token`

- [ ] **Step 1: Create namespace**

```bash
kubectl create namespace n8n
```

Expected: `namespace/n8n created` (or already exists).

- [ ] **Step 2: Generate local secret material (do not commit)**

```bash
umask 077
mkdir -p ~/secrets
openssl rand -hex 32 | tee ~/secrets/n8n-encryption-key.txt >/dev/null
openssl rand -hex 24 | tee ~/secrets/n8n-db-password.txt >/dev/null
# Tunnel token already at ~/secrets/n8n-tunnel-token.txt from Task 2
```

- [ ] **Step 3: Create DB auth Secret**

```bash
kubectl -n n8n create secret generic n8n-db-auth \
  --from-literal=postgres-password="$(cat ~/secrets/n8n-db-password.txt)" \
  --from-literal=password="$(cat ~/secrets/n8n-db-password.txt)" \
  --from-literal=username=n8n \
  --from-literal=database=n8n
```

- [ ] **Step 4: Create n8n app Secret (encryption key)**

```bash
kubectl -n n8n create secret generic n8n-app-secrets \
  --from-literal=N8N_ENCRYPTION_KEY="$(cat ~/secrets/n8n-encryption-key.txt)"
```

- [ ] **Step 5: Create Tunnel token Secret**

```bash
kubectl -n n8n create secret generic cloudflare-tunnel-token \
  --from-literal=token="$(cat ~/secrets/n8n-tunnel-token.txt)"
```

- [ ] **Step 6: Verify secrets exist (names only)**

```bash
kubectl -n n8n get secrets
```

Expected: `n8n-db-auth`, `n8n-app-secrets`, `cloudflare-tunnel-token` listed. Do not `kubectl get secret -o yaml` into chat logs or git.

---

### Task 4: Install PostgreSQL with Helm

**Files:**
- Cluster: Helm release `n8n-postgresql`
- Handbook examples later in Task 8

**Interfaces:**
- Consumes: `n8n` namespace, `n8n-db-auth`, `STORAGE_CLASS`
- Produces: Service reachable as Postgres for n8n — prefer DNS name recorded as `POSTGRES_HOST`

**Primary path (Bitnami).** If the pod stays in `ImagePullBackOff` because Bitnami images require a paid/login registry, use the **Fallback** subsection (groundhog2k) without changing namespace or secret names more than noted.

- [ ] **Step 1: Discover a Bitnami chart version**

```bash
helm show chart oci://registry-1.docker.io/bitnamicharts/postgresql | sed -n '1,20p'
```

Record `version:` as `BITNAMI_PG_CHART_VERSION`.

- [ ] **Step 2: Write local values file (outside git)**

```bash
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
```

- [ ] **Step 3: Install Bitnami PostgreSQL**

```bash
helm upgrade --install n8n-postgresql \
  oci://registry-1.docker.io/bitnamicharts/postgresql \
  --version "${BITNAMI_PG_CHART_VERSION}" \
  --namespace n8n \
  --values ~/secrets/n8n-postgresql-values.yaml \
  --wait --timeout 10m
```

- [ ] **Step 4: Verify Postgres pod and set host**

```bash
kubectl -n n8n get pods,svc,pvc
export POSTGRES_HOST=n8n-postgresql.n8n.svc.cluster.local
echo "POSTGRES_HOST=${POSTGRES_HOST}"
```

Expected: StatefulSet/pod Ready; PVC Bound; Service `n8n-postgresql` present.

If **ImagePullBackOff**, uninstall and use fallback:

```bash
helm -n n8n uninstall n8n-postgresql
```

#### Fallback: groundhog2k/postgres (official `postgres` image)

```bash
helm repo add groundhog2k https://groundhog2k.github.io/helm-charts/
helm repo update
helm search repo groundhog2k/postgres --versions | head
```

Pick a chart version as `GH2K_PG_CHART_VERSION`.

```bash
cat > ~/secrets/n8n-postgresql-values.yaml <<EOF
fullNameOverride: n8n-postgresql
settings:
  superuser:
    password: $(cat ~/secrets/n8n-db-password.txt)
# groundhog2k key names vary by chart version — after install, confirm with:
#   helm show values groundhog2k/postgres --version \$GH2K_PG_CHART_VERSION
# Adjust user/database creation to match chart docs so user=n8n db=n8n exist.
# Minimum requirement: POSTGRES_HOST Service name n8n-postgresql on port 5432.
storage:
  className: ${STORAGE_CLASS}
  requestedSize: 20Gi
resources:
  limits:
    cpu: "1"
    memory: 2Gi
  requests:
    cpu: "250m"
    memory: 512Mi
EOF
```

Because groundhog2k value keys differ by version, run:

```bash
helm show values groundhog2k/postgres --version "${GH2K_PG_CHART_VERSION}" | less
```

Then set `username`/`database`/`password` (or equivalent) to `n8n` / `n8n` / password from `~/secrets/n8n-db-password.txt`, `fullNameOverride` or service name to `n8n-postgresql`, persistence on `${STORAGE_CLASS}`, and install:

```bash
helm upgrade --install n8n-postgresql groundhog2k/postgres \
  --version "${GH2K_PG_CHART_VERSION}" \
  --namespace n8n \
  --values ~/secrets/n8n-postgresql-values.yaml \
  --wait --timeout 10m
export POSTGRES_HOST=n8n-postgresql.n8n.svc.cluster.local
```

- [ ] **Step 5: Smoke-test SQL connectivity from a throwaway pod**

```bash
kubectl -n n8n run psql-smoke --rm -it --restart=Never \
  --image=docker.io/library/postgres:16-alpine \
  --env="PGPASSWORD=$(cat ~/secrets/n8n-db-password.txt)" \
  --command -- psql -h n8n-postgresql -U n8n -d n8n -c 'SELECT 1;'
```

Expected: `?column?` / `1` and pod deleted on exit.

---

### Task 5: Install n8n with Helm (8gears chart)

**Files:**
- Cluster: Helm release `n8n`
- Local values: `~/secrets/n8n-values.yaml` (not committed)

**Interfaces:**
- Consumes: `POSTGRES_HOST`, secrets `n8n-db-auth` / `n8n-app-secrets`, StorageClass
- Produces: Service `n8n` on port `5678` (via `fullnameOverride: n8n`)

- [ ] **Step 1: Discover chart version**

```bash
helm show chart oci://8gears.container-registry.com/library/n8n | sed -n '1,25p'
```

Record version as `N8N_CHART_VERSION` (prefer a current 1.x/2.x release that matches Artifact Hub).

- [ ] **Step 2: Inspect values shape for this version**

```bash
helm show values oci://8gears.container-registry.com/library/n8n --version "${N8N_CHART_VERSION}" | sed -n '1,120p'
```

Confirm `main.config` / `main.secret` / `main.persistence` / `main.extraEnv` keys exist as in the 8gears README. If the chart renamed keys, adapt Step 3 to the shown schema while keeping the same env semantics (`DB_TYPE=postgresdb`, host, user, database, password, encryption key, public URL).

- [ ] **Step 3: Write n8n values (placeholders shown; substitute real hostname locally)**

Replace `n8n.YOUR_DOMAIN_HERE` with the Access-protected hostname from Task 2.

```bash
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
      host: "n8n.YOUR_DOMAIN_HERE"
      protocol: "https"
      editor_base_url: "https://n8n.YOUR_DOMAIN_HERE/"
      webhook_url: "https://n8n.YOUR_DOMAIN_HERE/"
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
```

- [ ] **Step 4: Install / upgrade n8n**

```bash
helm upgrade --install n8n \
  oci://8gears.container-registry.com/library/n8n \
  --version "${N8N_CHART_VERSION}" \
  --namespace n8n \
  --values ~/secrets/n8n-values.yaml \
  --wait --timeout 10m
```

- [ ] **Step 5: Verify Deployment/Service/PVC**

```bash
kubectl -n n8n get pods,svc,pvc
kubectl -n n8n logs deploy/n8n --tail=80
```

Expected: n8n pod Ready; Service `n8n` port 5678; n8n PVC Bound; logs show DB connection success (no repeated Postgres auth errors).

If the Deployment name is not `n8n`, locate it:

```bash
kubectl -n n8n get deploy
kubectl -n n8n logs deploy/<actual-name> --tail=80
```

- [ ] **Step 6: Cluster-local HTTP smoke test**

```bash
kubectl -n n8n run curl-smoke --rm -it --restart=Never \
  --image=curlimages/curl:8.5.0 \
  -- curl -sI http://n8n.n8n.svc.cluster.local:5678/
```

Expected: HTTP response headers from n8n (status may be 200 or redirect).

---

### Task 6: Deploy `cloudflared` and verify Tunnel + Access

**Files:**
- Apply cluster manifests from stdin (not committed with real token)
- Test: browser to `https://n8n.YOUR_DOMAIN_HERE`

**Interfaces:**
- Consumes: Secret `cloudflare-tunnel-token`; Service `n8n.n8n.svc.cluster.local:5678`
- Produces: Running `cloudflared` Deployment; Tunnel healthy in Cloudflare UI

- [ ] **Step 1: Apply cloudflared Deployment + optional PDB-free ServiceAccount**

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
                  name: cloudflare-tunnel-token
                  key: token
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 256Mi
          livenessProbe:
            exec:
              command:
                - cloudflared
                - --version
            initialDelaySeconds: 10
            periodSeconds: 30
EOF
```

Pinning `cloudflare/cloudflared` to a digest/tag instead of `latest` is preferred once a version is known; after first success, note the image tag in `docs/apps/n8n.md`.

- [ ] **Step 2: Wait for pods and check logs**

```bash
kubectl -n n8n rollout status deploy/cloudflared --timeout=120s
kubectl -n n8n logs deploy/cloudflared --tail=50
```

Expected: messages indicating connection registered / tunnel running (not repeated auth failures).

- [ ] **Step 3: Confirm Tunnel status in Cloudflare UI**

Zero Trust → Tunnels → `homelab-n8n` should show **Healthy**.

- [ ] **Step 4: Browser verification (Access gate)**

1. Open `https://n8n.YOUR_DOMAIN_HERE` in a private window.
2. Expect Cloudflare Access login (email OTP or IdP).
3. After success, expect n8n setup/login UI.
4. Create the initial n8n owner account (local to n8n; separate from Access).

- [ ] **Step 5: Negative check (optional)**

From a network path that is not the Tunnel (e.g. LAN NodePort probe): confirm you did **not** publish n8n via NodePort/LoadBalancer:

```bash
kubectl -n n8n get svc n8n -o wide
```

Expected: `ClusterIP` only.

---

### Task 7: Persistence and backup smoke tests

**Files:**
- None in git until Task 8 documents the procedure
- Test: workflow survives pod restart; dump command works

**Interfaces:**
- Consumes: running n8n + Postgres
- Produces: verified restore prerequisites (encryption key + DB dump path)

- [ ] **Step 1: Create a trivial workflow in the UI**

Save a workflow named `persistence-check` (e.g. Manual Trigger → NoOp / Set).

- [ ] **Step 2: Restart n8n pod and confirm workflow remains**

```bash
kubectl -n n8n delete pod -l app.kubernetes.io/name=n8n --wait=false
# If label differs:
kubectl -n n8n get pods
kubectl -n n8n delete pod <n8n-pod-name>
kubectl -n n8n rollout status deploy/n8n --timeout=180s
```

Reload UI: `persistence-check` still present.

- [ ] **Step 3: Take a Postgres logical dump to the operator machine**

```bash
kubectl -n n8n exec deploy/n8n-postgresql -- \
  bash -c 'PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -U n8n -d n8n' \
  > ~/secrets/n8n-pg-dump-$(date +%Y%m%d).sql
# If env var name differs on the Postgres image, use:
#   kubectl -n n8n get deploy,sts
# and exec into the postgres pod with PGPASSWORD from ~/secrets/n8n-db-password.txt
ls -la ~/secrets/n8n-pg-dump-*.sql
```

Expected: non-empty `.sql` file. Keep `~/secrets/n8n-encryption-key.txt` with dumps — without the encryption key, credential fields in workflows cannot be decrypted.

- [ ] **Step 4: Record success criteria checklist**

Confirm all true:

1. Access challenge appears before n8n UI.
2. Workflow survives pod restart.
3. PVCs still Bound after restart.
4. Dump file created offline.

---

### Task 8: Update handbook documentation

**Files:**
- Modify: `docs/apps/n8n.md` (full rewrite from Planned)
- Modify: `docs/architecture/networking.md` (Cloudflare alternate note)
- Create: `docs/experiences/2026-07-31-n8n-k3s-cloudflare.md` (if install completed)
- Test: `scripts/verify-docs.sh` if it checks linked paths; otherwise link-check manually

**Interfaces:**
- Consumes: chart versions actually used (`N8N_CHART_VERSION`, Postgres chart name/version), StorageClass, lessons from Bitnami vs fallback
- Produces: handbook pages matching the lived design (placeholders only)

- [ ] **Step 1: Rewrite `docs/apps/n8n.md`**

Replace contents with a page that includes:

- Status: Implemented (single-node) or Active
- Purpose (personal + teaching)
- Placement: single-node K3s namespace `n8n`; later compute-node affinity when multi-node arrives
- Architecture diagram (Tunnel → cloudflared → Service → n8n → Postgres)
- Exposure: Cloudflare Tunnel + Access (not raw public editor; not WireGuard-required for this app)
- Components table: 8gears Helm chart OCI URL, Postgres chart actually used, cloudflared Deployment, PVCs
- Example Helm values and cloudflared YAML using `n8n.example.net` and secret **names** only
- Webhooks: v1 behind Access; public webhook hostname is a follow-up
- Backups: `pg_dump` + retain `N8N_ENCRYPTION_KEY` + PVC notes
- Verify checklist matching Task 7
- See also: design spec, networking, Phase 4

Do not paste real tokens, passwords, or personal emails.

- [ ] **Step 2: Patch `docs/architecture/networking.md`**

After the WireGuard / Private access section (or under Exposure policy), add a short subsection:

```markdown
## Cloudflare Tunnel and Access (alternate gate)

For selected applications (starting with [n8n](../apps/n8n.md)), Cloudflare Tunnel can publish HTTPS without opening inbound ports on the homelab, with Cloudflare Access enforcing allowlisted users on the editor UI. This complements host-level WireGuard: WireGuard remains the break-glass admin path when the cluster or Cloudflare path is unavailable; Tunnel+Access is acceptable for app UIs that should not use Traefik/cert-manager public Ingress on day one.
```

Adjust wording to match surrounding voice; keep relative links.

- [ ] **Step 3: Add experience entry (when install succeeded)**

Create `docs/experiences/2026-07-31-n8n-k3s-cloudflare.md`:

```markdown
# n8n on single-node K3s with Cloudflare Tunnel

Date: 2026-07-31
Status: Accepted

## Context

Needed personal/teaching n8n on one PC with existing K3s, preferring Cloudflare Tunnel + Access over VPN-only exposure for the editor.

## Decision

Deploy Approach 1 from the design spec: Helm n8n + in-cluster Postgres + cloudflared to ClusterIP, Access on the hostname.

## Notes

- Chart versions used: (fill from install)
- Postgres path: Bitnami / groundhog2k fallback (fill which worked)
- Issues hit: (ImagePullBackOff, values key renames, etc.)

## See also

- [Design](../superpowers/specs/2026-07-31-n8n-k3s-cloudflare-design.md)
- [n8n app page](../apps/n8n.md)
```

- [ ] **Step 4: Link experience from `docs/experiences/README.md` if that index lists entries**

Read the README and add a bullet if the pattern requires it.

- [ ] **Step 5: Verify docs**

```bash
./scripts/verify-docs.sh
```

Expected: exit 0. Fix any broken relative links introduced.

- [ ] **Step 6: Commit handbook updates**

```bash
git add docs/apps/n8n.md docs/architecture/networking.md docs/experiences/2026-07-31-n8n-k3s-cloudflare.md docs/experiences/README.md
git commit -m "$(cat <<'EOF'
Document n8n single-node deploy with Cloudflare Tunnel and Access.

EOF
)"
```

Only stage files that exist and were intentionally changed.

---

### Task 9: Operator handoff checklist

**Files:**
- None required

**Interfaces:**
- Consumes: completed Tasks 1–8
- Produces: operator-ready summary

- [ ] **Step 1: Fill this checklist offline (do not commit secrets)**

```text
[ ] kubeconfig works for the single-node cluster
[ ] Namespace n8n healthy (n8n, postgres, cloudflared)
[ ] ~/secrets holds encryption key, db password, tunnel token, latest pg_dump
[ ] Cloudflare Access allowlist includes teaching emails when needed
[ ] Handbook docs/apps/n8n.md matches what was installed
[ ] Follow-ups known: public webhooks, Traefik-shared tunnel, CloudNativePG, multi-node
```

- [ ] **Step 2: No further commit unless docs still drift**

---

## Self-review (plan vs spec)

| Spec requirement | Task |
|------------------|------|
| Single-node existing K3s | Task 1 |
| Namespace `n8n` | Task 3 |
| PostgreSQL in-cluster + PVC | Task 4 |
| n8n Helm + PVC + encryption key | Task 5 |
| cloudflared → ClusterIP | Task 6 |
| Cloudflare Access on hostname | Tasks 2, 6 |
| Secrets not in git | Tasks 3–6, 8 |
| No public webhooks v1 | Tasks 2, 5, 8 |
| Persistence verification | Task 7 |
| Backup notes (`pg_dump` + key) | Tasks 7–8 |
| Update `docs/apps/n8n.md` + networking | Task 8 |
| Bitnami registry risk | Task 4 fallback |
| Success criteria (Access, persist, PVCs, docs) | Tasks 6–8 |

No TBD/TODO placeholders remain; chart version pins are discovered at install time and written into the handbook in Task 8.
