# Security

Dock Doctor observes kernel USB metadata as the logged-in user. The Omarchy shell
does not sandbox plugins, so install only source you trust.

## Boundaries

- No network requests, sockets, root operations, system services, package installation,
  device authorization, bus resets, driver detachment, or hardware writes.
- Python is launched by absolute path with isolated imports and a fixed environment.
  The bundled observer imports only its own package and the standard library.
- The optional udev monitor has a fixed absolute executable and fixed arguments.
  Device strings never become commands. Normal shutdown reaps the event monitor.
  A Linux parent-death signal also terminates it if Quickshell forcibly kills the observer.
- Scan cardinality, per-attribute reads, metadata length, command input, persisted
  file sizes, and retained event count are bounded.
- All device and error text is rendered as plain text, including device tooltips.
- Stored files must be user-owned single-link regular files without shared writes.
  Symlinks, FIFOs, oversized inputs, unsafe parents, and ownership mismatches fail closed.
- Directory descriptors are pinned and checked through writes. Private 0600 temporary
  files are created exclusively in the checked directory, synced, atomically renamed,
  and checked again. Destination links are never followed.
- Baseline, recording, and clear-history failures restore prior in-memory state.
  Corrupt retained state is not silently replaced. History write failures remain visible.
- A checked lock serializes observers. No credentials are required or stored.
- Export strips explicit serial and identity-key fields. User/device supplied names
  may contain identifying text; reports always require human review before sharing.

The checked-files helper and its regression tests originate in Babyface Control's
path-safety remediation, reviewed and merged as
`3ee5f14a5e919a93d470deee004a20071516fa54`.

## Limits

This is not a security monitor and cannot detect every physical failure. It cannot
provide protection against another process that already controls the same user
account or modifies trusted plugin code. Linux may omit hardware attributes.
No complete-event-history or hardware-health guarantee is made.

Please report suspected vulnerabilities using this repository's private security
reporting feature when available. Do not publish personal reports or exploit details
in an ordinary issue.
