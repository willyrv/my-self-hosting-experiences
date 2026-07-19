# Phase 1 — Hardware and base operating system

Status: Planned

## Goal

Prepare predictable, recoverable hosts with documented roles, stable networking, secure administration, and healthy storage before adding cluster software.

## Checklist

- Install Debian 13 or Ubuntu Server LTS consistently across the hosts.
- Configure static DHCP leases and consistent hostnames.
- Configure SSH key authentication and automatic security updates.
- Apply a per-host firewall policy.
- Mount SSDs, data disks, and backup disks at stable paths.
- Enable SMART monitoring and time synchronization.
- Connect critical hosts to a UPS where possible.
- Record the hardware inventory and intended role of each machine.

## Details

Assign infrastructure, compute, and storage/media responsibilities before sizing or mounting disks. The infrastructure node needs reliable SSD storage and is the preferred home for ingress, certificates, DNS-related services, monitoring, and the later host-level VPN endpoint. The compute node should receive the most CPU and RAM. The storage/media node needs capacity for large disks and, where available, hardware suitable for Jellyfin transcoding.

Plan capacity around the heaviest expected workloads. GitLab, Jupyter user environments, OpenProject, Nextcloud extensions, and long monitoring retention can all be RAM intensive. If the lab has less than roughly 48 GB of aggregate RAM, plan for a lighter Git forge or an independently constrained GitLab host.

Keep host setup independent of Kubernetes. Stable mounts, SSH access, firewall rules, security updates, clock synchronization, disk-health reporting, and an inventory are recovery prerequisites, not cluster features. Record disk purpose and mount paths so later storage classes, backups, and node affinity refer to known hardware.

## Verify before next phase

- Every host keeps the expected address and hostname after a reboot.
- SSH key access works on the LAN and password-based remote access follows the chosen security policy.
- Host firewall rules permit required administration traffic without exposing unintended services.
- All planned disks remount at their documented paths after a reboot.
- SMART and filesystem health can be checked on every storage device.
- The inventory records CPU, RAM, disks, network addresses, and the intended role for each machine.

## See also

- [Machine roles](../architecture/machine-roles.md)
- [Resource planning](../architecture/resources.md)
- [Networking and exposure](../architecture/networking.md)

## Navigation

- Next: [Phase 2 — VPN access](phase-02-vpn-access.md)
