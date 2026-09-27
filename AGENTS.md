# Agent instructions for DankSpotify

This public repository is the standalone source for this DMS plugin. Keep
private infrastructure, credentials, and operational notes out of it.

- GitHub `origin` is canonical for branches, issues, CI, and releases. Make
  changes on `dev`; promote to protected `main` through a GitHub pull request.
- Read [the ADR index](docs/adr/README.md) and relevant accepted decisions
  before lasting design changes. Add an ADR only for a real new decision.
- Keep `plugin.json` metadata and its `X.Y.Z` version valid. For each feature
  or fix, add a user-facing sentence under `CHANGELOG.md` `[Unreleased]`.
- Release in one commit: bump `plugin.json`, date the corresponding changelog
  section, and add a fresh empty `[Unreleased]`. Release tags are `vX.Y.Z`
  from `main`; do not move published tags.
- Run `bash test.sh` for code changes. CI also validates the manifest,
  changelog, and release contract.
- Keep `.github/workflows/ci.yml` aligned with the
  [shared CI template](https://github.com/alcxyz/dms-plugins/blob/main/templates/github/workflows/plugin-ci.yml).
  Keep packaging/build identity copies aligned with the
  [shared build templates](https://github.com/alcxyz/dms-plugins/tree/main/templates/build-identity).
- The [aggregate plugin rules](https://github.com/alcxyz/dms-plugins/blob/main/AGENTS.md)
  and [accepted aggregate ADRs](https://github.com/alcxyz/dms-plugins/blob/main/docs/adr/README.md)
  explain the release, workflow, and packaging contracts in detail.
- Use the configured user Git identity for author and committer; include no AI
  or tool attribution in commits, tags, or pull request descriptions.
