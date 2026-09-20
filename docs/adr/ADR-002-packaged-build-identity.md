# ADR-002: Packaged Build Identity

## Status

Accepted

## Decision

Keep the tracked `plugin.json` version as the release source of truth. The
packaging script stages a copy with a development identity such as
`X.Y.Z-dev.<commit>` (and `.dirty` when applicable). Nix and manual
packages use the same rules; release packaging requires the exact clean
`vX.Y.Z` tag.

This keeps development installs identifiable without changing release
versioning or the plugin source tree.
