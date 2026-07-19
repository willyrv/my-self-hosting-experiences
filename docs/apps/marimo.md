# marimo

Status: Recommended

## Purpose

marimo provides reactive Python notebooks that can run as private editing workspaces or restricted web applications. Separate those modes so public applications do not expose an editable notebook server.

## Placement

Deploy marimo in K3s on the application and compute node. Give the editable workspace persistent storage and keep it VPN-only; deploy each published application separately with its own dependency image and exposure policy.

## Deployment sketch

```text
marimo-edit
└── Private, VPN-only, persistent workspace

marimo-app-project-a
└── Read-only or restricted web application

marimo-app-project-b
└── Separate deployment and dependency image
```

Do not expose the editable server directly to the public Internet. Put it behind authentication and preferably behind WireGuard.

## Backups

Keep notebook source in version control where practical. Back up persistent workspace data and document any external datasets or secrets needed to recreate each application image.

## Planned

- Validate separate editor and application deployments on K3s.
- Define persistent workspace storage and dependency-image builds.
- Document authentication, ingress, secrets, backups, and upgrades.

## See also

- [Networking and exposure](../architecture/networking.md)
- [Machine roles](../architecture/machine-roles.md)
- [Phase 4 — low-risk apps](../guides/phase-04-low-risk-apps.md)
