#!/usr/bin/env python3
"""Build and stage a DMS plugin package."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REVISION_RE = re.compile(r"^[0-9a-f]{7,64}(?:-dirty)?$")
SOURCE_RE = re.compile(r"^source-[0-9a-f]{64}$")
BASE_RE = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
def package_config() -> dict:
    config = json.loads((ROOT / "packaging.json").read_text(encoding="utf-8"))
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]*", config.get("pluginDirectory", "")):
        raise ValueError("invalid pluginDirectory in packaging.json")
    if config.get("helper") and not re.fullmatch(r"[a-z][a-z0-9-]*", config["helper"]):
        raise ValueError("invalid helper in packaging.json")
    return config


def build_version(base: str, revision: str, release: bool = False) -> str:
    """Return the version stamped into both the manifest and helper."""
    if not BASE_RE.fullmatch(base):
        raise ValueError("base version must be X.Y.Z without leading zeroes")
    validate_revision(revision)
    if release:
        if not re.fullmatch(r"[0-9a-f]{7,64}", revision):
            raise ValueError("release builds require a clean hexadecimal revision")
        return base
    if revision == "unknown":
        return f"{base}-dev.unknown"
    if revision.startswith("source-"):
        return f"{base}-dev.source.{revision[7:19]}"
    dirty = revision.endswith("-dirty")
    commit = revision[:-6] if dirty else revision
    result = f"{base}-dev.{commit[:12]}"
    return result + (".dirty" if dirty else "")


def _run(args: list[str], *, cwd: Path | None = None) -> str:
    return subprocess.check_output(args, cwd=ROOT if cwd is None else cwd, text=True, stderr=subprocess.PIPE, timeout=10).rstrip("\n")


def git_revision() -> str:
    try:
        top = Path(_run(["git", "rev-parse", "--show-toplevel"])).resolve()
        if top != ROOT.resolve():
            return "unknown"
        revision = _run(["git", "rev-parse", "HEAD"])
        status = _run(["git", "status", "--porcelain", "--untracked-files=all"])
    except (OSError, subprocess.CalledProcessError):
        return "unknown"
    return revision + ("-dirty" if status else "")


def validate_revision(revision: str) -> None:
    if revision == "unknown" or SOURCE_RE.fullmatch(revision) or REVISION_RE.fullmatch(revision):
        return
    raise ValueError("revision must be 7-64 lowercase hex characters, optionally followed by -dirty, source-<64 hex>, or unknown")


def exact_release_tag(base: str) -> str:
    if Path(_run(["git", "rev-parse", "--show-toplevel"])).resolve() != ROOT.resolve():
        raise ValueError("release builds require the plugin's own Git checkout")
    expected = f"v{base}"
    revision = _run(["git", "rev-parse", "HEAD"])
    status = _run(["git", "status", "--porcelain", "--untracked-files=all"])
    if status:
        raise ValueError("release builds require a clean Git tree")
    try:
        tagged_revision = _run(["git", "rev-parse", f"refs/tags/{expected}^{{commit}}"])
    except subprocess.CalledProcessError:
        raise ValueError(f"release build requires exact tag {expected}") from None
    if tagged_revision != revision:
        raise ValueError(f"release build requires exact tag {expected}")
    return revision


def _load_manifest() -> tuple[dict, str]:
    path = ROOT / "plugin.json"
    raw = path.read_text(encoding="utf-8")
    manifest = json.loads(raw)
    base = manifest.get("version")
    if not isinstance(base, str) or not BASE_RE.fullmatch(base):
        raise ValueError("plugin.json version must be X.Y.Z")
    return manifest, base


def stage(output: Path, manifest: dict, version: str) -> None:
    destination = output / "share" / "dms-plugins" / package_config()["pluginDirectory"]
    destination.mkdir(parents=True, exist_ok=True)
    stamped = dict(manifest)
    stamped["version"] = version
    (destination / "plugin.json").write_text(json.dumps(stamped, indent=2) + "\n", encoding="utf-8")
    for pattern in ("*.qml", "*.js", "*.svg", "*.png"):
        for source in ROOT.glob(pattern):
            shutil.copy2(source, destination / source.name)
    for field in ("component", "settings"):
        if field not in manifest:
            continue
        relative = Path(manifest[field].split("?", 1)[0])
        if relative.is_absolute() or ".." in relative.parts or not (destination / relative).is_file():
            raise ValueError(f"missing or invalid packaged {field}")
    assets = ROOT / "assets"
    if assets.is_dir():
        shutil.copytree(assets, destination / "assets", dirs_exist_ok=True)
    for name in ("README.md", "LICENSE"):
        source = ROOT / name
        if source.is_file():
            shutil.copy2(source, destination / name)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--revision")
    parser.add_argument("--release", action="store_true")
    parser.add_argument("--stage-only", action="store_true")
    args = parser.parse_args(argv)
    try:
        manifest, base = _load_manifest()
        config = package_config()
        revision = args.revision if args.revision is not None else git_revision()
        validate_revision(revision)
        if args.release:
            if args.stage_only:
                if args.revision is None or not re.fullmatch(r"[0-9a-f]{7,64}", revision):
                    raise ValueError("stage-only release builds require an explicit clean hexadecimal revision")
            else:
                revision = exact_release_tag(base)
        version = build_version(base, revision, args.release)
        output = args.output.resolve()
        if not args.stage_only and output.exists() and any(output.iterdir()):
            raise ValueError("manual build output must be new or empty")
        output.mkdir(parents=True, exist_ok=True)
        if not args.stage_only and config.get("helper"):
            binary = output / "bin" / config["helper"]
            binary.parent.mkdir(parents=True, exist_ok=True)
            flags = f"-X main.version={version}"
            if config.get("revisionVariable", False):
                flags += f" -X main.revision={revision}"
            subprocess.run(["go", "build", "-ldflags", flags, "-o", str(binary), "./cmd/" + config["helper"]], cwd=ROOT, check=True)
        stage(output, manifest, version)
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print(f"package.py: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
