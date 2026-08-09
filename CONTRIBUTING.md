# Contributing

This repository is primarily a **personal self-hosting lab journal** and a **public handbook** derived from that experience.

## How to contribute

- Prefer opening an issue for suggestions, corrections, or clarifications.
- Pull requests that fix broken links, typos, or factual errors are welcome.
- Large structural changes should be discussed first.

## Documentation conventions

- Canonical guidance lives under `docs/architecture/`, `docs/guides/`, and `docs/apps/`.
- Personal decisions and experiments belong in `docs/experiences/` as dated notes (`YYYY-MM-DD-short-slug.md`).
- Do not commit secrets, real inventory, or private hostnames.
- Mark procedures that have not been validated in this lab as **Planned**.

### Private inventory (gitignored)

Keep LAN/Tailscale addresses, private hostnames, and hardware fingerprints **only** in local companions matched by `docs/**/*.local.md` (for example `docs/inventory.local.md` and `docs/experiences/deployment-topology.local.md`).

In tracked docs, use angle-bracket placeholders such as `<home-lan-cidr>`, `<openproject-lan-ip>`, `<guest1-hostname>`, `<ts-home-node>`, and point readers to those local files. Do not paste RFC1918/Tailscale CGNAT host addresses, private hostnames, or exact GPU SKUs into public markdown.

`./scripts/verify-docs.sh` fails if tracked markdown reintroduces common private inventory patterns.

## Dual audience

Keep instructional docs clear for public readers. Put diary-style narrative in the experiences log, and update canonical docs when a decision becomes lasting policy.
