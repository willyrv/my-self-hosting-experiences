# Guide — Matomo on k3s + Cloudflare Tunnel (manual install)

Status: Planned (commands ready; not yet lived in this lab)  
Audience: You, on **teaching GPU host A**, in a terminal where `kubectl` talks to that cluster.

This is the copy-paste runbook. Run the commands **on host A** (or any machine whose kubeconfig is that cluster). Do not run them against the OpenProject mini PC.

Public URL: `https://webanalytics.willyrv.com`  
Design: [2026-09-14 spec](../superpowers/specs/2026-09-14-matomo-k3s-cloudflare-design.md)  
Agent plan: [2026-09-14 plan](../superpowers/plans/2026-09-14-matomo-k3s-cloudflare.md)

Never put tunnel tokens, DB passwords, or `config.ini.php` in git.

---

## What you are building

```text
Public sites  →  /matomo.js and /matomo.php   →  Cloudflare  (no Access login)
You           →  dashboard at /               →  Cloudflare Access  →  Matomo login
                     │
                     ▼
              Tunnel (outbound from host A)
                     │
              k3s namespace matomo
              ├── matomo (official image, port 80)
              ├── matomo-mariadb (official image, port 3306)
              ├── matomo-archive CronJob
              └── cloudflared
```

---

## 0. One-time locals (this shell)

```bash
export MATOMO_IMAGE=docker.io/library/matomo:5-apache
export MARIADB_IMAGE=docker.io/library/mariadb:11
export CLOUDFLARED_IMAGE=docker.io/cloudflare/cloudflared:2025.8.1
umask 077
mkdir -p ~/secrets
```

Keep this terminal open (or re-export the three image variables if you start a new one).

---

## 1. Confirm the right cluster

```bash
kubectl get nodes -o wide
kubectl get ns
kubectl get --raw='/readyz?verbose' | head
kubectl get storageclass
export STORAGE_CLASS=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
echo "STORAGE_CLASS=${STORAGE_CLASS}"
curl -sI https://api.cloudflare.com | head -n 1
```

**Expect:** one `Ready` node; namespaces for n8n and/or JupyterHub; a default StorageClass (often `local-path`); an HTTP header from Cloudflare.

If `STORAGE_CLASS` is empty:

```bash
export STORAGE_CLASS=local-path
```

If you only see OpenProject and a small node, **stop** — wrong kubeconfig.

---

## 2. Cloudflare Zero Trust (browser)

Do this before `cloudflared` exists in the cluster. The Kubernetes Service name is created later; that is OK.

### 2.1 Tunnel + token

1. Open [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) → **Networks** → **Tunnels** → **Create**.
2. Type: **Cloudflared**. Name: `homelab-matomo`.
3. Copy the tunnel token (starts with `eyJ`).

On host A:

```bash
nano ~/secrets/matomo-tunnel-token.txt
# paste the token, one line, save
chmod 600 ~/secrets/matomo-tunnel-token.txt
```

### 2.2 Public hostname

On that tunnel → **Public Hostname** → **Add**:

| Field | Value |
|-------|--------|
| Subdomain | `webanalytics` |
| Domain | `willyrv.com` |
| Type | HTTP |
| URL | `matomo.matomo.svc.cluster.local:80` |

Save. DNS for `webanalytics.willyrv.com` should be **proxied** (orange cloud).

If there is a **Protect with Access** switch on this hostname, leave it **OFF**. Turning it on blocks anonymous tracking.

### 2.3 Access Bypass (tracking) — four apps

**Access controls** → **Applications** → **Add** → **Self-hosted**.

Create **four** applications. For each: policy action **Bypass**, include **Everyone**.

| Application name | Hostname | Path |
|------------------|----------|------|
| `matomo-tracker-js` | `webanalytics.willyrv.com` | `/matomo.js` |
| `matomo-tracker-php` | `webanalytics.willyrv.com` | `/matomo.php` |
| `matomo-tracker-piwik-js` | `webanalytics.willyrv.com` | `/piwik.js` |
| `matomo-tracker-piwik-php` | `webanalytics.willyrv.com` | `/piwik.php` |

Path-specific apps must exist **in addition to** the dashboard app below. They take precedence.

### 2.4 Access Allow (dashboard)

One more self-hosted application:

| Field | Value |
|-------|--------|
| Application name | `matomo-dashboard` |
| Hostname | `webanalytics.willyrv.com` |
| Path | *(leave empty)* |
| Session duration | 24 hours |
| Policy | **Allow** → Include → **Emails** → your address |
| Login | One-time PIN (or your existing IdP) |

Do **not** put Bypass-Everyone on this fifth app.

### 2.5 DNS check

```bash
dig +short webanalytics.willyrv.com
```

**Expect:** Cloudflare anycast IPs, not your home public IP as the only answer.

---

## 3. Namespace and secrets

```bash
kubectl create namespace matomo

openssl rand -hex 24 | tee ~/secrets/matomo-db-password.txt >/dev/null
openssl rand -hex 24 | tee ~/secrets/matomo-db-root-password.txt >/dev/null
chmod 600 ~/secrets/matomo-db-password.txt ~/secrets/matomo-db-root-password.txt

kubectl -n matomo create secret generic matomo-db-auth \
  --from-literal=mariadb-root-password="$(cat ~/secrets/matomo-db-root-password.txt)" \
  --from-literal=password="$(cat ~/secrets/matomo-db-password.txt)" \
  --from-literal=username=matomo \
  --from-literal=database=matomo

kubectl -n matomo create secret generic cloudflare-tunnel-token \
  --from-literal=token="$(cat ~/secrets/matomo-tunnel-token.txt)"

kubectl -n matomo get secrets
```

**Expect:** `matomo-db-auth` and `cloudflare-tunnel-token`. Do not `kubectl get secret -o yaml` into chat or git.

---

## 4. MariaDB

```bash
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

kubectl -n matomo rollout status statefulset/matomo-mariadb --timeout=5m
kubectl -n matomo get pods,svc,pvc
```

**Expect:** `matomo-mariadb-0` Ready; PVC Bound; Service type ClusterIP.

If the pod is Ready but probes fail because `healthcheck.sh` is missing, edit the StatefulSet and replace **both** probes with:

```yaml
tcpSocket:
  port: 3306
```

Then `kubectl -n matomo rollout status statefulset/matomo-mariadb --timeout=5m`.

SQL smoke test:

```bash
kubectl -n matomo run mysql-smoke --rm --restart=Never \
  --image="${MARIADB_IMAGE}" \
  --env="MYSQL_PWD=$(cat ~/secrets/matomo-db-password.txt)" \
  --command -- mariadb -h matomo-mariadb -u matomo matomo -e 'SELECT 1 AS ok;'
```

**Expect:** `ok` / `1`. If the client binary is `mysql` not `mariadb`, swap the command name.

---

## 5. Matomo app

```bash
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

kubectl -n matomo rollout status deploy/matomo --timeout=5m
kubectl -n matomo get pods,svc,pvc
kubectl -n matomo logs deploy/matomo --tail=40
```

**Expect:** Deployment Ready; no repeating DB connection errors. First start copies files onto the PVC.

---

## 6. cloudflared

Use a **quoted** heredoc so Kubernetes keeps `$(TUNNEL_TOKEN)` as a reference to the env var (the shell must not expand it).

```bash
cat > /tmp/matomo-cloudflared.yaml <<EOF
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

# The file must contain the characters $(TUNNEL_TOKEN), not an empty token.
grep -n 'TUNNEL_TOKEN' /tmp/matomo-cloudflared.yaml
kubectl apply -f /tmp/matomo-cloudflared.yaml
rm -f /tmp/matomo-cloudflared.yaml

kubectl -n matomo rollout status deploy/cloudflared --timeout=120s
kubectl -n matomo logs deploy/cloudflared --tail=40
```

**Expect:** `grep` shows `$(TUNNEL_TOKEN)` in `args`. Logs show the tunnel connected, not auth failures.

Zero Trust → Tunnels → `homelab-matomo` → **Healthy**.

If `args` in the live pod is missing the token placeholder:

```bash
kubectl -n matomo get deploy cloudflared -o jsonpath='{.spec.template.spec.containers[0].args}' ; echo
```

you must re-apply YAML where the last arg is exactly `$(TUNNEL_TOKEN)`.

---

## 7. Check Access split (before the wizard)

```bash
curl -sI https://webanalytics.willyrv.com/matomo.js | head -n 20
echo "----"
curl -sI https://webanalytics.willyrv.com/ | head -n 20
```

**Expect:**

| URL | Result |
|-----|--------|
| `/matomo.js` | HTTP `200` (or `301`/`302` only to another path on the **same** host). **Not** `cloudflareaccess.com`. |
| `/` | Redirect or challenge to Cloudflare Access. **Not** the Matomo UI without login. |

If `/matomo.js` goes to Access: fix Bypass apps or turn **Protect with Access** off, then continue.

Private window: `https://webanalytics.willyrv.com/` → Access email/OTP → Matomo installer.

---

## 8. Matomo wizard

| Field | Value |
|-------|--------|
| Database server | `matomo-mariadb` |
| Login | `matomo` |
| Password | output of `cat ~/secrets/matomo-db-password.txt` |
| Database name | `matomo` |

Create a strong Matomo superuser (this is **not** the Cloudflare Access email). Store it offline, not in git.

Then:

```bash
kubectl -n matomo exec deploy/matomo -- test -f /var/www/html/config/config.ini.php && echo "config ok"
```

**Expect:** `config ok`.

---

## 9. Trusted host, HTTPS, real visitor IPs

```bash
kubectl -n matomo exec deploy/matomo -- cat /var/www/html/config/config.ini.php \
  > ~/secrets/matomo-config.ini.php
chmod 600 ~/secrets/matomo-config.ini.php
```

Edit `~/secrets/matomo-config.ini.php`. Under `[General]` add or merge (do not delete existing salt/database lines):

```ini
assume_secure_protocol = 1
proxy_client_headers[] = "HTTP_CF_CONNECTING_IP"
trusted_hosts[] = "webanalytics.willyrv.com"
```

Copy it back:

```bash
kubectl -n matomo exec -i deploy/matomo -- tee /var/www/html/config/config.ini.php \
  < ~/secrets/matomo-config.ini.php >/dev/null
```

---

## 10. Privacy (Matomo UI)

**Administration** (gear) → Privacy / System (labels vary slightly in Matomo 5):

- Anonymize visitor IPs (at least 2 bytes).
- Do **not** use tracking cookies (cookieless).
- Respect Do Not Track.
- Delete old raw/visit logs after **13 months**.
- **Uncheck** “Archive reports when viewed from the browser”.

Do not install paid Marketplace plugins.

Add your first website (a site you own). Copy the JavaScript snippet. The snippet should call `https://webanalytics.willyrv.com/`. Do not commit a `token_auth` if the UI shows one.

---

## 11. Archive CronJob

Only after `config.ini.php` exists.

```bash
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

kubectl -n matomo create job matomo-archive-now --from=cronjob/matomo-archive
kubectl -n matomo wait --for=condition=complete job/matomo-archive-now --timeout=5m
kubectl -n matomo logs job/matomo-archive-now --tail=50
```

**Expect:** Job complete; logs without a fatal error.

If the Job pod stays **Pending** (`Multi-Attach` / volume in use), the RWO PVC cannot mount twice. Then:

```bash
kubectl -n matomo delete cronjob matomo-archive
kubectl -n matomo delete job matomo-archive-now --ignore-not-found
```

Add this sidecar to the `matomo` container list in the Deployment (same `html` volumeMount as the app), then `kubectl apply` the whole Deployment again:

```yaml
        - name: archive
          image: docker.io/library/matomo:5-apache
          imagePullPolicy: IfNotPresent
          command: ["/bin/sh", "-c"]
          args:
            - while true; do php /var/www/html/console core:archive --url=https://webanalytics.willyrv.com/; sleep 900; done
          env:
            - name: PHP_MEMORY_LIMIT
              value: "512M"
          volumeMounts:
            - name: html
              mountPath: /var/www/html
```

Use the same image tag as `MATOMO_IMAGE`. Note for later docs whether you kept the CronJob or the sidecar.

---

## 12. Prove tracking and persistence

```bash
curl -sI https://webanalytics.willyrv.com/matomo.js | head -n 15
curl -sI https://webanalytics.willyrv.com/matomo.php | head -n 15
curl -sI https://webanalytics.willyrv.com/ | head -n 15
```

Paste the JS snippet on a page you control. Open that page in a browser that has **never** completed Access on `webanalytics.willyrv.com` (another browser or a private window that did not log into Access).

Wait up to 15 minutes, or run another one-shot Job:

```bash
kubectl -n matomo create job matomo-archive-$(date +%H%M%S) --from=cronjob/matomo-archive
```

(If you switched to the sidecar, skip that Job and wait ~15 minutes.)

In the Matomo dashboard, the site should show at least one visit.

Restart test:

```bash
kubectl -n matomo delete pod -l app=matomo
kubectl -n matomo rollout status deploy/matomo --timeout=180s
```

Reload the UI: site and visit still there.

---

## 13. Backup (host disk, not git)

```bash
kubectl -n matomo exec statefulset/matomo-mariadb -- \
  mariadb-dump -umatomo -p"$(cat ~/secrets/matomo-db-password.txt)" matomo \
  > ~/secrets/matomo-mysqldump-$(date +%Y%m%d).sql

kubectl -n matomo exec deploy/matomo -- cat /var/www/html/config/config.ini.php \
  > ~/secrets/matomo-config.ini.php

chmod 600 ~/secrets/matomo-mysqldump-*.sql ~/secrets/matomo-config.ini.php
ls -la ~/secrets/matomo-mysqldump-*.sql ~/secrets/matomo-config.ini.php ~/secrets/matomo-db-password.txt
```

If `mariadb-dump` is not found, retry with `mysqldump` and the same arguments.

Keep together: dump, `config.ini.php`, both DB passwords, tunnel token. Cluster PVCs are not a backup.

---

## 14. Done checklist

```text
[ ] kubectl is teaching GPU host A (n8n/Jupyter namespaces)
[ ] matomo, matomo-mariadb-0, cloudflared Running
[ ] CronJob archive works (or sidecar documented)
[ ] curl /matomo.js is NOT an Access redirect
[ ] curl / IS Access-gated
[ ] Dashboard needs Access AND Matomo login
[ ] Protect with Access is OFF on the Tunnel hostname
[ ] One owned page recorded a visit
[ ] ~/secrets has dump + config.ini.php + passwords + tunnel token
```

When that list is true, tell me what happened (including CronJob vs sidecar and any probe/image tweaks). I will then update `docs/apps/matomo.md`, topology, and the dated experience log.

---

## Troubleshooting

**Wrong cluster.** `kubectl get ns` missing n8n/Jupyter → change kubeconfig.

**MariaDB not Ready.** `kubectl -n matomo describe pod matomo-mariadb-0` and `logs`. PVC Pending usually means StorageClass / disk. Probe errors → switch to `tcpSocket` port 3306.

**Matomo cannot reach DB.** Wizard host must be `matomo-mariadb`, not `localhost`. Secret keys must be `database` / `username` / `password`.

**Tunnel not Healthy.** Token file must be one line, no quotes. `cloudflared` args must include `$(TUNNEL_TOKEN)`. Host must reach `https://api.cloudflare.com`.

**`/matomo.js` requires Access.** Bypass apps missing, path typo, or **Protect with Access** enabled on the Tunnel hostname.

**No visits.** Browser request to `matomo.php` is 302 to Access (same as above), ad blocker, or archive not running. Check Job logs or sidecar logs: `kubectl -n matomo logs deploy/matomo -c archive --tail=50`.

**Archive Job Pending / Multi-Attach.** Use the sidecar in section 11.

**Installer loops after restart.** `matomo-html` PVC not bound or `config.ini.php` missing.
