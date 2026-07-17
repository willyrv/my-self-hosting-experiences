# Self-hosting documentation repository — design

Date: 2026-07-18  
Status: Approved for planning

## Purpose

Build a Git repository that serves two audiences from one place:

1. **Public guide** — a followable handbook for a hybrid K3s homelab on 2–3 machines.
2. **Personal lab journal** — dated experience notes capturing decisions, experiments, and deviations from the canonical docs.

Source material for v1 is `self_hosting_k3s_architecture.md`. This repository is **documentation-only** at first. GitOps manifests live in a separate repository later; this repo documents the intended Flux layout so that split is easy.

## Goals

- Reorganize the architecture notes into maintainable Markdown under `docs/`.
- Provide a phased implementation path (Phases 1–7) readers can follow.
- Keep per-application depth in dedicated app pages.
- Cite useful external resources in the README (and lightly elsewhere).
- Stay MkDocs-ready (`docs/` as future site root) without introducing a generator in v1.
- Avoid inventing unvalidated install runbooks; mark unfinished lived procedures as **Planned**.

## Non-goals (v1)

- Flux/Kubernetes manifests, secrets, or real inventory (IPs, hostnames, credentials).
- Guaranteed-working install scripts.
- Full deep-dives beyond what the architecture notes already cover (e.g. complete Authentik or Prometheus retention tuning).
- Shipping an MkDocs (or other) static site build.

## Approach

**Phase-first handbook** (selected):

- `docs/architecture/` — why / decisions
- `docs/guides/` — how / build order
- `docs/apps/` — per-service depth
- `docs/experiences/` — dated personal log
- Root `README.md` — public front door, stack summary, navigation, useful resources

Rejected alternatives:

- Topic-centric wiki only — weaker build-order story.
- Single long handbook — harder to maintain and to grow into a docs site.

## Repository layout

```text
my-self-hosting-experiences/
├── README.md
├── LICENSE                              # CC-BY-4.0 for documentation
├── CONTRIBUTING.md
├── self_hosting_k3s_architecture.md     # Original working note (retained)
├── .gitignore
└── docs/
    ├── index.md
    ├── architecture/
    │   ├── overview.md
    │   ├── options.md
    │   ├── machine-roles.md
    │   ├── storage.md
    │   ├── networking.md
    │   ├── auth.md
    │   ├── monitoring.md
    │   ├── backups.md
    │   ├── resources.md
    │   └── gitops-layout.md
    ├── guides/
    │   ├── phase-01-base-os.md
    │   ├── phase-02-vpn-access.md
    │   ├── phase-03-k3s-cluster.md
    │   ├── phase-04-low-risk-apps.md
    │   ├── phase-05-stateful-apps.md
    │   ├── phase-06-media-and-git.md
    │   └── phase-07-operations.md
    ├── apps/
    │   ├── openproject.md
    │   ├── jellyfin.md
    │   ├── cloud-nextcloud-seafile.md
    │   ├── wireguard.md
    │   ├── marimo.md
    │   ├── jupyterhub.md
    │   ├── gitlab-or-forgejo.md
    │   └── n8n.md
    ├── experiences/
    │   ├── README.md
    │   └── 2026-07-18-architecture-decision.md
    └── superpowers/
        └── specs/
            └── 2026-07-18-self-hosting-docs-repo-design.md
```

## Content strategy

### Voice

| Area | Voice |
|------|--------|
| `architecture/`, `guides/`, `apps/` | Instructional, recommended patterns; suitable for public readers |
| `experiences/` | First-person, dated; decisions, dead ends, hardware quirks |

When an experience decision becomes lasting policy, update the canonical doc and link back from the experience entry.

### Seed content rules

- Lift and lightly reorganize content from `self_hosting_k3s_architecture.md`.
- Phase guides include: goal, checklist, links to architecture/apps, and “verify before next phase.”
- Do not invent step-by-step commands that have not been validated; label those sections **Planned**.
- After v1, the docs under `docs/` are the maintained source of truth; the root architecture file remains as the historical working note.

### README requirements

- One-paragraph purpose (lab journal + hybrid K3s guide).
- Short stack snapshot (hybrid recommendation).
- Navigation into `docs/`.
- **Useful resources** citing at least:
  - https://github.com/mikeroyal/Self-Hosting-Guide
  - https://www.kdnuggets.com/10-github-repositories-to-master-self-hosting
  - https://github.com/awesome-selfhosted/awesome-selfhosted
  - https://github.com/n8n-io/n8n
- Note that MkDocs Material (or similar) can be added later with `docs/` as the site root.

### App: n8n

Include `docs/apps/n8n.md` as an optional/planned automation platform page with a link to the upstream project. It is not required in the initial deployment phases from the architecture notes.

## Content mapping

| Source (architecture note) | Destination |
|----------------------------|-------------|
| Intro + Option C recommendation + final recommendation | `docs/architecture/overview.md` |
| Options A / B / C | `docs/architecture/options.md` |
| Machine roles | `docs/architecture/machine-roles.md` |
| Ingress, MetalLB, exposure policy, VPN placement | `docs/architecture/networking.md` |
| Storage choices | `docs/architecture/storage.md` |
| Authentication | `docs/architecture/auth.md` |
| Monitoring | `docs/architecture/monitoring.md` |
| Backup design | `docs/architecture/backups.md` |
| Resource planning table | `docs/architecture/resources.md` |
| GitOps repository sketch | `docs/architecture/gitops-layout.md` |
| Per-app sections | `docs/apps/*.md` |
| Implementation phases 1–7 | `docs/guides/phase-0N-*.md` |
| Hybrid decision rationale | `docs/experiences/2026-07-18-architecture-decision.md` |

## Conventions

- Relative Markdown links only (GitHub today; MkDocs later).
- Optional page-header status: `Recommended`, `Planned`, or `In progress`.
- Placeholders for hosts/domains (e.g. `projects.example.net`); no real secrets or inventory.
- Documentation license: CC-BY-4.0.
- Experiences naming: `YYYY-MM-DD-short-slug.md`.

## GitOps boundary

This repo does **not** contain `clusters/` or live manifests in v1.

`docs/architecture/gitops-layout.md` documents the intended separate Flux repository layout (infrastructure vs applications, SOPS + age, no plaintext secrets), so a second repo (or later merge) is straightforward.

## Success criteria (v1)

- Full tree above exists with substantive content derived from the architecture notes.
- README cites all four required external resources.
- A reader can navigate from README → architecture overview → phase guides → app pages.
- Experiences folder has a README and the initial architecture-decision entry.
- Unvalidated procedures are clearly marked **Planned**.
- Repository is a git repo with an initial commit history suitable for publishing.

## Implementation next step

After this spec is reviewed and approved, produce an implementation plan via the writing-plans skill, then execute it to create the documentation tree.
