# 2026-08-09 — GPU JupyterHub on GUEST2 (3090 Ti + local CuPy image)

I stood up a second teaching/GPU JupyterHub box after the GUEST1 / `jupyter.willyrv.com` path. This one is **GUEST2**: fresh Ubuntu, **RTX 3090 Ti**, ~32 GB RAM, LAN around `172.16.0.131/16`. Public URL: **`https://jupyter2.willyrv.com`**.

## What I wanted

- JupyterHub (not a single JupyterLab process) so admin + a few students get isolated servers.
- Notebooks that actually see the GPU (`nvidia-smi`, CuPy).
- Cloudflare Tunnel + Access again — home ISP is still CGNAT, so no port-forward story.
- CuPy available **without** every user running `pip install`, and **without** pushing an image to Docker Hub or GHCR.

## Path that worked

1. Host driver already good (`nvidia-smi`, CUDA **13.2** reported).
2. NVIDIA Container Toolkit, then k3s with `default-runtime: nvidia` in `/etc/rancher/k3s/config.yaml`.
3. NVIDIA device plugin + DaemonSet patch for `runtimeClassName: nvidia` so the node advertised `nvidia.com/gpu: 1`.
4. Zero to JupyterHub Helm chart: DummyAuthenticator allow-list, `proxy-public` ClusterIP, `singleuser` with GPU resources + `runtimeClassName: nvidia`.
5. Tunnel hostname `jupyter2.willyrv.com` → `proxy-public.jhub.svc.cluster.local:80`, Access in front (Google IdP preferred over email OTP).
6. Built `scipy-notebook-cupy13:local` from `quay.io/jupyter/scipy-notebook` + `pip install cupy-cuda13x`, then:

   ```bash
   docker save scipy-notebook-cupy13:local | sudo k3s ctr images import -
   ```

   Pointed Helm `singleuser.image` at that tag with `pullPolicy: IfNotPresent`, upgraded, deleted user pods so they came back on the new image.

## Things that bit me (or almost did)

- **Editing `values.yaml` is not enough.** Until `helm upgrade` runs, `helm get values` still shows the old release. I kept checking the file and wondering why GPU / image settings had not applied.
- **Local images need `IfNotPresent` (or Never)** and the name must match what `k3s ctr images ls` shows — otherwise ImagePullBackOff looking for a registry.
- **CuPy wheel matches host CUDA major** (`cupy-cuda13x` for 13.x). A working `import cupy` with `driverGetVersion() == 0` means the GPU never entered the pod; that is runtime/device-plugin/Helm, not a bad pip package.
- **One GPU ⇒ one GPU notebook** unless I add time-slicing later. Fine for this box.
- GUEST2 sits on `172.16.0.0/16`, which my Headscale subnet router for `192.168.1.0/24` does not cover. Tunnel access still works; VPN/SSH to this host needs Tailscale on the machine or a new advertised route.

## Canonical docs

I wrote the full copy-paste path as a guide (not only the app page):

- [Guide: JupyterHub with GPU on k3s + Cloudflare](../guides/jupyterhub-gpu-k3s-cloudflare.md)
- [JupyterHub app notes](../apps/jupyterhub.md) (GUEST1 teaching stack + GPU section)
- Earlier: [2026-07-22 JupyterHub + Tunnel (+ GPU on guest1)](2026-07-22-jupyterhub-cloudflare-tunnel.md)

## Decision

Keep **two** public Hub URLs for now:

| Host | URL | Role |
|------|-----|------|
| GUEST1 | `jupyter.willyrv.com` | Larger RAM/CPU teaching box (4090 path documented earlier) |
| GUEST2 | `jupyter2.willyrv.com` | Fresh GPU box; local CuPy image; 3090 Ti |

Bake GPU Python stacks into a **local** image imported into k3s when I do not want a private registry. Put secrets and tunnel tokens only on the host, never in git.
