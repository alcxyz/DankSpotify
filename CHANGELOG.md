# Changelog

All notable changes to this plugin are documented here. The format follows
Keep a Changelog, and the release workflow publishes each version's section
as its GitHub release notes.

## [Unreleased]

## [0.2.2] - 2026-09-20

- Updated the README's plugin screenshot.
- Added a `scripts/package.py` build helper (with Nix `default.nix` support) that stages an identifiable development package, stamping builds with a version like `X.Y.Z-dev.<commit>` (or `.dirty` for a dirty checkout) so development installs are never mistaken for a tagged release. Release packaging still requires a clean checkout at the exact `vX.Y.Z` tag.

## [0.2.1] - 2026-05-03

- Added a test suite (`test.sh`, 16 tests) covering `plugin.json` validation, plugin ID consistency, MPRIS bus name parsing, metadata extraction, and playback status parsing, giving more confidence that playback control keeps working across changes.
- Removed the separate `VERSION` file; `plugin.json` is now the single source of truth for the plugin version, read by CI, the Nix flake, and `test.sh`. This eliminates a duplicate value that was easy to forget to update when bumping versions.
- Fixed the Nix install snippet in the README, which referenced the wrong plugin attribute name (`DankSpotify` instead of `dankSpotify`), so following the documented Nix installation instructions now actually works.
- Added a collapsible "Support" section to the README with cryptocurrency donation addresses.
- Documented the dev/main release workflow and the docs-only release exception in CONTRIBUTING.

## [0.2.0] - 2026-04-22

- Fixed playback controls that silently failed when `playerctl` was not installed. The plugin now talks to Spotify over MPRIS using `busctl` (systemd) to discover the bus name and invoke playback methods directly, removing the `playerctl` dependency entirely.
- Added `_preScored` to launcher items so results integrate correctly with the DMS Scorer.

## [0.1.0] - 2026-04-22

- Initial release: a Spotify launcher plugin for DankMaterialShell, providing playback control and track search via ncspot from the DMS launcher.
- Added packaging basics: CI workflow, README, LICENSE (MIT), and CONTRIBUTING guide.
