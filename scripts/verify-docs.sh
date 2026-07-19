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
