# Authentication

Status: Recommended

This page describes when and how to introduce centralized authentication as the service list grows.

## Approach

Possible identity-provider choices include:

- Authentik
- Keycloak
- Authelia combined with an LDAP or OIDC provider

A possible flow is:

```text
Browser
   │
Ingress
   │
Authentication portal
   │
OIDC
   ├── OpenProject
   ├── Grafana
   ├── JupyterHub
   ├── GitLab
   └── Headscale
```

Do not add centralized authentication on day one. First deploy two or three services and understand their native authentication models. Introduce a shared identity provider later, then integrate each service deliberately rather than assuming identical OIDC behavior.

Centralized login does not replace the [network exposure policy](networking.md): administration and notebook interfaces should remain VPN-only even when protected by an identity provider.

## See also

- [Networking and exposure](networking.md)
- [GitOps layout](gitops-layout.md)
- [Phase 7 — operations](../guides/phase-07-operations.md)
- [OpenProject](../apps/openproject.md)
- [JupyterHub](../apps/jupyterhub.md)
- [GitLab or a lighter forge](../apps/gitlab-or-forgejo.md)
