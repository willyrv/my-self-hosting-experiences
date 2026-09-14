# Matomo on single-node K3s + Cloudflare Tunnel Implementation Plan

> **Manual install (human on host A):** copy-paste runbook is [`docs/guides/matomo-k3s-cloudflare.md`](../../guides/matomo-k3s-cloudflare.md). Use that file in a terminal; this plan is the agent-oriented task breakdown.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy Matomo On-Premise on teaching GPU host A’s existing single-node K3s cluster with MariaDB, a report-archive CronJob, Cloudflare Tunnel, and a split Access gate (public tracking, Access-protected dashboard), then update the handbook to match.

**Architecture:** Namespace `matomo` holds MariaDB, the official Matomo Apache image, a CronJob for `core:archive`, and `cloudflared` dialing the Matomo ClusterIP Service. Cloudflare terminates HTTPS on `webanalytics.willyrv.com`. Access Bypass covers tracking paths; Access Allow plus Matomo login covers the dashboard. No Traefik Ingress for Matomo in v1.

**Tech Stack:** K3s, official `matomo` (Apache) image, official `mariadb` image, Kubernetes CronJob, `cloudflare/cloudflared`, Cloudflare Zero Trust Tunnel + Access.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-14-matomo-k3s-cloudflare-design.md`
- Target cluster: teaching GPU host A (the JupyterHub / n8n single-node k3s). Do not install on the OpenProject mini PC or the OVH VPS.
- Do not reinstall K3s.
- Namespace: `matomo`.
- Public hostname: `webanalytics.willyrv.com`.
- Matomo requires MariaDB/MySQL, not PostgreSQL.
- Official images only (no Bitnami Matomo/MariaDB charts).
- Secrets (tunnel token, DB passwords) stay in Kubernetes Secrets and `~/secrets/` — never commit real values or emails.
- Do **not** enable Tunnel **Protect with Access** on this hostname (it would JWT-lock tracking beacons).
- Tracking paths stay public: `/matomo.php`, `/matomo.js`, `/piwik.php`, `/piwik.js`.
- Dashboard: Cloudflare Access (allowlisted email) **and** Matomo login.
- No Traefik / cert-manager / Flux / SOPS / paid plugins / GA import / Tag Manager project in v1.
- This docs repo remains documentation-first: runbook YAML uses secret **names**, not values. Do not add a live GitOps `clusters/` tree.
- Pin image tags discovered at install time into the handbook.
- `./scripts/verify-docs.sh` must pass after handbook edits. Do not add private IPs, private hostnames, operator home directories, or operator emails to tracked markdown.

## File Structure

| Path | Responsibility |
|------|----------------|
| `docs/apps/matomo.md` | Canonical runbook: placement, manifests, Access Bypass, wizard, backups, verify |
| `docs/architecture/networking.md` | Tunnel + Access note: path Bypass for tracking (unlike n8n) |
| `docs/experiences/deployment-topology.md` | Host A + `webanalytics.willyrv.com` on the public diagram |
| `docs/experiences/2026-09-14-matomo-k3s-cloudflare.md` | Dated lived log after install |
| `docs/experiences/README.md` | Link the new experience |
| `docs/guides/phase-05-stateful-apps.md` | Short Matomo mention + link |
| `README.md` | Apps list link |
| `scripts/verify-docs.sh` | Require `docs/apps/matomo.md` |
| Cluster (not in git) | Namespace, Secrets, MariaDB, Matomo, CronJob, `cloudflared` |

Working directory for handbook edits:

```bash
cd <repo-root>
```

Cluster commands assume `kubectl` talks to teaching GPU host A’s K3s API.

Locked names for later tasks:

| Object | Name |
|--------|------|
| Namespace | `matomo` |
| MariaDB StatefulSet / Service | `matomo-mariadb` (port 3306) |
| Matomo Deployment / Service | `matomo` (port 80) |
| Matomo files PVC | `matomo-html` |
| MariaDB PVC | `data-matomo-mariadb-0` (volumeClaimTemplate) |
| Secrets | `matomo-db-auth`, `cloudflare-tunnel-token` |
| CronJob | `matomo-archive` |
| Tunnel HTTP URL | `matomo.matomo.svc.cluster.local:80` |
| Local secret files | `~/secrets/matomo-db-password.txt`, `~/secrets/matomo-db-root-password.txt`, `~/secrets/matomo-tunnel-token.txt` |

Default image refs (replace with a more specific tag if you pin one at install):

```bash
export MATOMO_IMAGE=docker.io/library/matomo:5-apache
export MARIADB_IMAGE=docker.io/library/mariadb:11
export CLOUDFLARED_IMAGE=docker.io/cloudflare/cloudflared:2025.8.1
```

---

### Task 1: Verify cluster prerequisites (host A)

**Files:**
- Modify: none (read-only cluster checks)
- Test: shell commands below

**Interfaces:**
- Consumes: existing K3s kubeconfig
- Produces: confirmed this is the Jupyter/n8n cluster; `STORAGE_CLASS` exported; outbound HTTPS to Cloudflare

- [ ] **Step 1: Confirm this is teaching GPU host A, not the OpenProject box**

```bash
kubectl get nodes -o wide
kubectl get ns
```

Expected: one node `Ready`; namespaces for n8n and/or JupyterHub exist. If you only see OpenProject-related namespaces and a small node, stop — wrong cluster.

- [ ] **Step 2: API health, Helm (optional), default StorageClass**

```bash
kubectl get --raw='/readyz?verbose' | head
helm version || true
kubectl get storageclass
export STORAGE_CLASS=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
echo "STORAGE_CLASS=${STORAGE_CLASS}"
```

Expected: readyz healthy; default StorageClass set (often `local-path`). If `STORAGE_CLASS` is empty: `export STORAGE_CLASS=local-path`. Helm is not required for this install.

- [ ] **Step 3: Confirm outbound HTTPS (Tunnel requirement)**

```bash
curl -sI https://api.cloudflare.com | head -n 1
```

Expected: an HTTP response header line (not a connection failure).

- [ ] **Step 4: Commit nothing**

No repo changes in this task.

---

### Task 2: Cloudflare Tunnel, DNS, and split Access

**Files:**
- Modify: none in git (Cloudflare Zero Trust UI)
- Test: DNS for `webanalytics.willyrv.com`; Access apps exist; Protect with Access is off

**Interfaces:**
- Consumes: Cloudflare account that already hosts `willyrv.com`
- Produces: Tunnel token in `~/secrets/matomo-tunnel-token.txt`; public hostname routed to `http://matomo.matomo.svc.cluster.local:80`; Bypass apps for tracking paths; Allow app for the dashboard

- [ ] **Step 1: Create a dedicated Tunnel**

Zero Trust → Networks → Tunnels → Create:

1. Choose **Cloudflared**.
2. Name it `homelab-matomo`.
3. Copy the tunnel token (`eyJ...`) into a file **not** in git:

```bash
umask 077
mkdir -p ~/secrets
nano ~/secrets/matomo-tunnel-token.txt   # paste token, one line
chmod 600 ~/secrets/matomo-tunnel-token.txt
```

- [ ] **Step 2: Add the public hostname (Protect with Access OFF)**

Tunnel → Public Hostname → Add:

| Field | Value |
|-------|--------|
| Subdomain | `webanalytics` |
| Domain | `willyrv.com` |
| Type | HTTP |
| URL | `matomo.matomo.svc.cluster.local:80` |

Save. DNS CNAME for `webanalytics.willyrv.com` should be **proxied**.

Open the hostname’s additional settings if present and confirm **Protect with Access is disabled**. Enabling it would block anonymous `matomo.php` hits.

The Kubernetes Service does not exist yet; the connector will become useful after Task 6.

- [ ] **Step 3: Bypass Access for tracking paths (four small apps)**

Path-specific Access applications take precedence over a hostname-wide app. Create four **self-hosted** applications. For each: policy **Bypass**, include **Everyone**, session duration irrelevant.

| Application name | Public hostname | Path |
|------------------|-----------------|------|
| `matomo-tracker-js` | `webanalytics.willyrv.com` | `/matomo.js` |
| `matomo-tracker-php` | `webanalytics.willyrv.com` | `/matomo.php` |
| `matomo-tracker-piwik-js` | `webanalytics.willyrv.com` | `/piwik.js` |
| `matomo-tracker-piwik-php` | `webanalytics.willyrv.com` | `/piwik.php` |

If the UI asks for an identity provider on Bypass apps, you can leave OTP enabled; Bypass must still apply to unauthenticated visitors (action **Bypass**, not Allow).

- [ ] **Step 4: Protect the dashboard**

Create a fifth self-hosted application:

| Field | Value |
|-------|--------|
| Application name | `matomo-dashboard` |
| Public hostname | `webanalytics.willyrv.com` |
| Path | *(empty — whole host, after the four path apps)* |
| Session duration | 24 hours |
| Policy | **Allow** → Include → Emails → your address |
| Identity | One-time PIN (or existing IdP) |

Do not add a Bypass-Everyone policy on this fifth app.

- [ ] **Step 5: Sanity-check DNS**

```bash
dig +short webanalytics.willyrv.com
```

Expected: Cloudflare anycast IPs (proxied), not a home public IP as the only story.

- [ ] **Step 6: Commit nothing**

---

### Task 3: Namespace and Kubernetes Secrets

**Files:**
- Cluster only (Secrets not committed)
- Test: `kubectl -n matomo get secrets`

**Interfaces:**
- Consumes: tunnel token file; generated DB passwords
- Produces: namespace `matomo`; secrets `matomo-db-auth`, `cloudflare-tunnel-token`

- [ ] **Step 1: Create namespace**

```bash
kubectl create namespace matomo
```

Expected: `namespace/matomo created` (or already exists).

- [ ] **Step 2: Generate local secret material (do not commit)**

```bash
umask 077
mkdir -p ~/secrets
openssl rand -hex 24 | tee ~/secrets/matomo-db-password.txt >/dev/null
openssl rand -hex 24 | tee ~/secrets/matomo-db-root-password.txt >/dev/null
# Tunnel token already at ~/secrets/matomo-tunnel-token.txt from Task 2
chmod 600 ~/secrets/matomo-db-password.txt ~/secrets/matomo-db-root-password.txt
```

- [ ] **Step 3: Create DB auth Secret**

```bash
kubectl -n matomo create secret generic matomo-db-auth \
  --from-literal=mariadb-root-password="$(cat ~/secrets/matomo-db-root-password.txt)" \
  --from-literal=password="$(cat ~/secrets/matomo-db-password.txt)" \
  --from-literal=username=matomo \
  --from-literal=database=matomo
```

- [ ] **Step 4: Create Tunnel token Secret**

```bash
kubectl -n matomo create secret generic cloudflare-tunnel-token \
  --from-literal=token="$(cat ~/secrets/matomo-tunnel-token.txt)"
```

- [ ] **Step 5: Verify secret names only**

```bash
kubectl -n matomo get secrets
```

Expected: `matomo-db-auth` and `cloudflare-tunnel-token`. Do not dump `-o yaml` into chat logs or git.

---

### Task 4: Install MariaDB

**Files:**
- Cluster: StatefulSet `matomo-mariadb`, Service `matomo-mariadb`
- Test: SQL `SELECT 1` from a throwaway pod

**Interfaces:**
- Consumes: `matomo` namespace, `matomo-db-auth`, `STORAGE_CLASS`, `MARIADB_IMAGE`
- Produces: ClusterIP Service `matomo-mariadb.matomo.svc.cluster.local:3306` with database `matomo` and user `matomo`

- [ ] **Step 1: Apply MariaDB Service + StatefulSet**

```bash
export MARIADB_IMAGE="${MARIADB_IMAGE:-docker.io/library/mariadb:11}"
export STORAGE_CLASS="${STORAGE_CLASS:-local-path}"

kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: matomo-mariadb
  namespace: matomo
spec:
  type: ClusterIP
  selector:
    app: matomo-mariadb
  ports:
    - name: mysql
      port: 3306
      targetPort: 3306
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: matomo-mariadb
  namespace: matomo
spec:
  serviceName: matomo-mariadb
  replicas: 1
  selector:
    matchLabels:
      app: matomo-mariadb
  template:
    metadata:
      labels:
        app: matomo-mariadb
    spec:
      securityContext:
        fsGroup: 999
      containers:
        - name: mariadb
          image: ${MARIADB_IMAGE}
          imagePullPolicy: IfNotPresent
          args:
            - --max-allowed-packet=64M
            - --character-set-server=utf8mb4
            - --collation-server=utf8mb4_unicode_ci
          ports:
            - containerPort: 3306
              name: mysql
          env:
            - name: MARIADB_DATABASE
              valueFrom:
                secretKeyRef:
                  name: matomo-db-auth
                  key: database
            - name: MARIADB_USER
              valueFrom:
                secretKeyRef:
                  name: matomo-db-auth
                  key: username
            - name: MARIADB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: matomo-db-auth
                  key: password
            - name: MARIADB_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: matomo-db-auth
                  key: mariadb-root-password
          resources:
            requests:
              cpu: "250m"
              memory: 512Mi
            limits:
              cpu: "1"
              memory: 2Gi
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
          readinessProbe:
            exec:
              command: ["healthcheck.sh", "--connect", "--innodb_initialized"]
            initialDelaySeconds: 20
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 12
          livenessProbe:
            exec:
              command: ["healthcheck.sh", "--connect", "--innodb_initialized"]
            initialDelaySeconds: 60
            periodSeconds: 30
            timeoutSeconds: 5
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: ${STORAGE_CLASS}
        resources:
          requests:
            storage: 20Gi
EOF
```

- [ ] **Step 2: Wait until Ready**

```bash
kubectl -n matomo rollout status statefulset/matomo-mariadb --timeout=5m
kubectl -n matomo get pods,svc,pvc
```

Expected: pod `matomo-mariadb-0` Ready; PVC Bound; Service `matomo-mariadb` ClusterIP.

If the readiness probe fails because this MariaDB tag lacks `healthcheck.sh`, replace both probes with:

```yaml
tcpSocket:
  port: 3306
```

and re-apply.

- [ ] **Step 3: Smoke-test SQL**

```bash
kubectl -n matomo run mysql-smoke --rm -it --restart=Never \
  --image="${MARIADB_IMAGE}" \
  --env="MYSQL_PWD=$(cat ~/secrets/matomo-db-password.txt)" \
  --command -- mariadb -h matomo-mariadb -u matomo matomo -e 'SELECT 1 AS ok;'
```

Expected: a row `ok` / `1`, then the pod is deleted. If `-it` swallows output, drop `-it` and read the pod logs.

- [ ] **Step 4: Confirm the DB is not published**

```bash
kubectl -n matomo get svc matomo-mariadb -o jsonpath='{.spec.type}{"\n"}'
```

Expected: `ClusterIP` (not NodePort / LoadBalancer).

---

### Task 5: Install Matomo (official image)

**Files:**
- Cluster: PVC `matomo-html`, Deployment `matomo`, Service `matomo`
- Test: pod Ready; Service ClusterIP `:80`

**Interfaces:**
- Consumes: MariaDB Service, `matomo-db-auth`, `STORAGE_CLASS`, `MATOMO_IMAGE`
- Produces: Service `matomo.matomo.svc.cluster.local:80`

- [ ] **Step 1: Apply PVC, Deployment, Service**

```bash
export MATOMO_IMAGE="${MATOMO_IMAGE:-docker.io/library/matomo:5-apache}"
export STORAGE_CLASS="${STORAGE_CLASS:-local-path}"

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: matomo-html
  namespace: matomo
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: ${STORAGE_CLASS}
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: Service
metadata:
  name: matomo
  namespace: matomo
spec:
  type: ClusterIP
  selector:
    app: matomo
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: matomo
  namespace: matomo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: matomo
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: matomo
    spec:
      securityContext:
        fsGroup: 33
      containers:
        - name: matomo
          image: ${MATOMO_IMAGE}
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
              name: http
          env:
            - name: MATOMO_DATABASE_HOST
              value: matomo-mariadb
            - name: MATOMO_DATABASE_ADAPTER
              value: mysql
            - name: MATOMO_DATABASE_TABLES_PREFIX
              value: matomo_
            - name: MATOMO_DATABASE_DBNAME
              valueFrom:
                secretKeyRef:
                  name: matomo-db-auth
                  key: database
            - name: MATOMO_DATABASE_USERNAME
              valueFrom:
                secretKeyRef:
                  name: matomo-db-auth
                  key: username
            - name: MATOMO_DATABASE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: matomo-db-auth
                  key: password
            - name: PHP_MEMORY_LIMIT
              value: "512M"
          resources:
            requests:
              cpu: "250m"
              memory: 512Mi
            limits:
              cpu: "1"
              memory: 2Gi
          volumeMounts:
            - name: html
              mountPath: /var/www/html
          readinessProbe:
            tcpSocket:
              port: 80
            initialDelaySeconds: 15
            periodSeconds: 10
          livenessProbe:
            tcpSocket:
              port: 80
            initialDelaySeconds: 60
            periodSeconds: 30
      volumes:
        - name: html
          persistentVolumeClaim:
            claimName: matomo-html
EOF
```

- [ ] **Step 2: Wait and inspect logs**

```bash
kubectl -n matomo rollout status deploy/matomo --timeout=5m
kubectl -n matomo get pods,svc,pvc
kubectl -n matomo logs deploy/matomo --tail=40
```

Expected: Deployment Ready; PVC Bound; Apache/PHP started (no persistent DB connection errors). First boot copies Matomo files onto the PVC.

- [ ] **Step 3: Confirm Service type**

```bash
kubectl -n matomo get svc matomo -o jsonpath='{.spec.type}{" "}{.spec.ports[0].port}{"\n"}'
```

Expected: `ClusterIP 80`.

---

### Task 6: Deploy cloudflared and confirm the Tunnel

**Files:**
- Cluster: Deployment `cloudflared`
- Test: Tunnel Healthy in Zero Trust; HTTPS reaches Matomo through Cloudflare

**Interfaces:**
- Consumes: secret `cloudflare-tunnel-token`; Service `matomo:80`
- Produces: working Tunnel to the Matomo Service

- [ ] **Step 1: Apply cloudflared**

```bash
export CLOUDFLARED_IMAGE="${CLOUDFLARED_IMAGE:-docker.io/cloudflare/cloudflared:2025.8.1}"

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: matomo
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
```

If the shell ate the backslash and the args contain a literal `$(TUNNEL_TOKEN)` that Kubernetes did **not** expand from the env, re-apply with a YAML file:

```bash
cat > /tmp/matomo-cloudflared.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: matomo
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
          image: docker.io/cloudflare/cloudflared:2025.8.1
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
# Fix image if you pinned a different tag:
sed -i "s|image: docker.io/cloudflare/cloudflared:2025.8.1|image: ${CLOUDFLARED_IMAGE}|" /tmp/matomo-cloudflared.yaml
kubectl apply -f /tmp/matomo-cloudflared.yaml
rm -f /tmp/matomo-cloudflared.yaml
```

Kubernetes substitutes `$(TUNNEL_TOKEN)` from the container env. The token must **not** be written in the YAML.

- [ ] **Step 2: Wait for logs**

```bash
kubectl -n matomo rollout status deploy/cloudflared --timeout=120s
kubectl -n matomo logs deploy/cloudflared --tail=40
```

Expected: connection registered / tunnel running, not repeated auth failures.

- [ ] **Step 3: Confirm Tunnel Healthy**

Zero Trust → Tunnels → `homelab-matomo` → **Healthy**.

- [ ] **Step 4: Browser — dashboard is gated**

1. Private window: open `https://webanalytics.willyrv.com/`.
2. Expect Cloudflare Access (email OTP or IdP), **not** the Matomo UI yet.
3. After Access, expect the Matomo installer or login.

- [ ] **Step 5: curl — tracking paths are not gated**

```bash
curl -sI https://webanalytics.willyrv.com/matomo.js | head -n 15
curl -sI https://webanalytics.willyrv.com/
```

Expected:

- `/matomo.js`: HTTP `200` (or `304`), **not** a redirect to `cloudflareaccess.com` / Access login.
- `/`: Access challenge or redirect to Access, **not** the raw dashboard.

If `/matomo.js` is redirected to Access, the Bypass apps are wrong or **Protect with Access** is on. Fix Access before continuing; tracking cannot work.

---

### Task 7: Wizard, privacy defaults, and archive CronJob

**Files:**
- Cluster: CronJob `matomo-archive` (enable only after `config.ini.php` exists)
- Matomo UI / `config.ini.php` on the PVC (not in git)
- Test: dashboard login; archive Job succeeds

**Interfaces:**
- Consumes: working HTTPS + Access; MariaDB user `matomo`
- Produces: installed Matomo; privacy settings; periodic `core:archive`

- [ ] **Step 1: Complete the setup wizard through Access**

Open `https://webanalytics.willyrv.com/` after Access. Database step:

| Field | Value |
|-------|--------|
| Database server | `matomo-mariadb` |
| Login | `matomo` |
| Password | contents of `~/secrets/matomo-db-password.txt` |
| Database name | `matomo` |

Create a strong Matomo superuser (separate from the Access email). Superuser password stays offline, not in git.

Finish the wizard. Confirm `config.ini.php` exists:

```bash
kubectl -n matomo exec deploy/matomo -- test -f /var/www/html/config/config.ini.php && echo "config ok"
```

Expected: `config ok`.

- [ ] **Step 2: Trusted host, HTTPS, visitor IP**

In Matomo (or by editing config via exec), set:

- Trusted host: `webanalytics.willyrv.com`
- Assume HTTPS / secure protocol
- Proxy / client IP header: `HTTP_CF_CONNECTING_IP` (Cloudflare)

Example `config.ini.php` fragments (merge into existing `[General]`; do not overwrite the whole file blindly):

```ini
[General]
assume_secure_protocol = 1
proxy_client_headers[] = "HTTP_CF_CONNECTING_IP"
trusted_hosts[] = "webanalytics.willyrv.com"
```

Copy the live file out, edit locally, copy back:

```bash
kubectl -n matomo exec deploy/matomo -- cat /var/www/html/config/config.ini.php > ~/secrets/matomo-config.ini.php
chmod 600 ~/secrets/matomo-config.ini.php
# edit ~/secrets/matomo-config.ini.php, then:
kubectl -n matomo exec -i deploy/matomo -- tee /var/www/html/config/config.ini.php < ~/secrets/matomo-config.ini.php >/dev/null
```

- [ ] **Step 3: Privacy defaults in the UI**

Administration → Privacy / System (labels vary by Matomo 5):

- Anonymize visitor IPs (at least 2 bytes).
- Do **not** use tracking cookies (cookieless / disable cookies).
- Respect Do Not Track.
- Delete old raw/visit data after **13 months**.
- Disable **Archive reports when viewed from the browser**.

Do not install Marketplace paid plugins.

- [ ] **Step 4: Apply the archive CronJob**

```bash
export MATOMO_IMAGE="${MATOMO_IMAGE:-docker.io/library/matomo:5-apache}"

kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: matomo-archive
  namespace: matomo
spec:
  schedule: "*/15 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      backoffLimit: 1
      template:
        spec:
          restartPolicy: Never
          securityContext:
            fsGroup: 33
          containers:
            - name: archive
              image: ${MATOMO_IMAGE}
              imagePullPolicy: IfNotPresent
              command:
                - php
                - /var/www/html/console
                - core:archive
                - --url=https://webanalytics.willyrv.com/
              env:
                - name: PHP_MEMORY_LIMIT
                  value: "512M"
              resources:
                requests:
                  cpu: "100m"
                  memory: 256Mi
                limits:
                  cpu: "1"
                  memory: 1Gi
              volumeMounts:
                - name: html
                  mountPath: /var/www/html
          volumes:
            - name: html
              persistentVolumeClaim:
                claimName: matomo-html
EOF
```

Trigger one Job immediately:

```bash
kubectl -n matomo create job matomo-archive-now --from=cronjob/matomo-archive
kubectl -n matomo wait --for=condition=complete job/matomo-archive-now --timeout=5m
kubectl -n matomo logs job/matomo-archive-now --tail=50
```

Expected: archive completed without fatal errors.

If the Job pod stays **Pending** with a Multi-Attach / volume in-use error (RWO PVC), delete the CronJob and add an `archive` sidecar on the Matomo Deployment (same image, `while true; do php ... core:archive --url=https://webanalytics.willyrv.com/; sleep 900; done`, same `html` volumeMount). Record which path you used in the experience log.

- [ ] **Step 5: Add the first site**

In Matomo: add a site you own. Copy the JavaScript tracking snippet. Keep it for Task 8; do not commit the snippet if it embeds a secret token you do not want public (`token_auth` must never go in git). The standard JS tracker uses the site id and `https://webanalytics.willyrv.com/` only.

---

### Task 8: Tracking, persistence, and backup tests

**Files:**
- Local dump under `~/secrets/` (not git)
- Test: curl Bypass still holds; visit appears; pod restart keeps data

**Interfaces:**
- Consumes: site id + snippet from Task 7; PVCs
- Produces: verified tracking; `~/secrets/matomo-mysqldump-YYYYMMDD.sql` and `~/secrets/matomo-config.ini.php`

- [ ] **Step 1: Re-check Bypass vs Access**

```bash
curl -sI https://webanalytics.willyrv.com/matomo.js | head -n 15
curl -sI https://webanalytics.willyrv.com/matomo.php | head -n 15
curl -sI https://webanalytics.willyrv.com/ | head -n 15
```

Expected: JS/PHP tracker not redirected to Access; `/` still Access-gated.

- [ ] **Step 2: Record a real visit**

Paste the JS snippet on a page you control (a blog, docs, or a throwaway HTML file on `willyrv.com`). Load that page in a browser **without** an Access session on `webanalytics.willyrv.com` (different browser or private window that never logged into Access).

Wait for the next archive (or run `kubectl -n matomo create job ... --from=cronjob/matomo-archive` again). In Matomo, the site should show at least one visit.

If visits are missing: browser devtools → the page should request `matomo.js` and `matomo.php` with HTTP 200. A 302 to Access means Bypass is broken.

- [ ] **Step 3: Restart Matomo; data remains**

```bash
kubectl -n matomo delete pod -l app=matomo
kubectl -n matomo rollout status deploy/matomo --timeout=180s
```

Reload the dashboard (Access + Matomo login): the site and the visit remain.

- [ ] **Step 4: Logical dump + config copy**

```bash
kubectl -n matomo exec statefulset/matomo-mariadb -- \
  mariadb-dump -umatomo -p"$(cat ~/secrets/matomo-db-password.txt)" matomo \
  > ~/secrets/matomo-mysqldump-$(date +%Y%m%d).sql

kubectl -n matomo exec deploy/matomo -- cat /var/www/html/config/config.ini.php \
  > ~/secrets/matomo-config.ini.php

chmod 600 ~/secrets/matomo-mysqldump-*.sql ~/secrets/matomo-config.ini.php
ls -la ~/secrets/matomo-mysqldump-*.sql ~/secrets/matomo-config.ini.php
```

If `mariadb-dump` is not in the image, use `mysqldump` with the same arguments. Expected: non-empty `.sql` and config file. Keep DB passwords with the dump; `config.ini.php` contains the salt and tokens needed to restore.

- [ ] **Step 5: Record success criteria**

All true before handbook work:

1. Dashboard only after Access **and** Matomo login.
2. `/matomo.js` and `/matomo.php` work without Access.
3. At least one owned page recorded a visit after archive.
4. Dump + `config.ini.php` exist under `~/secrets/`.
5. PVCs still Bound after pod delete.

---

### Task 9: Update handbook documentation

**Files:**
- Create: `docs/apps/matomo.md`
- Create: `docs/experiences/2026-09-14-matomo-k3s-cloudflare.md`
- Modify: `docs/architecture/networking.md`
- Modify: `docs/experiences/deployment-topology.md`
- Modify: `docs/experiences/README.md`
- Modify: `docs/guides/phase-05-stateful-apps.md`
- Modify: `README.md`
- Modify: `scripts/verify-docs.sh`
- Test: `./scripts/verify-docs.sh`

**Interfaces:**
- Consumes: image tags actually used, whether CronJob or sidecar won, lessons from Access Bypass
- Produces: handbook matching the lived path (no secrets, no private IPs)

- [ ] **Step 1: Create `docs/apps/matomo.md`**

Write the page with this structure and content (adjust image tags, CronJob vs sidecar, and any probe tweak to match what actually ran). Status **Implemented** only if Tasks 1–8 succeeded; otherwise **Planned** and say what is unfinished.

```markdown
# Matomo

Status: Implemented (single-node K3s)

## Purpose

[Matomo](https://matomo.org/) On-Premise is an open-source web analytics platform (GPL-3.0) used here as a Google Analytics alternative for public and personal websites. Visitor data stays on the cluster. Core reports are free; heatmaps and session recordings are paid plugins and are not installed.

## Placement

Validated on **teaching GPU host A** (single-node K3s, same cluster as JupyterHub and n8n):

- Namespace `matomo`
- Official `matomo` (Apache) + official MariaDB
- CronJob `matomo-archive` for `console core:archive` (sidecar fallback if the RWO PVC cannot attach to a second pod)
- Cloudflare Tunnel (`cloudflared`) to the Matomo ClusterIP Service
- Hostname `https://webanalytics.willyrv.com`

Do **not** publish Matomo or MariaDB via NodePort / host ports. Public HTTPS terminates at Cloudflare.

## Architecture

\`\`\`text
Public sites (JS snippet)
        │
        ▼
https://webanalytics.willyrv.com/matomo.js
https://webanalytics.willyrv.com/matomo.php
        │
        ▼
Cloudflare Edge — Access Bypass on tracking paths
        │
        ▼
Cloudflare Tunnel (outbound)
        │
        ▼
cloudflared  ──►  Matomo Service :80
                      │
        ┌─────────────┴─────────────┐
        ▼                           ▼
   MariaDB PVC                 Matomo files PVC
        ▲
        └── CronJob: console core:archive

Dashboard visitors (allowlisted email)
        │
        ▼
Same hostname, other paths → Cloudflare Access → Matomo login
\`\`\`

| Piece | Choice |
|-------|--------|
| Namespace | \`matomo\` |
| App | Official \`matomo\` Apache image (pin the tag you installed) |
| Database | Official \`mariadb\` (not Postgres, not Bitnami) |
| Archive | CronJob \`matomo-archive\` every 15 minutes |
| Storage | Default StorageClass (often \`local-path\`) |
| Tunnel | \`cloudflared\` Deployment + Secret (tunnel token) |
| Dashboard auth | Cloudflare Access + Matomo login |
| Tracking | Access Bypass for \`/matomo.php\`, \`/matomo.js\`, \`/piwik.php\`, \`/piwik.js\` |
| Secrets | Kubernetes Secrets (not committed) |

Design: [2026-09-14 Matomo K3s Cloudflare design](../superpowers/specs/2026-09-14-matomo-k3s-cloudflare-design.md).

## Exposure policy

- **Tracking:** public on purpose. Sites cannot record visits if these paths require Access.
- **Dashboard:** Cloudflare Access (email allowlist) and Matomo’s own login.
- **Never** enable Tunnel **Protect with Access** on this hostname.
- **Break-glass admin:** host SSH / Headscale remain independent of Cloudflare.
- **MariaDB:** ClusterIP only.

## Install guide (single-node K3s)

Replace secret values locally. Never commit tokens or passwords.

### 1. Prerequisites

\`\`\`bash
kubectl get nodes -o wide
kubectl get ns
kubectl get storageclass
curl -sI https://api.cloudflare.com | head -n 1
export STORAGE_CLASS=\$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\\\\.kubernetes\\\\.io/is-default-class=="true")].metadata.name}')
echo "STORAGE_CLASS=\${STORAGE_CLASS}"
\`\`\`

Expect the JupyterHub/n8n cluster (teaching GPU host A), a default StorageClass, and outbound HTTPS to Cloudflare.

### 2. Cloudflare Tunnel and split Access

In [Cloudflare Zero Trust](https://one.dash.cloudflare.com/):

1. Create a **Cloudflared** tunnel (name \`homelab-matomo\`). Save the token only on the host:

\`\`\`bash
umask 077
mkdir -p ~/secrets
nano ~/secrets/matomo-tunnel-token.txt
chmod 600 ~/secrets/matomo-tunnel-token.txt
\`\`\`

2. Public hostname:

| Field | Value |
|-------|--------|
| Hostname | \`webanalytics.willyrv.com\` |
| Type | HTTP |
| URL | \`matomo.matomo.svc.cluster.local:80\` |
| Protect with Access | **Off** |

3. Access **Bypass** (Everyone) applications for paths \`/matomo.js\`, \`/matomo.php\`, \`/piwik.js\`, \`/piwik.php\`.
4. Access **Allow** (email) application for \`webanalytics.willyrv.com\` with no path.

### 3. Namespace and Secrets

\`\`\`bash
kubectl create namespace matomo
umask 077
openssl rand -hex 24 | tee ~/secrets/matomo-db-password.txt >/dev/null
openssl rand -hex 24 | tee ~/secrets/matomo-db-root-password.txt >/dev/null
kubectl -n matomo create secret generic matomo-db-auth \\
  --from-literal=mariadb-root-password="\$(cat ~/secrets/matomo-db-root-password.txt)" \\
  --from-literal=password="\$(cat ~/secrets/matomo-db-password.txt)" \\
  --from-literal=username=matomo \\
  --from-literal=database=matomo
kubectl -n matomo create secret generic cloudflare-tunnel-token \\
  --from-literal=token="\$(cat ~/secrets/matomo-tunnel-token.txt)"
\`\`\`

### 4–6. MariaDB, Matomo, cloudflared

Apply the StatefulSet/Deployment/Service manifests from the [implementation plan](../superpowers/plans/2026-09-14-matomo-k3s-cloudflare.md) Tasks 4–6. Pin image tags. Database host in the wizard is \`matomo-mariadb\`, not \`localhost\`.

### 7. After the wizard

- Trusted host \`webanalytics.willyrv.com\`, \`assume_secure_protocol = 1\`, \`proxy_client_headers[] = "HTTP_CF_CONNECTING_IP"\`.
- Anonymize IPs, cookieless tracking, respect DNT, 13-month deletion, disable browser-triggered archiving.
- Enable CronJob \`matomo-archive\` (\`--url=https://webanalytics.willyrv.com/\`).

### 8. Verify and back up

- \`curl -sI https://webanalytics.willyrv.com/matomo.js\` is not an Access redirect.
- \`curl -sI https://webanalytics.willyrv.com/\` is Access-gated.
- A real page with the JS snippet records a visit after archive.
- Delete the Matomo pod; site and visits remain.

\`\`\`bash
kubectl -n matomo exec statefulset/matomo-mariadb -- \\
  mariadb-dump -umatomo -p"\$(cat ~/secrets/matomo-db-password.txt)" matomo \\
  > ~/secrets/matomo-mysqldump-\$(date +%Y%m%d).sql
kubectl -n matomo exec deploy/matomo -- cat /var/www/html/config/config.ini.php \\
  > ~/secrets/matomo-config.ini.php
\`\`\`

Keep the dump, \`config.ini.php\`, and DB passwords together. PVCs are not a backup.

## Privacy defaults

Personal sites, not advertising: anonymize IPs, no tracking cookies unless a site later needs them, 13-month retention, respect DNT, no heatmaps/session recordings, snippet only on sites you own.

## Follow-ups

- Tag Manager \`/js/container_*.js\` and opt-out iframe Bypass paths if those features are enabled
- Shared Tunnel in front of Traefik for many apps
- SOPS + Flux when a separate GitOps repo exists
- Optional geolocation database (DB-IP / MaxMind)

## See also

- [Networking and exposure](../architecture/networking.md)
- [Phase 5 — stateful apps](../guides/phase-05-stateful-apps.md)
- [Deployment topology](../experiences/deployment-topology.md)
- Experience: [2026-09-14 Matomo on K3s](../experiences/2026-09-14-matomo-k3s-cloudflare.md)
- Design: [2026-09-14-matomo-k3s-cloudflare-design.md](../superpowers/specs/2026-09-14-matomo-k3s-cloudflare-design.md)
- Plan: [2026-09-14-matomo-k3s-cloudflare.md](../superpowers/plans/2026-09-14-matomo-k3s-cloudflare.md)
- Upstream: https://matomo.org/matomo-on-premise/
- Docker: https://github.com/matomo-org/docker
```

When writing the real file, use normal markdown fences (not backslash-escaped). Include the actual image tags from `kubectl -n matomo get deploy,sts -o yaml | grep image:`.

- [ ] **Step 2: Patch `docs/architecture/networking.md`**

In **Cloudflare Tunnel and Access (alternate gate)**, keep the n8n sentence and add Matomo’s split gate. Replace that subsection with:

```markdown
## Cloudflare Tunnel and Access (alternate gate)

For selected applications (starting with [n8n](../apps/n8n.md) and [Matomo](../apps/matomo.md)), Cloudflare Tunnel can publish HTTPS without opening inbound ports on the homelab. Cloudflare Access then enforces allowlisted users on the **dashboard / editor**. This complements host-level WireGuard: WireGuard remains the break-glass admin path when the cluster or Cloudflare path is unavailable; Tunnel + Access is acceptable for app UIs that should not use Traefik/cert-manager public Ingress on day one.

[Matomo](../apps/matomo.md) is different from n8n: tracking endpoints (`/matomo.php`, `/matomo.js`, and the `piwik.*` aliases) must stay reachable without Access, or public sites cannot record visits. Protect the dashboard on `webanalytics.willyrv.com` with Access; Bypass those tracking paths; do not enable Tunnel **Protect with Access** on that hostname.
```

Under **Never expose directly**, add MariaDB/MySQL next to PostgreSQL:

```markdown
- PostgreSQL
- MariaDB / MySQL
```

Under **Public**, add:

```markdown
- Matomo tracking endpoints (JS snippet / `matomo.php`); the Matomo **dashboard** stays Access-gated
```

- [ ] **Step 3: Update deployment topology**

In `docs/experiences/deployment-topology.md`:

1. Inside `subgraph OtherLAN`, add a node next to `N8N`:

```text
    MATOMO["Matomo + MariaDB + cloudflared<br/>webanalytics.willyrv.com"]
```

2. Add edges:

```text
  CF -->|"Tunnel"| MATOMO
  GuestA --- MATOMO
```

3. In **Hosts and exposure**, extend teaching GPU host A:

| Host | Role | Services | How it is reached |
|------|------|----------|-------------------|
| Teaching GPU host A | Compute / teaching node | Single-node k3s, JupyterHub (+ GPU), n8n, Matomo | Public: Cloudflare Tunnel + Access → `jupyter.willyrv.com`, the n8n Access-protected hostname, and `webanalytics.willyrv.com` (Access on the Matomo dashboard; tracking paths Bypass). Not covered by the home LAN Headscale route unless this host joins the mesh or its LAN is advertised |

4. In **Notes**, add that Matomo tracking URLs are public by design.

5. In **Canonical write-ups**, link `2026-09-14-matomo-k3s-cloudflare.md`.

Do not add LAN IPs or private hostnames.

- [ ] **Step 4: Create the experience entry**

Create `docs/experiences/2026-09-14-matomo-k3s-cloudflare.md` in the same first-person style as `docs/experiences/2026-07-31-n8n-k3s-cloudflare.md`:

- Context: wanted OSS GA for `willyrv.com` / blogs / docs
- Decision: Approach 1 from the spec (k3s official images, split Access)
- What you did (Tasks 1–8 condensed)
- What worked / friction (Access Bypass, RWO CronJob vs sidecar, probe tweaks)
- Consequences: handbook pages; follow-ups
- See also: app page, design, plan, networking, topology

Fill image tags and CronJob vs sidecar from the live install. No secrets.

- [ ] **Step 5: Index links**

`docs/experiences/README.md` — add at the top of the entry list:

```markdown
- [2026-09-14 — Matomo on single-node K3s with Cloudflare Tunnel](2026-09-14-matomo-k3s-cloudflare.md)
```

`README.md` apps list — add after n8n:

```markdown
- [Matomo](docs/apps/matomo.md) (single-node K3s + Cloudflare Tunnel)
```

`docs/guides/phase-05-stateful-apps.md` — in Details, after the JupyterHub paragraph, add:

```markdown
Matomo (web analytics for public/personal sites) is validated on teaching GPU host A at `webanalytics.willyrv.com` via Cloudflare Tunnel: Access on the dashboard, public tracking paths, MariaDB dumps plus `config.ini.php`. See [Matomo](../apps/matomo.md).
```

Add `[Matomo](../apps/matomo.md)` to that page’s See also list.

- [ ] **Step 6: Require the new app page in `scripts/verify-docs.sh`**

In the `required_files=(` array, after `docs/apps/n8n.md`, add:

```bash
  docs/apps/matomo.md
```

- [ ] **Step 7: Verify docs**

```bash
./scripts/verify-docs.sh
```

Expected: exit 0. Fix broken relative links or inventory leaks before committing.

- [ ] **Step 8: Commit handbook updates**

```bash
git add docs/apps/matomo.md \
  docs/architecture/networking.md \
  docs/experiences/deployment-topology.md \
  docs/experiences/README.md \
  docs/experiences/2026-09-14-matomo-k3s-cloudflare.md \
  docs/guides/phase-05-stateful-apps.md \
  README.md \
  scripts/verify-docs.sh
git commit -m "$(cat <<'EOF'
Document Matomo on K3s with Cloudflare Tunnel and split Access.

EOF
)"
```

Only stage files that exist and were intentionally changed. If the live install is not done in this session, still add `docs/apps/matomo.md` as **Planned** with the runbook, and skip or mark the experience as in progress — do not invent a lived log.

---

### Task 10: Operator handoff checklist

**Files:**
- None required

**Interfaces:**
- Consumes: completed Tasks 1–9
- Produces: operator-ready summary

- [ ] **Step 1: Fill this checklist offline (do not commit secrets)**

```text
[ ] kubeconfig is teaching GPU host A (n8n/Jupyter namespaces present)
[ ] Namespace matomo healthy (matomo, matomo-mariadb, cloudflared)
[ ] CronJob matomo-archive succeeding (or sidecar documented)
[ ] ~/secrets holds DB passwords, tunnel token, config.ini.php, latest dump
[ ] curl /matomo.js is not Access-redirected
[ ] curl / is Access-gated
[ ] One owned site shows a visit
[ ] Protect with Access is OFF on the Tunnel hostname
[ ] Handbook docs/apps/matomo.md matches what was installed
[ ] Follow-ups known: Tag Manager paths, Traefik-shared tunnel, GitOps/SOPS
```

- [ ] **Step 2: No further commit unless docs still drift**

---

## Self-review (plan vs spec)

| Spec requirement | Task |
|------------------|------|
| Teaching GPU host A, existing K3s | Task 1 |
| Namespace `matomo` | Task 3 |
| Hostname `webanalytics.willyrv.com` | Task 2 |
| Official Matomo Apache image + PVC | Task 5 |
| Official MariaDB, not Postgres/Bitnami | Task 4 |
| CronJob `core:archive` (+ RWO fallback) | Task 7 |
| cloudflared → ClusterIP `:80` | Task 6 |
| Access Allow on dashboard | Tasks 2, 6 |
| Access Bypass tracking paths | Tasks 2, 6, 8 |
| Protect with Access forbidden | Tasks 2, 6, 9 |
| Wizard DB host in-cluster | Task 7 |
| Trusted host + `CF-Connecting-IP` | Task 7 |
| Privacy defaults (IP, cookies, DNT, 13 months) | Task 7 |
| Secrets not in git | Tasks 3–9 |
| Tracking + persistence + dump/`config.ini.php` | Task 8 |
| `docs/apps/matomo.md`, networking, topology, Phase 5, README, experience | Task 9 |
| `verify-docs.sh` | Task 9 |
| No paid plugins / Traefik / Flux / GA import / Compose / OVH | Global constraints |
| Success criteria | Tasks 6–9 |

Image tags are discovered/pinned at install and written into the handbook in Task 9. CronJob vs sidecar is an explicit fallback, not an open TBD.
