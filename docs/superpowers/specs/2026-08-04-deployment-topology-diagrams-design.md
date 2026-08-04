# Deployment topology diagrams — design

Date: 2026-08-04  
Status: Approved

## Purpose

Document the computers currently hosting services described in this repository as Mermaid diagrams: one public (no network identifiers) linked from the experiences README, and one private local copy (full IPs and networks) that stays off git.

## Goals

- Independent public Markdown file with a Mermaid topology of hosts, services, and exposure paths.
- Independent private Markdown file with the same topology plus LAN/Tailscale/CIDR details, gitignored.
- Experiences README links the public diagram and explains the private/local companion.
- Call out security rationale for the split.

## Non-goals

- Changing live infrastructure or Cloudflare/Headscale config.
- Publishing OVH public IPv4 literals (not present as literals in experience posts either).
- Auto-generating diagrams from cluster inventory.
- Canvas / IDE-only artifacts as the handbook deliverable.

## Decisions

| Concern | Choice |
|---------|--------|
| Format | Mermaid in Markdown |
| Layout | Two side-by-side files (Approach 1) |
| Public path | `docs/experiences/deployment-topology.md` |
| Private path | `docs/experiences/deployment-topology.local.md` |
| Ignore rule | Add `docs/experiences/deployment-topology.local.md` to `.gitignore` |
| README | Short “Deployment topology” section in `docs/experiences/README.md` |

## Topology content (from experience posts)

| Host (role) | Network context | IPs (private file only) | Services | Exposure |
|-------------|-----------------|-------------------------|----------|----------|
| OVH VPS | Public VPS | Tailscale `100.64.0.2`; public IPv4 not literalized | Nginx/Certbot, Headscale, Uptime Kuma | Direct HTTPS (Cloudflare DNS-only); UDP 3478 DERP STUN |
| Home Ubuntu / `nuc2-ingress` | Home LAN behind CGNAT | `192.168.1.12`, Tailscale `100.64.0.1` | Tailscale subnet router for home LAN | No inbound home ports; advertises `192.168.1.0/24` |
| OpenProject mini PC | Same home LAN | `192.168.1.11` | Single-node k3s, OpenProject, cloudflared | Cloudflare Tunnel + Access → `projects.willyrv.com`; LAN via subnet router |
| GUEST1 | Separate LAN | `172.16.0.136` | Single-node k3s, JupyterHub (+ GPU), n8n (inferred) | Cloudflare Tunnel + Access → `jupyter.willyrv.com` (+ n8n hostname); not on Headscale advertised subnet |

**Inference:** n8n design/spec places it on the high-spec single-node k3s host (24 CPU / ~128 GB), which matches GUEST1. Public and private diagrams note this as inferred if the experience post does not name the host.

## Public vs private rules

**Public file must not include:** LAN IPs, Tailscale IPs, CIDRs, public VPS IPv4, or other host network addresses.

**Public file may include:** host roles/names already in posts, service names, public hostnames under `willyrv.com`, exposure mechanisms (Tunnel/Access, Nginx/Certbot DNS-only, Headscale), CGNAT as a qualitative constraint.

**Private file:** same structure with IPs/CIDRs; top banner that the file must not be committed or published.

## Security note (for README / public file)

Combining service inventory, domains, and exposure methods already aids reconnaissance; omitting IPs/CIDRs reduces that value for a public handbook. The private file is for local ops only.

## See also

- Experiences: Headscale/CGNAT, Uptime Kuma, OpenProject Tunnel, JupyterHub Tunnel, n8n Tunnel
- [Networking](../../architecture/networking.md)
