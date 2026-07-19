# GitLab or a lighter Git forge

Status: Recommended

## Purpose

A self-hosted Git forge provides repository hosting and, optionally, issue tracking, a container registry, and CI. GitLab offers the broadest ecosystem, while Forgejo and Gitea use substantially fewer resources.

## Placement

Do not initially deploy the complete cloud-native GitLab Helm chart on a two- or three-machine homelab. Run GitLab Omnibus on a dedicated VM or Docker host, and optionally run GitLab CI runners in K3s:

```text
GitLab VM
├── GitLab web
├── PostgreSQL
├── Redis
├── repositories
└── registry
```

```text
GitLab application → VM or dedicated Docker host
GitLab CI runners  → K3s
```

If you do not need GitLab's complete ecosystem, deploy Forgejo or Gitea as the lighter option. Keep a lighter forge on a dedicated host or in K3s with persistent SSD storage, according to its resource and recovery requirements.

## Backups and warnings

GitLab changes the architecture more than the other listed applications: it requires several components and substantial resources. Back up repositories, the database, configuration, secrets, uploads, and registry data using the forge's supported backup and restore process.

## Planned

- Decide whether the required features justify GitLab instead of Forgejo or Gitea.
- Validate host or K3s placement and set strict resource limits.
- Document runner isolation, ingress, upgrades, backups, and a complete restore test.

## See also

- [Architecture options](../architecture/options.md)
- [Resource planning](../architecture/resources.md)
- [Phase 6 — media and Git](../guides/phase-06-media-and-git.md)
