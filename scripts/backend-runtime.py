#!/usr/bin/env python3
"""Report the packaged backend's state to the plugin.

maitri ships the backend in the maitri-mail package, so the plugin never
downloads, replaces or links an executable. This only checks that the packaged
binary answers with the exact version this plugin revision pins, and reports
the API revision the plugin requires, in the JSON shape ui/backend/Runtime.js
decodes.
"""
import contextlib
import json
import os
from pathlib import Path
import re
import selectors
import signal
import stat
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent.parent
# Installed by the maitri-mail package. MAITRI_MAIL_BIN overrides it for
# development only and must name an absolute executable.
BINARY = Path("/usr/bin/maitri-mail")
VERSION = re.compile(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?")
PACKAGED = "maitri installs the mail backend with the maitri-mail package. Run maitri update if it is missing or out of date."


class Refused(Exception):
    pass


def require(condition, message):
    if not condition:
        raise Refused(message)


def pin():
    with (ROOT / "backend-version").open("rb") as source:
        raw = source.read(258)
    text = raw.decode("ascii")
    version = text[:-1] if text.endswith("\n") else text
    require(len(raw) <= 256 and VERSION.fullmatch(version), "Invalid backend version pin.")
    return version


def api_pin():
    """The API the pinned binary speaks, the one this checkout implements, and
    the methods only the latter has. The handshake accepts the former; a call
    to one of the latter on the pinned binary is refused in the UI instead."""
    with (ROOT / "backend-api.json").open("rb") as source:
        raw = source.read(1024 * 1024 + 1)
    require(len(raw) <= 1024 * 1024, "Backend API contract is too large.")
    contract = json.loads(raw)
    require(isinstance(contract, dict), "Invalid backend API contract.")
    released = contract.get("releasedApiVersion")
    latest = contract.get("apiVersion")
    for value in (released, latest):
        require(type(value) is int and 0 < value <= 2147483647, "Invalid backend API version.")
    require(latest - released in (0, 1), "Invalid backend API version.")
    unreleased = contract.get("unreleased", {}).get("methods", []) if isinstance(contract.get("unreleased"), dict) else None
    require(isinstance(unreleased, list) and all(isinstance(m, str) for m in unreleased), "Invalid backend API contract.")
    return released, latest, unreleased


def safe_path(path):
    """Refuse symlink components, including dangling links."""
    for part in [*reversed(path.parents), path]:
        if part == Path(part.anchor):
            continue
        try:
            mode = part.lstat().st_mode
        except FileNotFoundError:
            continue
        require(not stat.S_ISLNK(mode), "Refusing a symbolic link in the backend path.")
        if part != path:
            require(stat.S_ISDIR(mode), "Backend directory is not a directory.")
        else:
            require(stat.S_ISREG(mode), "Backend executable is not a regular file.")


def version_of(executable):
    """Bound both the probe's time and its output; never surface child diagnostics."""
    if not executable.exists():
        return ""
    process = subprocess.Popen([str(executable), "--version"], stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL, start_new_session=True)
    output = bytearray()
    try:
        deadline = time.monotonic() + 5
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            while True:
                remaining = deadline - time.monotonic()
                require(remaining > 0, "Backend version check timed out.")
                require(selector.select(remaining), "Backend version check timed out.")
                chunk = os.read(process.stdout.fileno(), 257)
                if not chunk:
                    break
                output.extend(chunk)
                require(len(output) <= 256, "Invalid backend version response.")
        require(process.wait(timeout=max(0.01, deadline - time.monotonic())) == 0,
                "Backend version check failed.")
        match = re.fullmatch(rb"maitri-mail ([^\r\n ]+)\n?", bytes(output))
        require(match is not None, "Invalid backend version response.")
        version = match[1].decode("ascii")
        require(VERSION.fullmatch(version), "Invalid backend version response.")
        return version
    finally:
        with contextlib.suppress(ProcessLookupError):
            os.killpg(process.pid, signal.SIGKILL)
        process.wait()
        process.stdout.close()


def run(command):
    result = dict(state="error", requiredVersion="", requiredApiVersion=0, latestApiVersion=0, unreleasedMethods=[], installedVersion="", executable=str(BINARY), error="", cliInstalled=False)
    try:
        required = pin()
        result["requiredVersion"] = required
        result["requiredApiVersion"], result["latestApiVersion"], result["unreleasedMethods"] = api_pin()
        development = os.environ.get("MAITRI_MAIL_BIN", "")
        executable = Path(development) if development else BINARY
        result["executable"] = str(executable)
        require(command == "status", PACKAGED)
        if development:
            require(executable.is_absolute(), "MAITRI_MAIL_BIN must be an absolute executable path.")
        else:
            safe_path(executable)
        installed = version_of(executable)
        result["installedVersion"] = installed
        result["state"] = "missing" if not installed else "ready" if installed == required else "mismatch"
        if result["state"] != "ready" and not development:
            result["error"] = PACKAGED
    except Refused as error:
        result["state"] = "error"
        result["error"] = str(error)
    except Exception:
        result["state"] = "error"
        result["error"] = "Backend check failed. Check the maitri-mail package and its permissions."
    return result


if __name__ == "__main__":
    result = run(sys.argv[1] if len(sys.argv) == 2 else "")
    print(json.dumps(result))
    sys.exit(1 if result["state"] == "error" else 0)
