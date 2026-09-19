import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("package", ROOT / "scripts" / "package.py")
package = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(package)


class PackageVersionTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("nix-instantiate"), "Nix unavailable")
    def test_nix_and_manual_version_rules_agree(self):
        for revision, release in [
            ("abcdef1234567", False), ("abcdef1234567-dirty", False),
            ("source-" + "a" * 64, False), ("unknown", False),
            ("abcdef1234567", True),
        ]:
            expression = 'import ' + str(ROOT / "build-version.nix") + ' { version = "1.0.0"; revision = '
            expression += json.dumps(revision) + '; release = ' + str(release).lower() + '; }'
            actual = subprocess.check_output(
                ["nix-instantiate", "--eval", "--strict", "--json", "--expr", expression],
                text=True, timeout=20,
            )
            self.assertEqual(json.loads(actual), package.build_version("1.0.0", revision, release))

    def test_dev_versions(self):
        self.assertEqual(package.build_version("1.0.0", "abcdef1234567"), "1.0.0-dev.abcdef123456")
        self.assertEqual(package.build_version("1.0.0", "abcdef1234567-dirty"), "1.0.0-dev.abcdef123456.dirty")
        self.assertEqual(package.build_version("1.0.0", "source-" + "a" * 64), "1.0.0-dev.source.aaaaaaaaaaaa")
        self.assertEqual(package.build_version("1.0.0", "unknown"), "1.0.0-dev.unknown")
        self.assertEqual(package.build_version("1.0.0", "abcdef1234567", release=True), "1.0.0")

    def test_revision_validation(self):
        for value in ("abcdef1", "a" * 64, "abcdef1-dirty", "source-" + "b" * 64, "unknown"):
            package.validate_revision(value)
        for value in ("ABCDEF1", "abcdef", "a" * 65, "source-" + "a" * 63, "dirty"):
            with self.assertRaises(ValueError):
                package.validate_revision(value)

    def test_base_version_validation(self):
        with self.assertRaises(ValueError):
            package.build_version("01.0.0", "abcdef1")
        with self.assertRaises(ValueError):
            package.build_version("1.0.0", "abcdef1-dirty", release=True)


class PackageFixtureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.repo = Path(self.temp.name)
        self.git_env = os.environ.copy()
        self.git_env.update({
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_EDITOR": "true",
            "GIT_TERMINAL_PROMPT": "0",
        })
        self.old_env = {key: os.environ.get(key) for key in self.git_env if key.startswith("GIT_")}
        os.environ.update({key: value for key, value in self.git_env.items() if key.startswith("GIT_")})
        for name in ("Widget.qml", "Settings.qml", "Extra.qml"):
            (self.repo / name).write_text("import QtQuick\n", encoding="utf-8")
        (self.repo / "assets").mkdir()
        (self.repo / "assets" / "logo.svg").write_text("<svg/>", encoding="utf-8")
        (self.repo / "README.md").write_text("readme", encoding="utf-8")
        (self.repo / "LICENSE").write_text("license", encoding="utf-8")
        (self.repo / ".gitignore").write_text("dist/\n", encoding="utf-8")
        (self.repo / "plugin.json").write_text(json.dumps({"id": "test", "version": "1.0.0", "component": "./Widget.qml?rev=test", "settings": "./Settings.qml"}), encoding="utf-8")
        (self.repo / "packaging.json").write_text(json.dumps({"pluginDirectory": "TestPlugin"}), encoding="utf-8")
        self.git(["init", "-q"])
        self.git(["config", "user.email", "test@example.invalid"])
        self.git(["config", "user.name", "Test"])
        self.git(["config", "core.hooksPath", "/dev/null"])
        self.git(["add", "."])
        self.git(["commit", "-qm", "initial"])

    def git(self, args):
        return subprocess.run(["git", *args], cwd=self.repo, env=self.git_env, check=True, timeout=10)

    def tearDown(self):
        for key, value in self.old_env.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        self.temp.cleanup()

    def test_fixture_clean_dirty_and_dist(self):
        old_root = package.ROOT
        package.ROOT = self.repo
        try:
            clean = package.git_revision()
            self.assertRegex(clean, r"^[0-9a-f]{40}$")
            (self.repo / "local.txt").write_text("change", encoding="utf-8")
            self.assertTrue(package.git_revision().endswith("-dirty"))
            (self.repo / "local.txt").unlink()
            (self.repo / "dist").mkdir()
            (self.repo / "dist" / "artifact").write_text("ignored for identity", encoding="utf-8")
            self.assertFalse(package.git_revision().endswith("-dirty"))
        finally:
            package.ROOT = old_root

    def test_release_requires_exact_tag(self):
        old_root = package.ROOT
        package.ROOT = self.repo
        try:
            with self.assertRaises(ValueError):
                package.exact_release_tag("1.0.0")
            self.git(["-c", "tag.gpgSign=false", "tag", "v1.0.0"])
            revision = package.exact_release_tag("1.0.0")
            self.assertRegex(revision, r"^[0-9a-f]{40}$")
            (self.repo / "changed").write_text("dirty", encoding="utf-8")
            with self.assertRaises(ValueError):
                package.exact_release_tag("1.0.0")
        finally:
            package.ROOT = old_root

    def test_stage_only_stamps_without_changing_source(self):
        old_root = package.ROOT
        package.ROOT = self.repo
        try:
            manifest, base = package._load_manifest()
            output = self.repo / "out"
            package.stage(output, manifest, package.build_version(base, "abcdef1234567"))
            stamped = json.loads((output / "share/dms-plugins/TestPlugin/plugin.json").read_text())
            self.assertEqual(stamped["version"], "1.0.0-dev.abcdef123456")
            self.assertEqual(json.loads((self.repo / "plugin.json").read_text())["version"], "1.0.0")
        finally:
            package.ROOT = old_root

    def test_parent_repository_does_not_identify_a_source_archive(self):
        old_root = package.ROOT
        archive = self.repo / "archive"
        archive.mkdir()
        package.ROOT = archive
        try:
            self.assertEqual(package.git_revision(), "unknown")
            with self.assertRaises(ValueError):
                package.exact_release_tag("1.0.0")
        finally:
            package.ROOT = old_root

    def test_manual_output_cannot_overwrite_existing_files(self):
        old_root = package.ROOT
        package.ROOT = self.repo
        output = self.repo / "dist"
        output.mkdir()
        sentinel = output / "keep"
        sentinel.write_text("keep this")
        try:
            self.assertEqual(package.main(["--output", str(output)]), 2)
            self.assertEqual(sentinel.read_text(), "keep this")
        finally:
            package.ROOT = old_root

    @unittest.skipUnless(shutil.which("go"), "Go unavailable")
    def test_release_package_helper_and_manifest_match(self):
        (self.repo / "go.mod").write_text("module example.invalid/package-test\n\ngo 1.22\n")
        command = self.repo / "cmd" / "dankaiusage"
        command.mkdir(parents=True)
        (command / "main.go").write_text(
            'package main\nimport "fmt"\nvar version = "dev"\nvar revision string\n'
            'func main() { fmt.Println(version) }\n'
        )
        (self.repo / "packaging.json").write_text(json.dumps({"pluginDirectory": "TestPlugin", "helper": "dankaiusage"}), encoding="utf-8")
        self.git(["add", "."])
        self.git(["commit", "-qm", "helper"])
        self.git(["tag", "v1.0.0"])
        self.git(["tag", "another-tag"])
        old_root = package.ROOT
        package.ROOT = self.repo
        try:
            output = self.repo / "dist" / "release"
            self.assertEqual(package.main(["--release", "--output", str(output)]), 0)
            actual = subprocess.check_output([str(output / "bin" / "dankaiusage"), "version"], text=True).strip()
            manifest = json.loads((output / "share/dms-plugins/TestPlugin/plugin.json").read_text())
            self.assertEqual(actual, "1.0.0")
            self.assertEqual(manifest["version"], actual)
            self.assertFalse(package.git_revision().endswith("-dirty"))
        finally:
            package.ROOT = old_root


if __name__ == "__main__":
    unittest.main()
