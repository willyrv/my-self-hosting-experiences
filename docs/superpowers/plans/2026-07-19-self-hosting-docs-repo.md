# Self-Hosting Docs Repository Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a phase-first Markdown documentation repository that reorganizes `self_hosting_k3s_architecture.md` into public handbook pages plus a personal experiences log, with required external resource citations in the README.

**Architecture:** Documentation-only repo. Canonical content lives under `docs/architecture/`, `docs/guides/`, and `docs/apps/`; dated notes live under `docs/experiences/`. Root `README.md` is the public front door. Original architecture note is retained at the repo root as a historical working document. No Flux manifests in this repo; GitOps layout is documented only.

**Tech Stack:** Git, Markdown, CC-BY-4.0 license text, shell-based verification (file presence + link/URL checks). No site generator in v1.

## Global Constraints

- Source of truth for seed content: `self_hosting_k3s_architecture.md` (repo root).
- Docs under `docs/` become the maintained source of truth after v1; keep the root architecture file as historical.
- Voice: instructional in `architecture/`, `guides/`, `apps/`; first-person dated notes in `experiences/`.
- Do not invent unvalidated install commands; mark unfinished lived procedures with `Status: Planned` or a `## Planned` section.
- Relative Markdown links only; use placeholders like `projects.example.net` (no real secrets/IPs/hostnames).
- README must cite: Self-Hosting-Guide, KDNuggets article, awesome-selfhosted, and n8n.
- License: CC-BY-4.0 for documentation.
- No `clusters/` manifests or secrets managers deployed in this repo.
- MkDocs-ready layout (`docs/` as future site root) but do not add MkDocs config/dependencies in v1.

## File Structure

| Path | Responsibility |
|------|----------------|
| `README.md` | Public front door: purpose, stack snapshot, nav, useful resources |
| `LICENSE` | CC-BY-4.0 |
| `CONTRIBUTING.md` | Personal lab journal + guide contribution note |
| `.gitignore` | Ignore editor/OS junk only |
| `self_hosting_k3s_architecture.md` | Historical working note (track in git; do not delete) |
| `docs/index.md` | Docs home / MkDocs-ready entry |
| `docs/architecture/*.md` | Why / decisions |
| `docs/guides/phase-0N-*.md` | How / phased build order |
| `docs/apps/*.md` | Per-service depth |
| `docs/experiences/*` | Personal log |
| `scripts/verify-docs.sh` | Lightweight structural verification |

---

### Task 1: Repo scaffolding and verification script

**Files:**
- Create: `LICENSE`
- Create: `CONTRIBUTING.md`
- Create: `.gitignore`
- Create: `docs/index.md`
- Create: `scripts/verify-docs.sh`
- Track: `self_hosting_k3s_architecture.md`

**Interfaces:**
- Consumes: none
- Produces: `scripts/verify-docs.sh` checking required paths exist; later tasks extend the required-file list as they add pages

- [ ] **Step 1: Add the original architecture note to git tracking**

```bash
cd <repo-root>
git add self_hosting_k3s_architecture.md
```

- [ ] **Step 2: Create `.gitignore`**

```gitignore
.DS_Store
Thumbs.db
*.swp
*.swo
*~
.idea/
.vscode/
*.html
site/
```

- [ ] **Step 3: Create `LICENSE` with the full Creative Commons Attribution 4.0 International text**

Use the official CC-BY-4.0 legal code from https://creativecommons.org/licenses/by/4.0/legalcode.txt (or the standard short SPDX-style header plus link if the full legal code is impractical to paste). Minimum acceptable content:

```text
This documentation is licensed under Creative Commons Attribution 4.0 International (CC BY 4.0).

https://creativecommons.org/licenses/by/4.0/

You are free to share and adapt the material for any purpose, even commercially, as long as you give appropriate credit, provide a link to the license, and indicate if changes were made.
```

- [ ] **Step 4: Create `CONTRIBUTING.md`**

```markdown
# Contributing

This repository is primarily a **personal self-hosting lab journal** and a **public handbook** derived from that experience.

## How to contribute

- Prefer opening an issue for suggestions, corrections, or clarifications.
- Pull requests that fix broken links, typos, or factual errors are welcome.
- Large structural changes should be discussed first.

## Documentation conventions

- Canonical guidance lives under `docs/architecture/`, `docs/guides/`, and `docs/apps/`.
- Personal decisions and experiments belong in `docs/experiences/` as dated notes (`YYYY-MM-DD-short-slug.md`).
- Do not commit secrets, real inventory, or private hostnames.
- Mark procedures that have not been validated in this lab as **Planned**.

## Dual audience

Keep instructional docs clear for public readers. Put diary-style narrative in the experiences log, and update canonical docs when a decision becomes lasting policy.
```

- [ ] **Step 5: Create `docs/index.md`**

```markdown
# Self-hosting experiences

Documentation for a hybrid K3s homelab on two or three machines: public handbook pages plus a personal experiences log.

## Start here

- [Architecture overview](architecture/overview.md) — recommended hybrid design
- [Implementation phases](guides/phase-01-base-os.md) — build order
- [Experiences log](experiences/README.md) — decisions and experiments

## Browse

| Section | Purpose |
|---------|---------|
| [Architecture](architecture/overview.md) | Why and design decisions |
| [Guides](guides/phase-01-base-os.md) | How to build in phases |
| [Apps](apps/openproject.md) | Per-service notes |
| [Experiences](experiences/README.md) | Dated personal log |

## Docs site later

These files are organized so [MkDocs Material](https://squidfunk.github.io/mkdocs-material/) (or similar) can treat `docs/` as the site root later. This repository does not ship a site generator yet.
```

- [ ] **Step 6: Create `scripts/verify-docs.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

required_files=(
  README.md
  LICENSE
  CONTRIBUTING.md
  .gitignore
  self_hosting_k3s_architecture.md
  docs/index.md
  docs/architecture/overview.md
  docs/architecture/options.md
  docs/architecture/machine-roles.md
  docs/architecture/storage.md
  docs/architecture/networking.md
  docs/architecture/auth.md
  docs/architecture/monitoring.md
  docs/architecture/backups.md
  docs/architecture/resources.md
  docs/architecture/gitops-layout.md
  docs/guides/phase-01-base-os.md
  docs/guides/phase-02-vpn-access.md
  docs/guides/phase-03-k3s-cluster.md
  docs/guides/phase-04-low-risk-apps.md
  docs/guides/phase-05-stateful-apps.md
  docs/guides/phase-06-media-and-git.md
  docs/guides/phase-07-operations.md
  docs/apps/openproject.md
  docs/apps/jellyfin.md
  docs/apps/cloud-nextcloud-seafile.md
  docs/apps/wireguard.md
  docs/apps/marimo.md
  docs/apps/jupyterhub.md
  docs/apps/gitlab-or-forgejo.md
  docs/apps/n8n.md
  docs/experiences/README.md
  docs/experiences/2026-07-18-architecture-decision.md
)

missing=0
for f in "${required_files[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "MISSING: $f"
    missing=1
  fi
done

required_urls=(
  "https://github.com/mikeroyal/Self-Hosting-Guide"
  "https://www.kdnuggets.com/10-github-repositories-to-master-self-hosting"
  "https://github.com/awesome-selfhosted/awesome-selfhosted"
  "https://github.com/n8n-io/n8n"
)

if [[ -f README.md ]]; then
  for url in "${required_urls[@]}"; do
    if ! grep -Fq "$url" README.md; then
      echo "README missing required URL: $url"
      missing=1
    fi
  done
fi

if [[ "$missing" -ne 0 ]]; then
  echo "verify-docs: FAILED"
  exit 1
fi

echo "verify-docs: OK (${#required_files[@]} files, ${#required_urls[@]} README URLs)"
```

- [ ] **Step 7: Make the script executable and confirm it fails until later tasks complete**

```bash
chmod +x scripts/verify-docs.sh
./scripts/verify-docs.sh
```

Expected: `FAILED` with many `MISSING:` lines (architecture/guides/apps/README not created yet). That is correct for this task.

- [ ] **Step 8: Commit scaffolding**

```bash
git add LICENSE CONTRIBUTING.md .gitignore docs/index.md scripts/verify-docs.sh self_hosting_k3s_architecture.md
git commit -m "$(cat <<'EOF'
Add docs repo scaffolding and verification script.

Track the architecture working note and establish MkDocs-ready docs entry points.
EOF
)"
```

---

### Task 2: Architecture pages (why / decisions)

**Files:**
- Create: `docs/architecture/overview.md`
- Create: `docs/architecture/options.md`
- Create: `docs/architecture/machine-roles.md`
- Create: `docs/architecture/storage.md`
- Create: `docs/architecture/networking.md`
- Create: `docs/architecture/auth.md`
- Create: `docs/architecture/monitoring.md`
- Create: `docs/architecture/backups.md`
- Create: `docs/architecture/resources.md`
- Create: `docs/architecture/gitops-layout.md`

**Interfaces:**
- Consumes: content from `self_hosting_k3s_architecture.md`
- Produces: architecture pages linked from `docs/index.md` and later README/guides

**Extraction map (source headings → files):**

| Source heading(s) in `self_hosting_k3s_architecture.md` | Output file |
|----------------------------------------------------------|-------------|
| Opening recommendation + `# Final concrete recommendation` + central principle quote | `overview.md` |
| `# 1. Three possible architectures` (Options A/B/C) | `options.md` |
| `# 2. Suggested machine roles` | `machine-roles.md` |
| `# 4. Storage strategy` | `storage.md` |
| `# 3. Recommended infrastructure stack` (OS, K3s, Ingress/TLS, MetalLB) + `# 10. Network exposure policy` + VPN placement notes from app section as cross-links | `networking.md` |
| `# 6. Authentication` | `auth.md` |
| `# 8. Monitoring` | `monitoring.md` |
| `# 9. Backup design` | `backups.md` |
| `# 11. Resource planning` | `resources.md` |
| `# 7. GitOps and repository organization` | `gitops-layout.md` |

- [ ] **Step 1: Create each architecture file**

For every file:

1. Start with a title and status line, e.g. `Status: Recommended`.
2. Add a one-sentence purpose.
3. Adapt the mapped source content into clean Markdown (keep diagrams/tables/code blocks).
4. Add a short “See also” section with relative links to related architecture, guide, and app pages (even if some targets are created in later tasks — use the exact paths from the File Structure table).
5. In `gitops-layout.md`, explicitly state that manifests live in a **separate repository later**; this docs repo only describes the intended layout. Include the example tree from the source (`homelab/clusters/...`) and the SOPS + age note.
6. In `overview.md`, include the hybrid diagram and the final concrete recommendation block; link to `options.md` for A/B/C detail.
7. In `networking.md`, cover OS baseline briefly or link to Phase 1; include ingress/TLS, ServiceLB/MetalLB, exposure policy (public / VPN-only / LAN-only / never expose).
8. Do not copy the full per-app sections into architecture files — those belong in Task 3.

- [ ] **Step 2: Spot-check that diagrams and the resource table survived**

```bash
rg -n "Option C|Longhorn|3-2-1|WireGuard|MetalLB|role=infrastructure" docs/architecture/
rg -n "Node 1|32–64 GB|Suggested role" docs/architecture/resources.md
```

Expected: matches in the corresponding files.

- [ ] **Step 3: Commit architecture pages**

```bash
git add docs/architecture/
git commit -m "$(cat <<'EOF'
Add architecture handbook pages from the hybrid K3s design notes.

Split decisions on options, roles, storage, networking, and operations into focused docs.
EOF
)"
```

---

### Task 3: Application pages

**Files:**
- Create: `docs/apps/openproject.md`
- Create: `docs/apps/jellyfin.md`
- Create: `docs/apps/cloud-nextcloud-seafile.md`
- Create: `docs/apps/wireguard.md`
- Create: `docs/apps/marimo.md`
- Create: `docs/apps/jupyterhub.md`
- Create: `docs/apps/gitlab-or-forgejo.md`
- Create: `docs/apps/n8n.md`

**Interfaces:**
- Consumes: `# 5. Application-by-application recommendations` from the architecture note
- Produces: app pages for guides and README navigation

**Extraction map:**

| Source subsection | Output file |
|-------------------|-------------|
| `## OpenProject` | `openproject.md` |
| `## Jellyfin` | `jellyfin.md` |
| `## Cloud service` (Nextcloud / Seafile / Rust notes) | `cloud-nextcloud-seafile.md` |
| `## VPN service` | `wireguard.md` |
| `## Marimo` | `marimo.md` |
| `## Jupyter server` | `jupyterhub.md` |
| `## GitLab` | `gitlab-or-forgejo.md` |
| (not in architecture note) | `n8n.md` — new planned stub |

- [ ] **Step 1: Create app pages from the source subsections**

Each app page must include:

1. Title + `Status: Recommended` or `Status: Planned` as appropriate.
2. Purpose (1–2 sentences).
3. Placement guidance (in K3s / pinned node / host-level).
4. Adapted content from the source (deployment sketch, backup notes, warnings).
5. Links to relevant architecture pages and the phase guide that introduces the app.
6. A `## Planned` section if lived install steps are not yet validated.

- [ ] **Step 2: Create `docs/apps/n8n.md` exactly as follows (adapt only if fixing typos)**

```markdown
# n8n

Status: Planned

## Purpose

[n8n](https://github.com/n8n-io/n8n) is an open-source workflow automation platform. It is a useful optional component for gluing self-hosted services together (notifications, backups triggers, webhooks, light integrations) without putting business-critical data paths solely in a SaaS automation tool.

## Placement

Recommended later placement for this lab:

- Deploy on K3s after Phase 4 routing/TLS patterns are proven; or
- Run via Docker Compose on the infrastructure node if you want it independent of the cluster.

Keep the editor UI on **VPN-only** exposure unless you have a deliberate public webhook design with authentication and rate limiting.

## Why it is listed here

This repository documents a growing self-hosting stack. n8n is not required for the initial hybrid K3s phases, but it is a high-leverage automation building block commonly used alongside projects catalogued in [awesome-selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted).

## Planned

- Choose Helm chart vs Compose deployment.
- Define persistent volume strategy for n8n data.
- Document webhook exposure policy and credential storage (SOPS), consistent with [GitOps layout](../architecture/gitops-layout.md).
- Add backup/restore notes before relying on production workflows.

## See also

- [Phase 4 — low-risk apps](../guides/phase-04-low-risk-apps.md)
- [Phase 7 — operations](../guides/phase-07-operations.md)
- Upstream: https://github.com/n8n-io/n8n
```

- [ ] **Step 3: Commit app pages**

```bash
git add docs/apps/
git commit -m "$(cat <<'EOF'
Add per-application handbook pages for the planned homelab stack.

Include OpenProject, media, cloud, VPN, notebooks, Git forge options, and a planned n8n page.
EOF
)"
```

---

### Task 4: Phase guides (how / build order)

**Files:**
- Create: `docs/guides/phase-01-base-os.md`
- Create: `docs/guides/phase-02-vpn-access.md`
- Create: `docs/guides/phase-03-k3s-cluster.md`
- Create: `docs/guides/phase-04-low-risk-apps.md`
- Create: `docs/guides/phase-05-stateful-apps.md`
- Create: `docs/guides/phase-06-media-and-git.md`
- Create: `docs/guides/phase-07-operations.md`

**Interfaces:**
- Consumes: `# 12. Recommended implementation sequence` plus linked architecture/app pages
- Produces: sequential guides linked from README and `docs/index.md`

**Phase content rules (apply to every guide):**

1. Title: `# Phase N — …`
2. `Status: Planned` (until lived through in this lab).
3. `## Goal` — one short paragraph.
4. `## Checklist` — bullet list adapted from the matching phase in the architecture note.
5. `## Details` — expand using linked architecture/app pages; do not invent unvalidated shell install transcripts. Where the architecture note already gives concrete commands (e.g. `kubectl label node ...`), you may include those as illustrative.
6. `## Verify before next phase` — 3–6 concrete checks.
7. `## See also` — previous/next phase links + relevant architecture/app links.

**Phase mapping:**

| Phase file | Source phase | Extra links |
|------------|--------------|-------------|
| `phase-01-base-os.md` | Phase 1 | `../architecture/machine-roles.md`, `../architecture/resources.md` |
| `phase-02-vpn-access.md` | Phase 2 | `../apps/wireguard.md`, `../architecture/networking.md` |
| `phase-03-k3s-cluster.md` | Phase 3 | `../architecture/overview.md`, `../architecture/storage.md`, `../architecture/networking.md` |
| `phase-04-low-risk-apps.md` | Phase 4 | `../apps/marimo.md`, mention Uptime Kuma; optional pointer to `../apps/n8n.md` as later automation |
| `phase-05-stateful-apps.md` | Phase 5 | `../apps/openproject.md`, `../apps/jupyterhub.md`, `../apps/cloud-nextcloud-seafile.md`, `../architecture/backups.md` |
| `phase-06-media-and-git.md` | Phase 6 | `../apps/jellyfin.md`, `../apps/gitlab-or-forgejo.md` |
| `phase-07-operations.md` | Phase 7 | `../architecture/gitops-layout.md`, `../architecture/monitoring.md`, `../architecture/backups.md`, `../architecture/auth.md` |

- [ ] **Step 1: Create all seven phase guides using the rules above**

Include previous/next navigation, for example at the bottom of Phase 3:

```markdown
## Navigation

- Previous: [Phase 2 — VPN access](phase-02-vpn-access.md)
- Next: [Phase 4 — low-risk apps](phase-04-low-risk-apps.md)
```

Phase 1 has no previous link; Phase 7 has no next link.

- [ ] **Step 2: Commit phase guides**

```bash
git add docs/guides/
git commit -m "$(cat <<'EOF'
Add phased implementation guides for the hybrid K3s homelab.

Turn the recommended build sequence into navigable handbook chapters.
EOF
)"
```

---

### Task 5: Experiences log

**Files:**
- Create: `docs/experiences/README.md`
- Create: `docs/experiences/2026-07-18-architecture-decision.md`

**Interfaces:**
- Consumes: hybrid recommendation rationale from the architecture note
- Produces: personal log entry linked from docs index and README

- [ ] **Step 1: Create `docs/experiences/README.md`**

```markdown
# Experiences log

Dated notes from building and operating this self-hosting lab.

## Conventions

- One file per entry: `YYYY-MM-DD-short-slug.md`
- First-person is fine
- Record what you tried, what failed, and what you decided
- When a decision becomes lasting policy, update the canonical docs under `architecture/`, `guides/`, or `apps/`, and link both ways

## Entries

- [2026-07-18 — Architecture decision: hybrid K3s](2026-07-18-architecture-decision.md)
```

- [ ] **Step 2: Create `docs/experiences/2026-07-18-architecture-decision.md`**

```markdown
# Architecture decision: hybrid K3s

Date: 2026-07-18  
Status: Accepted

## Context

I want a self-hosting setup on two or three computers that can grow toward JupyterHub, OpenProject, marimo, media, and related services. Pure Docker Compose is simple, but configuration tends to fragment. Putting absolutely everything in Kubernetes makes storage, GitLab, and hardware-bound media workloads harder than they need to be on a small cluster.

## Decision

Adopt a **hybrid homelab architecture**:

- K3s for web applications and computational workloads
- Host-level (or node-pinned) services for storage-sensitive and hardware-sensitive apps
- Infrastructure managed through Git later (Flux in a separate repo)
- Off-site backups independent of the cluster

Central principle: use Kubernetes to manage applications, but do not make Kubernetes the sole guardian of data or emergency access.

## Alternatives considered

1. **Docker Compose on each machine** — best for simplicity; weak rescheduling and standardization.
2. **Everything on K3s** — one deployment model; distributed storage and heavy apps (GitLab, Jellyfin HA paths) dominate the operational cost too early.
3. **Hybrid K3s (chosen)** — Kubernetes where it helps; WireGuard/Jellyfin/GitLab Omnibus (or a lighter forge) kept outside or carefully pinned.

## Consequences

- Documentation is organized as architecture (why), phase guides (how), and app notes (depth).
- WireGuard stays on the host so cluster breakage does not remove remote admin access.
- Initial storage favors local PVs / NFS over rushing into Longhorn for multi-terabyte media.
- This docs repository does not yet hold Flux manifests; see [GitOps layout](../architecture/gitops-layout.md).

## See also

- [Architecture overview](../architecture/overview.md)
- [Architecture options](../architecture/options.md)
- Original working note: [`self_hosting_k3s_architecture.md`](../../self_hosting_k3s_architecture.md)
```

- [ ] **Step 3: Commit experiences log**

```bash
git add docs/experiences/
git commit -m "$(cat <<'EOF'
Add experiences log with the hybrid K3s architecture decision.

Separate personal decision records from the canonical handbook pages.
EOF
)"
```

---

### Task 6: Root README with useful resources

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: all docs pages created in Tasks 1–5
- Produces: public front door that `scripts/verify-docs.sh` checks for four required URLs

- [ ] **Step 1: Create `README.md`**

```markdown
# My self-hosting experiences

Personal lab journal and public handbook for a **hybrid K3s** homelab on two or three machines. The docs explain the architecture decisions, a phased build path, and per-application notes — alongside dated experience entries for what was tried and what changed.

## Stack snapshot

Recommended shape of this lab:

- Three Debian/Ubuntu machines with role labels (infrastructure, compute, storage/media)
- Three-node K3s control plane (or one server + agent if only two machines)
- Traefik + cert-manager; MetalLB or K3s ServiceLB
- Apps in-cluster: OpenProject, JupyterHub, marimo, Uptime Kuma; monitoring/identity later
- Outside or pinned: WireGuard on the host, Jellyfin on the media/GPU node, GitLab Omnibus or a lighter forge
- Storage: local SSDs first; NFS for shared notebooks/files; Longhorn only where replication is worth the cost
- Operations later: Flux (separate repo), SOPS + age, Restic/Borg, PostgreSQL dumps, etcd snapshots, off-site backups

> Use Kubernetes to manage applications, but do not make Kubernetes the sole guardian of your data or your emergency access path.

## Documentation

- [Docs home](docs/index.md)
- [Architecture overview](docs/architecture/overview.md)
- [Phase 1 — base OS](docs/guides/phase-01-base-os.md)
- [Experiences log](docs/experiences/README.md)
- Historical working note: [self_hosting_k3s_architecture.md](self_hosting_k3s_architecture.md)

### Architecture

- [Overview](docs/architecture/overview.md)
- [Options compared](docs/architecture/options.md)
- [Machine roles](docs/architecture/machine-roles.md)
- [Storage](docs/architecture/storage.md)
- [Networking](docs/architecture/networking.md)
- [Authentication](docs/architecture/auth.md)
- [Monitoring](docs/architecture/monitoring.md)
- [Backups](docs/architecture/backups.md)
- [Resources](docs/architecture/resources.md)
- [GitOps layout (separate repo later)](docs/architecture/gitops-layout.md)

### Apps

- [OpenProject](docs/apps/openproject.md)
- [Jellyfin](docs/apps/jellyfin.md)
- [Cloud (Nextcloud / Seafile)](docs/apps/cloud-nextcloud-seafile.md)
- [WireGuard](docs/apps/wireguard.md)
- [marimo](docs/apps/marimo.md)
- [JupyterHub](docs/apps/jupyterhub.md)
- [GitLab or Forgejo/Gitea](docs/apps/gitlab-or-forgejo.md)
- [n8n](docs/apps/n8n.md) (planned)

## Useful resources

These projects and articles are excellent companions while designing and operating a self-hosted stack:

- [mikeroyal/Self-Hosting-Guide](https://github.com/mikeroyal/Self-Hosting-Guide) — broad self-hosting guide and links across the ecosystem
- [10 GitHub repositories to master self-hosting (KDNuggets)](https://www.kdnuggets.com/10-github-repositories-to-master-self-hosting) — curated repositories for learning self-hosting
- [awesome-selfhosted/awesome-selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted) — large catalogue of software you can host yourself
- [n8n-io/n8n](https://github.com/n8n-io/n8n) — open-source workflow automation useful for gluing self-hosted services together

## Docs site later

Content under `docs/` is arranged so a static site generator such as MkDocs Material can use that folder as the site root later. This repository does not include a generator configuration yet.

## License

Documentation is licensed under [CC BY 4.0](LICENSE).
```

- [ ] **Step 2: Run the verification script and expect success**

```bash
./scripts/verify-docs.sh
```

Expected: `verify-docs: OK (… files, 4 README URLs)`

- [ ] **Step 3: Commit README**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
Add README as the public front door with resource citations.

Link the handbook sections and credit key self-hosting references including n8n.
EOF
)"
```

---

### Task 7: Final consistency pass

**Files:**
- Modify: any docs page with broken relative links or missing See also targets found during verification

**Interfaces:**
- Consumes: full tree from Tasks 1–6
- Produces: green `scripts/verify-docs.sh` and a manual relative-link spot check

- [ ] **Step 1: Re-run structural verification**

```bash
./scripts/verify-docs.sh
```

Expected: OK

- [ ] **Step 2: Check that key relative links resolve to existing files**

```bash
python3 - <<'PY'
from pathlib import Path
import re
root = Path('.')
md_files = list(root.glob('*.md')) + list((root/'docs').rglob('*.md'))
missing = []
for md in md_files:
    text = md.read_text(encoding='utf-8')
    for link in re.findall(r'\[[^\]]*\]\(([^)]+)\)', text):
        if link.startswith(('http://', 'https://', 'mailto:')):
            continue
        path = link.split('#', 1)[0]
        if not path:
            continue
        target = (md.parent / path).resolve()
        if not target.exists():
            missing.append(f'{md}: {link}')
if missing:
    print('BROKEN LINKS:')
    print('\n'.join(missing))
    raise SystemExit(1)
print(f'link-check: OK ({len(md_files)} markdown files)')
PY
```

Expected: `link-check: OK`

- [ ] **Step 3: Fix any broken links found in Step 2, then re-run Steps 1–2**

- [ ] **Step 4: Commit fixes if any; otherwise skip commit**

```bash
git status
# If there are changes:
git add -u docs README.md
git commit -m "$(cat <<'EOF'
Fix documentation links after the consistency pass.

Keep handbook navigation accurate across architecture, guides, and apps.
EOF
)"
```

---

## Self-review (plan author)

1. **Spec coverage:** Layout, dual audience, plain Markdown + MkDocs-ready note, full skeleton with substantive extraction, docs-only GitOps boundary, four resource URLs, n8n app page, experiences entry, CC-BY-4.0, Planned markers — all mapped to Tasks 1–7.
2. **Placeholder scan:** No TBD/TODO implementation steps; extraction maps and full text provided for scaffolding, n8n, experiences, and README.
3. **Consistency:** Paths in `scripts/verify-docs.sh` match the spec layout and task file lists.

## Execution handoff

After approval of this plan, implement task-by-task using subagent-driven development (recommended) or inline executing-plans.
