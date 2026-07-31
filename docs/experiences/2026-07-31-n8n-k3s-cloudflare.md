# n8n on single-node K3s with Cloudflare Tunnel

Date: 2026-07-31  
Status: Accepted

## Context

I have a PC with plenty of CPU and RAM and an existing single-node K3s install. I wanted n8n for personal automation and teaching, exposed over HTTPS without opening inbound ports on the home network. The handbook had n8n listed as Planned with a VPN-only editor preference; for this service I preferred Cloudflare Tunnel plus Cloudflare Access instead.

## Decision

Deploy **Approach 1** from the design spec:

- Namespace `n8n` on the existing single-node cluster
- Bitnami PostgreSQL via Helm + PVC
- 8gears n8n Helm chart + PVC, Postgres as the DB
- `cloudflared` Deployment using a tunnel token Secret
- Cloudflare Access (email allowlist) in front of the public hostname

I ran the install commands on the K3s host myself and used the docs repo as the guide and journal.

## What I did

1. Confirmed the node was Ready, Helm 3 was available, `local-path` was the default StorageClass, and the host could reach Cloudflare.
2. Created a Cloudflare Tunnel and Access application for my n8n hostname, and saved the tunnel token under `~/secrets/` (not in Git).
3. Created Kubernetes Secrets for DB auth, `N8N_ENCRYPTION_KEY`, and the tunnel token.
4. Installed PostgreSQL with Helm; the pod came up cleanly and the PVC bound.
5. Installed n8n with Helm pointed at Postgres and my public hostname. Migrations ran on first boot and the logs showed the editor URL I expected.
6. Deployed two `cloudflared` replicas. After the Tunnel went Healthy, Access challenged me and then the n8n UI loaded.

## What worked well

- Direct Tunnel → ClusterIP (no Traefik/cert-manager for this app) was simple on a single node.
- Access is a good teaching gate: I can invite emails without sharing cluster credentials.
- Bitnami Postgres pulled and ran without needing the free-image fallback on this install.
- Separating secrets on the host (`~/secrets/`) from the docs repo kept the handbook publishable.

## Friction

- I initially forgot to create `~/secrets/n8n-tunnel-token.txt`, so creating the tunnel Secret failed until I copied the token from Zero Trust.
- Interactive `kubectl run -it` smoke tests sometimes hid useful stdout; non-interactive runs (or checking Deployments/logs) were clearer.
- n8n logged future deprecations around task runners and a few security env defaults. Harmless for day one; I should tighten those later.

## Consequences

- `docs/apps/n8n.md` is now an install runbook for this pattern, not a Planned stub.
- Networking docs mention Cloudflare Tunnel + Access as an alternate gate beside WireGuard.
- Public unauthenticated webhooks, Traefik-shared tunnels, CloudNativePG, and GitOps/SOPS remain follow-ups.
- I still need a habit of `pg_dump` plus offline copies of the encryption key before I trust important workflows.

## See also

- [n8n app page](../apps/n8n.md)
- [Design](../superpowers/specs/2026-07-31-n8n-k3s-cloudflare-design.md)
- [Implementation plan](../superpowers/plans/2026-07-31-n8n-k3s-cloudflare.md)
- [Networking](../architecture/networking.md)
