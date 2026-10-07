#!/usr/bin/env python3
"""The packaged-backend status probe; never touches the installed system binary."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "scripts/backend-runtime.py"


class PackagedRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        base = Path(self.tmp.name).resolve()
        self.root = base / "plugin"
        (self.root / "scripts").mkdir(parents=True)
        target = self.root / "scripts/backend-runtime.py"
        shutil.copyfile(SOURCE, target)
        spec = importlib.util.spec_from_file_location("runtime_manager", target)
        self.manager = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.manager)
        (self.root / "backend-version").write_text("0.8.2\n")
        (self.root / "backend-api.json").write_text(
            '{"apiVersion": 2, "releasedApiVersion": 1, "unreleased": {"methods": ["message.new"], "cases": []}}')
        self.binary = base / "usr/bin/maitri-mail"
        patch.object(self.manager, "BINARY", self.binary).start()
        self.addCleanup(patch.stopall)
        patch.dict(os.environ, {}, clear=True).start()

    def executable(self, version, path=None):
        path = path or self.binary
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"#!/bin/sh\nprintf 'maitri-mail {version}\\n'\n")
        path.chmod(0o755)
        return path

    def test_default_binary_is_the_packaged_one(self):
        spec = importlib.util.spec_from_file_location("fresh_runtime_manager", SOURCE)
        manager = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(manager)
        self.assertEqual(manager.BINARY, Path("/usr/bin/maitri-mail"))

    def test_ready_when_the_package_matches_the_pin(self):
        self.executable("0.8.2")
        result = self.manager.run("status")
        self.assertEqual(result["state"], "ready", result)
        self.assertEqual(result["executable"], str(self.binary))
        self.assertEqual(result["installedVersion"], "0.8.2")
        self.assertEqual(result["requiredApiVersion"], 1)
        self.assertEqual(result["latestApiVersion"], 2)
        self.assertEqual(result["unreleasedMethods"], ["message.new"])
        self.assertEqual(result["error"], "")
        self.assertFalse(result["cliInstalled"])

    def test_missing_and_mismatched_point_at_the_package(self):
        result = self.manager.run("status")
        self.assertEqual(result["state"], "missing")
        self.assertIn("maitri-mail package", result["error"])
        self.executable("0.8.1")
        result = self.manager.run("status")
        self.assertEqual(result["state"], "mismatch")
        self.assertEqual(result["installedVersion"], "0.8.1")
        self.assertIn("maitri update", result["error"])

    def test_install_and_cli_operations_are_refused_without_side_effects(self):
        for command in ("install", "install-local", "uninstall", "enable-cli", "disable-cli", ""):
            before = sorted(Path(self.tmp.name).rglob("*"))
            result = self.manager.run(command)
            self.assertEqual(result["state"], "error", command)
            self.assertIn("maitri-mail package", result["error"], command)
            self.assertEqual(sorted(Path(self.tmp.name).rglob("*")), before, command)

    def test_a_symlinked_backend_is_refused(self):
        real = self.executable("0.8.2", Path(self.tmp.name) / "elsewhere/maitri-mail")
        self.binary.parent.mkdir(parents=True)
        self.binary.symlink_to(real)
        result = self.manager.run("status")
        self.assertEqual(result["state"], "error")
        self.assertIn("symbolic link", result["error"])

    def test_development_override_must_be_absolute(self):
        dev = self.executable("0.8.2", Path(self.tmp.name) / "dev/maitri-mail")
        with patch.dict(os.environ, {"MAITRI_MAIL_BIN": str(dev)}):
            result = self.manager.run("status")
        self.assertEqual(result["state"], "ready", result)
        self.assertEqual(result["executable"], str(dev))
        with patch.dict(os.environ, {"MAITRI_MAIL_BIN": "relative/maitri-mail"}):
            self.assertEqual(self.manager.run("status")["state"], "error")

    def test_the_probe_never_reaches_the_network(self):
        source = SOURCE.read_text()
        for forbidden in ("urllib", "http.client", "socket", "github.com", "releases/download"):
            self.assertNotIn(forbidden, source)

    def test_cli_prints_one_json_line(self):
        self.executable("0.8.2")
        env = dict(os.environ, MAITRI_MAIL_BIN=str(self.binary))
        completed = subprocess.run([sys.executable, str(self.root / "scripts/backend-runtime.py"), "status"],
                                   env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(json.loads(completed.stdout)["state"], "ready")
        completed = subprocess.run([sys.executable, str(self.root / "scripts/backend-runtime.py"), "install"],
                                   env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(completed.returncode, 1)


if __name__ == "__main__":
    unittest.main()
