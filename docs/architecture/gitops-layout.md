# GitOps layout

Status: Recommended

This page describes the intended Flux repository organization and secret-handling policy for the homelab.

## Repository boundary

Kubernetes manifests will live in a **separate repository later**. This documentation repository contains no cluster manifests and only describes the intended layout.

Once the cluster works reliably, Flux can synchronize Kubernetes resources with configuration stored in Git, providing a declarative and version-controlled cluster state.

## Intended manifest repository

```text
homelab/
├── clusters/
│   └── home/
│       ├── infrastructure/
│       └── applications/
├── infrastructure/
│   ├── cert-manager/
│   ├── ingress/
│   ├── metallb/
│   ├── longhorn/
│   ├── monitoring/
│   └── external-secrets/
├── applications/
│   ├── openproject/
│   ├── jupyterhub/
│   ├── marimo/
│   └── cloud/
└── docs/
    ├── architecture.md
    ├── disaster-recovery.md
    └── inventory.md
```

The `clusters/home/` path should select infrastructure and application resources for the home cluster while reusable definitions remain grouped by responsibility.

## Secrets

Never store plaintext passwords in Git. Initially, use **SOPS with age encryption** for secrets committed to the future manifest repository. A secrets manager such as Vault can be considered later, but it introduces substantial operational complexity and should not be a day-one dependency.

Encrypted configuration is only one recovery input. Keep independent copies of age key material and follow the [backup design](backups.md).

## See also

- [Architecture overview](overview.md)
- [Authentication](auth.md)
- [Backup design](backups.md)
- [Phase 7 — operations](../guides/phase-07-operations.md)
- [n8n](../apps/n8n.md)
