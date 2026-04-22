# ADR-001: Use busctl Instead of playerctl for MPRIS Control

**Status:** Accepted
**Date:** 2026-04-22
**Applies to:** `DankSpotify.qml`, `plugin.json`

## Context

The plugin used `playerctl` for all MPRIS media player control (play/pause, next, previous, metadata). However, `playerctl` is not installed on the system — it's not part of the NixOS system packages or user profile. Since Quickshell's `execDetached` silently fails when a command doesn't exist, all playback controls failed without any error feedback. Only the "Open ncspot" action (using `foot`) worked because it didn't depend on `playerctl`.

## Decision

Replace all `playerctl` usage with `busctl`, which is available system-wide as part of systemd. The plugin now:

1. Discovers the full MPRIS bus name by grepping `busctl --user list` for the configured player name (e.g. `org.mpris.MediaPlayer2.ncspot.instance2982660`).
2. Calls MPRIS methods directly via `busctl --user call`.
3. Reads metadata and playback status via `busctl --user get-property`.

## Alternatives Considered

- **Add playerctl to system packages**: Would work but adds an unnecessary dependency when busctl can do the same thing and is already present.
- **Use dbus-send**: Also available, but busctl has simpler output parsing and is the modern systemd tool for bus interaction.
- **Bundle playerctl in the plugin nix derivation**: Over-engineering for a problem that busctl solves natively.

## Consequences

- No external dependency beyond systemd's busctl (universally available on systemd-based NixOS).
- Bus name discovery adds a small overhead per refresh cycle, but the instance suffix changes between ncspot restarts so caching isn't safe anyway.
- The metadata parsing uses grep/sed on busctl's text output, which is slightly more fragile than playerctl's `--format` flag, but tested and working.
