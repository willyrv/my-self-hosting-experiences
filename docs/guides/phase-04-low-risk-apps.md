# Phase 4 — First low-risk applications

Status: Planned

## Goal

Prove repeatable application deployment, routing, TLS, persistence, and exposure policies with services that do not yet hold critical data.

## Checklist

- Deploy Uptime Kuma.
- Deploy a private marimo editing workspace.
- Deploy a separate restricted marimo application or a simple test web application.
- Exercise public, VPN-only, and LAN-only routing as applicable.
- Validate TLS and certificate renewal behavior.
- Validate a small persistent volume and the redeployment procedure.
- Record the deployment and rollback pattern for later applications.

## Details

Use Uptime Kuma for external-style availability checks and a simple web application for ingress and TLS testing. Monitoring can remain lightweight here; the broader metrics, logs, and alerting stack belongs in Phase 7.

Separate marimo's editable and published modes. Place the persistent editing workspace on the application/compute node and keep it VPN-only. Deploy published applications independently with their own dependency images and explicit exposure policy. Do not expose an editable notebook server directly to the Internet.

Keep notebook source in version control where practical, and identify any persistent workspace data, datasets, secrets, and image dependencies needed to recreate each deployment. Treat success in this phase as a validated operational pattern: deploy, route, obtain TLS, persist small state, restart, update, and roll back without involving irreplaceable data.

n8n is an optional later automation service after these patterns are proven. Its editor should remain VPN-only, and it needs a defined persistence, credential, webhook, and backup policy before important workflows depend on it.

## Verify before next phase

- Uptime Kuma can check at least one service through the same route users will take.
- Private marimo editing is reachable through the VPN and not from the public Internet.
- A test application serves a valid certificate through ingress.
- Persistent test data survives a pod restart or redeployment.
- The documented deployment and rollback procedure works for a non-critical application.
- No administrative or editable interface is exposed outside its chosen policy.

## See also

- [marimo](../apps/marimo.md)
- [Monitoring](../architecture/monitoring.md)
- [Networking and exposure](../architecture/networking.md)
- [n8n](../apps/n8n.md)

## Navigation

- Previous: [Phase 3 — K3s cluster](phase-03-k3s-cluster.md)
- Next: [Phase 5 — stateful apps](phase-05-stateful-apps.md)
