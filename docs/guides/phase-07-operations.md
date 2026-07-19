# Phase 7 — Operations

Status: Planned

## Goal

Make the working homelab reproducible, observable, recoverable, and manageable without turning any single cluster service into a recovery dependency.

## Checklist

- Create the separate manifest repository and introduce Flux GitOps.
- Encrypt committed secrets with SOPS and age.
- Deploy lightweight metrics, dashboards, alerting, and centralized logs.
- Monitor hosts, Kubernetes, certificates, applications, disks, and backup jobs.
- Send encrypted backups off-site.
- Schedule K3s etcd snapshots and application-aware backups.
- Perform restore tests and maintain disaster-recovery documentation.
- Introduce centralized authentication after native application authentication is understood.

## Details

Keep Kubernetes manifests in a separate GitOps repository, organized by cluster, infrastructure, and applications. Introduce Flux only after manual deployment patterns work reliably. Store no plaintext passwords in Git; use SOPS with age initially and keep independent recovery copies of the age key material.

Start observability with Prometheus, Grafana, Loki, Alertmanager, and Uptime Kuma, with modest retention. Cover node CPU and RAM, temperatures, disk space and SMART status, pod restarts, certificate expiry, HTTP availability, PostgreSQL backup age, backup-job success, UPS state, Internet connectivity, and filesystem or array health. Keep administrative dashboards VPN-only.

Use independent local and encrypted off-site backups. Match tools to data: Restic or Borg for files, `pg_dump` for PostgreSQL, application-specific exports, K3s etcd snapshots, and optionally Velero for Kubernetes resources and selected volumes. A recovery procedure should start from fresh Linux, GitOps configuration, encrypted secrets, database dumps, and persistent-file backups.

Add an identity provider only after two or three services are stable and their native authentication models are understood. Authentik, Keycloak, or Authelia with an LDAP/OIDC provider are candidates. Integrate applications individually and keep the network exposure policy in force; centralized login does not make administrative services safe for public exposure.

## Verify before next phase

- Flux can reconcile the intended cluster configuration from the separate repository without plaintext secrets.
- Alerts fire for representative availability, disk, certificate, and backup failures and reach an operator.
- Centralized logs support investigation of a representative application or cluster failure.
- Encrypted off-site backups complete and can be read with separately retained recovery material.
- A documented restore test rebuilds at least one application from its independent recovery inputs.
- Central authentication works for each deliberately integrated service without widening its exposure policy.

## See also

- [GitOps layout](../architecture/gitops-layout.md)
- [Monitoring](../architecture/monitoring.md)
- [Backup design](../architecture/backups.md)
- [Authentication](../architecture/auth.md)
- [Networking and exposure](../architecture/networking.md)

## Navigation

- Previous: [Phase 6 — media and Git](phase-06-media-and-git.md)
