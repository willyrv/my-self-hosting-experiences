# Deployment topology diagrams Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a public Mermaid deployment topology (no IPs/networks) linked from the experiences README, plus a gitignored private Mermaid file with full addressing.

**Architecture:** Two Markdown companions under `docs/experiences/`. Public file describes hosts, services, and exposure; private file mirrors structure with LAN/Tailscale/CIDR details. `.gitignore` excludes the private file.

**Tech Stack:** Markdown, Mermaid, gitignore

## Global Constraints

- Public diagram must not contain LAN IPs, Tailscale IPs, CIDRs, or public VPS IPv4 literals.
- Private file path must be exactly `docs/experiences/deployment-topology.local.md` and listed in `.gitignore`.
- n8n host is teaching GPU host A by inference from the design spec; label it as inferred.
- Do not invent an n8n FQDN; handbook uses `n8n.example.net` placeholder — public diagram says “n8n (Access-protected hostname)” without a real FQDN.
- Do not commit unless the user asks.

---

### Task 1: Public topology + gitignore + README link

**Files:**
- Create: `docs/experiences/deployment-topology.md`
- Create: `docs/experiences/deployment-topology.local.md`
- Modify: `.gitignore`
- Modify: `docs/experiences/README.md`

**Interfaces:**
- Consumes: topology table from `docs/superpowers/specs/2026-08-04-deployment-topology-diagrams-design.md`
- Produces: public Mermaid page; private Mermaid page; README section “Deployment topology”

- [ ] **Step 1: Add gitignore entry**

Append to `.gitignore`:

```gitignore
# Local-only inventory (IPs / networks) — do not commit
docs/experiences/deployment-topology.local.md
```

- [ ] **Step 2: Write public Mermaid file**

Create `docs/experiences/deployment-topology.md` with:
- Short intro + security note (IPs omitted on purpose)
- Mermaid `flowchart` or `graph` grouping Internet / OVH VPS / Home LAN (CGNAT) / Separate LAN (teaching GPU host A)
- Services and exposure edges (Tunnel+Access, Nginx DNS-only, Headscale)
- No IP/CIDR literals

- [ ] **Step 3: Write private Mermaid file**

Create `docs/experiences/deployment-topology.local.md` with:
- Banner: do not commit / do not publish
- Same layout as public plus IPs/CIDRs from the design table
- Note teaching GPU host A not on advertised Headscale subnet

- [ ] **Step 4: Link from experiences README**

Add a “Deployment topology” section near the top of `docs/experiences/README.md` linking `deployment-topology.md` and mentioning the gitignored `.local.md` companion.

- [ ] **Step 5: Verify private file is ignored**

Run: `git check-ignore -v docs/experiences/deployment-topology.local.md`  
Expected: a matching `.gitignore` rule line.

Run: `git status --short docs/experiences/ .gitignore`  
Expected: public topology + README + gitignore tracked as changes; `.local.md` not listed as untracked.
