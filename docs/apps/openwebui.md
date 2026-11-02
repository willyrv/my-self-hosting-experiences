# Open WebUI

Status: Planned

## Purpose

[Open WebUI](https://docs.openwebui.com/) is a self-hosted chat interface for an OpenAI-compatible model API. This lab will run one instance on teaching GPU host B, next to the second JupyterHub (`jupyter2.willyrv.com`). The UI does not use the GPU. Model serving stays outside this install.

## Placement (intended)

| Role | Where |
|------|--------|
| k3s + Open WebUI (SQLite on a local PVC) | Teaching GPU host B (same single-node cluster as JupyterHub `jupyter2`) |
| Public HTTPS | Cloudflare Tunnel → `https://chat.willyrv.com` |
| Who can open it | Cloudflare Access (email) **and** an Open WebUI account. Open sign-up off |
| Models | Existing OpenAI-compatible base URL. Ollama is not installed by the chart |

## Manual install

Run the commands yourself on host B:

**[Guide — Open WebUI on k3s + Cloudflare Tunnel](../guides/openwebui-k3s-cloudflare.md)**

## See also

- Upstream: https://docs.openwebui.com/deployment/kubernetes
- [JupyterHub on host B](../guides/jupyterhub-gpu-k3s-cloudflare.md)
- [Networking](../architecture/networking.md)
