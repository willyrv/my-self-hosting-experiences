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
