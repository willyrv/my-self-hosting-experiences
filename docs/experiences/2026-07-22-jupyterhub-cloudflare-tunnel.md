# JupyterHub for three students on a big k3s box

Date: 2026-07-22 (GPU follow-up 2026-07-23)  
Status: Accepted

## Context

I got a powerful machine (~24 cores, ~128 GB RAM, multi-terabyte NVMe, RTX 4090) and wanted a small teaching setup: **three students**, each with their **own space**, running notebooks I prepare. I compared marimo and JupyterHub and chose **JupyterHub** for real multi-user isolation and quotas. marimo stays useful later for reactive demos or published apps, not as the classroom account system.

The host is fresh Ubuntu (hostname `GUEST1` / `guest1`), on LAN address **`172.16.0.136`**, not on my `192.168.1.0/24` segment. Public access therefore goes through **Cloudflare Tunnel + Access** at `https://jupyter.willyrv.com`, same pattern as OpenProject — my ISP CGNAT still rules out simple home port forwards.

## What I installed

1. Single-node **k3s** and **Helm** (kubeconfig copied to `~/.kube/config` so kubectl does not talk to `localhost:8080`).
2. **Zero to JupyterHub** Helm chart in namespace `jhub`, with values in `~/jupyterhub/values.yaml`:
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

## Enabling the RTX 4090 inside Jupyter (next day)

I wanted GPU acceleration (CuPy) for a NumPy training notebook. On the **host**, `nvidia-smi` looked perfect (driver 595, CUDA 13.2, RTX 4090). Inside the Jupyter pod it failed: no `nvidia-smi`, CuPy reported `runtime 13020` and **`driver 0`**. The runtime libraries were in the environment, but k3s was not passing the GPU through.

What fixed it, in order:

1. Install **NVIDIA Container Toolkit** on the node (`nvidia-ctk` was missing at first).
2. Restart k3s so containerd picks up the NVIDIA runtime; set `default-runtime: nvidia` in `/etc/rancher/k3s/config.yaml` if needed.
3. Deploy the **NVIDIA device plugin**. Until `kubectl describe node` showed `nvidia.com/gpu: 1` under Capacity/Allocatable, nothing could schedule a GPU. Patching the plugin DaemonSet with `runtimeClassName: nvidia` was required on this k3s setup.
4. Edit `~/jupyterhub/values.yaml` to request a GPU on `singleuser` (`extraPodConfig.runtimeClassName` + `extraResource` limits/guarantees for `nvidia.com/gpu: "1"`).
5. **`helm upgrade jhub ... -f values.yaml`** — editing the file alone does not change the release; I confirmed with `helm get values jhub -n jhub`, then deleted `jupyter-admin` so the new pod picked up the GPU.

After that, `nvidia-smi` worked in the notebook pod and CuPy could see a real driver. Matching the CuPy wheel to the host CUDA major (`cupy-cuda13x` for CUDA 13.x) mattered; swapping wheels never helps when `driver` is still `0`.

## Outcome

`https://jupyter.willyrv.com` works: Access → Hub → Lab for admin and students, with separate environments on a machine that has room to spare. GPU notebooks work once the device plugin advertises the GPU and the Helm values actually request it.

## Follow-ups

- Pin image/chart versions instead of `latest`.
- Shared course materials volume or git-pull init for assignments.
- Join GUEST1 to Headscale for private admin access.
- Backup user home PVCs before the next teaching term.
- Decide how to share one GPU across students (queue, time-slicing, or admin-only GPU profile).

## See also

- Runbook: [JupyterHub](../apps/jupyterhub.md)
- [marimo](../apps/marimo.md)
- [OpenProject + Tunnel](2026-07-22-openproject-cloudflare-tunnel.md)
- [Headscale / CGNAT](../apps/headscale.md)
