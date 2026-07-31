# n8n on single-node K3s with Cloudflare Tunnel — design

Date: 2026-07-31  
Status: Approved for planning

## Purpose

Host an n8n instance for personal use and teaching on an existing single-node K3s PC (24 CPUs, 124 GB RAM), exposed through Cloudflare Tunnel with Cloudflare Access protecting the editor UI.

This design extends the hybrid K3s handbook with a concrete first-app path that uses Cloudflare for HTTPS exposure instead of (or alongside) the handbook’s WireGuard-first private access model.

## Goals

- Run n8n on the already-installed single-node K3s cluster.
- Use PostgreSQL in-cluster for workflow state (not SQLite).
- Expose the UI via Cloudflare Tunnel (no inbound ports on the PC).
- Restrict UI access with Cloudflare Access (allowlisted emails / trusted users).
- Prefer Helm for n8n and PostgreSQL; keep `cloudflared` as a small hand-written Deployment.
- Update handbook docs (`docs/apps/n8n.md`, networking cross-links) so the lived path matches the design.
- Keep a clear upgrade path toward multi-node K3s, Traefik-fronted tunnels, and CloudNativePG later.

## Non-goals (v1)

- Multi-node / HA control plane.
- n8n queue mode or separate worker replicas.
- CloudNativePG operator.
- Routing n8n through Traefik / cert-manager (Cloudflare terminates TLS).
- Public unauthenticated webhooks.
- Flux / SOPS GitOps (document Secrets in-cluster for now; GitOps later per handbook).
- Longhorn or replicated block storage.
- Guaranteed-working secrets or real inventory (domain names, tokens) in this docs repo.

## Context from the handbook

- [docs/apps/n8n.md](../../apps/n8n.md) currently marks n8n as Planned and prefers VPN-only editor exposure.
- [docs/architecture/networking.md](../../architecture/networking.md) centers Traefik + cert-manager + WireGuard; Cloudflare Tunnel is not documented yet.
- Phase 4 treats n8n as optional after low-risk routing patterns are proven; this design deliberately starts with n8n on a single node for teaching value, accepting that Tunnel + Access replace the VPN gate for this service.

## Decision

**Approach 1 — Direct Tunnel to n8n Service**

Deploy n8n and PostgreSQL with Helm. Run `cloudflared` in-cluster so the Tunnel connects directly to the n8n ClusterIP Service. Protect the public hostname with Cloudflare Access.

Rejected for v1:

- **Tunnel → Traefik Ingress** — better when many apps share one Tunnel; extra moving parts for a first app.
- **CloudNativePG** — better long-term Postgres ops; heavier before the first working UI.

## Architecture

```text
Internet users (allowlisted via Cloudflare Access)
        │
        ▼
Cloudflare Access  (auth gate on hostname)
        │
        ▼
Cloudflare Edge    (HTTPS termination)
        │
        ▼
Cloudflare Tunnel  (outbound only from the PC)
        │
        ▼
cloudflared Pod (K3s)  ──►  n8n Service :5678
                              │
                ┌─────────────┴─────────────┐
                ▼                           ▼
         PostgreSQL PVC              n8n data PVC
```

| Concern | Choice |
|---------|--------|
| Cluster | Existing single-node K3s |
| Namespace | `n8n` |
| Hostname | `n8n.<domain>` (exact FQDN chosen at implement time) |
| n8n | Community Helm chart (verify current maintained chart at install time; candidate: 8gears/n8n) |
| PostgreSQL | Separate Bitnami PostgreSQL Helm release in the same namespace, standalone (not HA, not an n8n chart subchart) |
| n8n files | PVC on default / local-path StorageClass |
| Postgres data | Separate PVC |
| Tunnel | `cloudflared` Deployment + Secret (tunnel token) |
| Auth | Cloudflare Access application on the hostname |
| Secrets | Kubernetes Secrets in-cluster (not committed) |

### Starting resources (adjustable)

- n8n: 1–2 CPU / 2–4 Gi RAM
- PostgreSQL: 1 CPU / 1–2 Gi RAM
- cloudflared: minimal (CPU/memory requests only)

## Security model

- Cloudflare Access is mandatory for the editor hostname in v1.
- Tunnel token, database password, and n8n encryption key (`N8N_ENCRYPTION_KEY`) are Kubernetes Secrets; never committed to this repository.
- n8n and PostgreSQL are not published via NodePort / host ports; only `cloudflared` needs outbound HTTPS to Cloudflare.
- Kubernetes API, etcd, and Postgres remain private (LAN / future VPN), consistent with the handbook exposure policy.
- Teaching access is granted by inviting emails in Access policies — not by sharing cluster credentials or the tunnel token.

### Webhooks (explicit follow-up)

v1 keeps webhook endpoints behind the same Access gate (or unused). A separate public webhook hostname with authentication/rate limiting is out of scope and must be designed before production webhook integrations.

## Operations

- Before relying on real workflows: document Postgres dump procedure and PVC backup expectations.
- Pod restart must preserve workflows (Postgres PVC + encryption key stability).
- Teaching demos: prefer Access-invited accounts; rotate invite list after workshops if needed.
- Later migrations without changing Access:
  - Point the same Tunnel at Traefik Ingress (multi-app pattern).
  - Replace Bitnami Postgres with CloudNativePG.
  - Join additional K3s nodes; keep namespace/Services stable.

## Documentation updates in this repo

After implementation planning:

1. Rewrite [docs/apps/n8n.md](../../apps/n8n.md) from Planned to this design (placement, Helm, Tunnel + Access, PVCs, backups).
2. Add a short note or cross-link in [docs/architecture/networking.md](../../architecture/networking.md) that Cloudflare Tunnel + Access is a valid alternate public/private gate for selected apps.
3. Optionally add a dated experience entry when the live install is completed.

Manifests and Helm values may live in a separate GitOps repo later; this docs repo holds the design, runbook narrative, and app notes — not live secrets.

## Success criteria

- n8n UI reachable at `https://n8n.<domain>` only after Cloudflare Access success.
- Direct LAN/public access to n8n without Tunnel+Access is not required and should not be the default.
- Creating a workflow, restarting the n8n pod, and seeing the workflow persist.
- Postgres and n8n PVCs bound and reattached after pod recreation.
- Handbook `docs/apps/n8n.md` reflects the lived architecture.

## Open choices deferred to implementation plan

- Exact Helm chart names/versions and `values.yaml` keys.
- Exact Cloudflare Tunnel public hostname and Access IdP (email OTP vs other).
- StorageClass name present on the cluster (`local-path` vs other).
- Bitnami image/registry pin if the default chart images require a pull secret or alternate registry.
