# My self-hosting experiences

Personal lab journal and public handbook for a **hybrid K3s** homelab on two or three machines. The docs explain the architecture decisions, a phased build path, and per-application notes — alongside dated experience entries for what was tried and what changed.

## Stack snapshot

Recommended shape of this lab:

- Three Debian/Ubuntu machines with role labels (infrastructure, compute, storage/media)
- Three-node K3s control plane (or one server + agent if only two machines)
- Traefik + cert-manager; MetalLB or K3s ServiceLB
- Apps in-cluster: OpenProject, JupyterHub, marimo, Uptime Kuma; monitoring/identity later
- Outside or pinned: Headscale (control plane on OVH VPS; home PC as subnet router), Jellyfin on the media/GPU node, GitLab Omnibus or a lighter forge
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
- [Headscale](docs/apps/headscale.md)
- [Uptime Kuma](docs/apps/uptime-kuma.md)
- [WireGuard](docs/apps/wireguard.md) (alternative)
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
