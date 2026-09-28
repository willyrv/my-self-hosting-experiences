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
  docs/guides/jupyterhub-gpu-k3s-cloudflare.md
  docs/guides/matomo-k3s-cloudflare.md
  docs/apps/openproject.md
  docs/apps/jellyfin.md
  docs/apps/cloud-nextcloud-seafile.md
  docs/apps/wireguard.md
  docs/apps/headscale.md
  docs/apps/uptime-kuma.md
  docs/apps/marimo.md
  docs/apps/jupyterhub.md
  docs/apps/gitlab-or-forgejo.md
  docs/apps/n8n.md
  docs/apps/matomo.md
  docs/experiences/README.md
  docs/experiences/2026-07-18-architecture-decision.md
  docs/experiences/2026-07-19-headscale-ovh-cgnat.md
  docs/experiences/2026-07-20-uptime-kuma-vpn-monitoring.md
  docs/experiences/2026-07-22-openproject-cloudflare-tunnel.md
  docs/experiences/2026-07-22-jupyterhub-cloudflare-tunnel.md
  docs/experiences/2026-08-09-jupyterhub-gpu-guest2.md
  docs/experiences/2026-09-28-matomo-k3s-cloudflare.md
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

if ! python3 - <<'PY'
from pathlib import Path
from urllib.parse import unquote
import re
import subprocess

result = subprocess.run(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "--", "*.md"],
    check=True,
    capture_output=True,
    text=True,
)
all_markdown = [Path(path) for path in result.stdout.splitlines()]
markdown_files = [
    path
    for path in all_markdown
    if path.parts[:2] != ("docs", "superpowers")
]

link_pattern = re.compile(r"\[[^\]]*\]\((<[^>]+>|[^)\s]+)")
broken_links = []

for markdown_file in markdown_files:
    text = markdown_file.read_text(encoding="utf-8")
    for match in link_pattern.finditer(text):
        link = match.group(1).strip("<>")
        if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", link) or link.startswith(("/", "#")):
            continue

        path = unquote(link.split("#", 1)[0].split("?", 1)[0])
        if path and not (markdown_file.parent / path).exists():
            broken_links.append(f"{markdown_file}: {link}")

if broken_links:
    print("BROKEN LINKS:")
    print("\n".join(broken_links))
    raise SystemExit(1)

print(f"link-check: OK ({len(markdown_files)} markdown files)")

# Fail if tracked markdown reintroduces private inventory (local *.local.md is gitignored).
ip_pattern = re.compile(
    r"\b(?:(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3})|"
    r"(?:172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})|"
    r"(?:192\.168\.\d{1,3}\.\d{1,3})|"
    r"(?:100\.64\.\d{1,3}\.\d{1,3}))\b"
)
# Documentation / public resolver / loopback / whole private *blocks* (not hosts).
allowed_ips = {
    "127.0.0.1",
    "0.0.0.0",
    "1.1.1.1",
    "1.0.0.1",
    "100.64.0.0",  # CGNAT block documentation only (100.64.0.0/10)
}
# Permit RFC5737 TEST-NET host examples such as 192.0.2.220
allowed_ip_prefixes = ("192.0.2.", "198.51.100.", "203.0.113.")

other_patterns = [
    (re.compile(r"\bnuc2-ingress\b", re.I), "private hostname nuc2-ingress"),
    (re.compile(r"\bGUEST[12]\b"), "private hostname GUEST1/GUEST2"),
    (re.compile(r"\bRTX\s*40\d0\b|\bRTX\s*30\d0\b", re.I), "exact GPU SKU"),
    (re.compile(r"/home/willy\b"), "operator home path"),
    (re.compile(r"--user\s+willy\b"), "operator Headscale username"),
]

leaks = []
for markdown_file in all_markdown:
    if markdown_file.name.endswith(".local.md"):
        continue
    for lineno, line in enumerate(
        markdown_file.read_text(encoding="utf-8").splitlines(), start=1
    ):
        for match in ip_pattern.finditer(line):
            ip = match.group(0)
            if ip in allowed_ips or ip.startswith(allowed_ip_prefixes):
                continue
            leaks.append(f"{markdown_file}:{lineno}: private IP {ip}: {line.strip()[:120]}")
        for pattern, label in other_patterns:
            if pattern.search(line):
                leaks.append(f"{markdown_file}:{lineno}: {label}: {line.strip()[:120]}")

if leaks:
    print("INVENTORY LEAKS (use placeholders; keep real values in docs/**/*.local.md):")
    print("\n".join(leaks))
    raise SystemExit(1)

print("inventory-check: OK")
PY
then
  missing=1
fi

if [[ "$missing" -ne 0 ]]; then
  echo "verify-docs: FAILED"
  exit 1
fi

echo "verify-docs: OK (${#required_files[@]} files, ${#required_urls[@]} README URLs)"
