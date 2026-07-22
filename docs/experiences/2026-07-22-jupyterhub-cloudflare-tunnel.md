# JupyterHub for three students on a big k3s box

Date: 2026-07-22  
Status: Accepted

## Context

I got a powerful machine (~24 cores, ~128 GB RAM, multi-terabyte NVMe) and wanted a small teaching setup: **three students**, each with their **own space**, running notebooks I prepare. I compared marimo and JupyterHub and chose **JupyterHub** for real multi-user isolation and quotas. marimo stays useful later for reactive demos or published apps, not as the classroom account system.

The host is fresh Ubuntu (hostname `GUEST1` / `guest1`), on LAN address **`172.16.0.136`**, not on my `192.168.1.0/24` segment. Public access therefore goes through **Cloudflare Tunnel + Access** at `https://jupyter.willyrv.com`, same pattern as OpenProject — my ISP CGNAT still rules out simple home port forwards.

## What I installed

1. Single-node **k3s** and **Helm** (kubeconfig copied to `~/.kube/config` so kubectl does not talk to `localhost:8080`).
2. **Zero to JupyterHub** Helm chart in namespace `jhub`, with:
   - DummyAuthenticator + allow-list `admin`, `student1`, `student2`, `student3`
   - `proxy-public` ClusterIP (no Ingress; Tunnel targets the proxy)
   - dynamic **local-path** homes (~20 Gi each)
   - per-user limits (e.g. 1–4 CPU, 2–16 GiB memory) and idle **culling**
   - `quay.io/jupyter/scipy-notebook` → JupyterLab
3. **cloudflared** Deployment pointing at `proxy-public.jhub.svc.cluster.local:80`.
4. **Cloudflare Access** in front (Google login preferred after earlier OTP email pain on OpenProject).

## How students log in

1. Pass Cloudflare Access with an allowed identity.  
2. At JupyterHub: username `student1` (etc.), password = the shared Dummy password from Helm values.  
3. Hub spawns a dedicated pod and PVC for that user.

Admin uses username `admin` the same way. This is fine for a tiny class behind Access; I can move to NativeAuthenticator or OAuth when I want distinct passwords per student.

## Network lesson

Because this machine is on **`172.16.0.0/16`**, my Headscale subnet router on `192.168.1.12` does **not** automatically expose it. Tunnel covers the teaching URL. For VPN/SSH break-glass I still need either Tailscale on GUEST1 itself or a route advertisement for that subnet.

## Outcome

`https://jupyter.willyrv.com` works: Access → Hub → Lab for admin and students, with separate environments on a machine that has room to spare.

## Follow-ups

- Pin image/chart versions instead of `latest`.
- Shared course materials volume or git-pull init for assignments.
- Join GUEST1 to Headscale for private admin access.
- Backup user home PVCs before the next teaching term.

## See also

- Runbook: [JupyterHub](../apps/jupyterhub.md)
- [marimo](../apps/marimo.md)
- [OpenProject + Tunnel](2026-07-22-openproject-cloudflare-tunnel.md)
- [Headscale / CGNAT](../apps/headscale.md)
