#!/bin/bash
# maitri-mail's own invariants: the rebrand holds, the plugin is maitri's
# first-party maitri.mail, versions agree, the backend comes from the package,
# dropped upstream files stay dropped, and tools/install.sh stages the layout
# maitri-pkgs ships.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

fail() { printf 'test_maitri.sh: %s\n' "$1" >&2; exit 1; }

tools/rebrand.sh --check >/dev/null || fail "upstream brand leaked; run tools/rebrand.sh --check"

python3 - <<'EOF' || fail "manifest or version metadata is wrong"
import json, re, sys, tomllib
from pathlib import Path

manifest = json.loads(Path("manifest.json").read_text())
assert manifest["schemaVersion"] == 1
assert manifest["id"] == "maitri.mail", manifest["id"]
assert set(manifest["kinds"]) == {"service", "bar-widget", "panel"}, manifest["kinds"]
for kind, entry in manifest["entryPoints"].items():
    assert Path(entry).is_file() and not entry.startswith(("/", "..")), entry
assert manifest["barWidget"]["defaultSection"] in ("left", "center", "right")

cargo = tomllib.loads(Path("Cargo.toml").read_text())["package"]
assert cargo["name"] == "maitri-mail", cargo["name"]
lock = [p for p in tomllib.loads(Path("Cargo.lock").read_text())["package"] if p["name"] == "maitri-mail"]
assert len(lock) == 1 and lock[0]["version"] == cargo["version"], lock
pin = Path("backend-version").read_text().strip()
if not (cargo["version"] == manifest["version"] == pin):
    sys.exit(f"Cargo {cargo['version']}, manifest {manifest['version']} and backend-version {pin} disagree")
EOF

grep -q '^BINARY = Path("/usr/bin/maitri-mail")$' scripts/backend-runtime.py \
  || fail "the plugin must run the packaged /usr/bin/maitri-mail"
if grep -rn -E 'releases/download|install-backend|enable-cli' ui scripts --include='*.qml' --include='*.js' --include='*.py' --include='*.sh' \
    | grep -v -E '^ui/tests/|^ui/backend/Runtime\.(qml|js):'; then
  fail "the plugin must not download, install or link a backend"
fi

# The heart seal replaces upstream's M everywhere the mark is drawn. A sync that
# resolves a conflict toward upstream's side brings the M back.
grep -q 'd="M10 19L32 35L54 19"' ui/assets/maitri-mail.svg && grep -q 'class="accent"' ui/assets/maitri-mail.svg \
  && grep -q 'd="M10 19L32 35L54 19"' docs/images/maitri-mail.svg \
  || fail "the mark assets must draw the V fold and heart seal"
grep -q 'bezierCurveTo' ui/components/GmailIcon.qml && ! grep -q 'innerW \* 0.30' ui/components/GmailIcon.qml \
  || fail "the bar glyph must draw the heart seal, not the M"
grep -qF '[[10, 19], [32, 35], [54, 19]]' ui/components/MaitriMailLogo.qml \
  || fail "the animated logo must trace the V fold"

for dropped in app install.sh install.ps1 docs/index.html scripts/link-plugin.sh scripts/publish.sh \
    scripts/install-backend.sh .github/workflows/pages.yml .github/workflows/native-credentials.yml; do
  [[ ! -e $dropped ]] || fail "$dropped is on maitri-mail's delete list but came back"
done

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin"
printf '#!/bin/sh\nprintf "maitri-mail 0.0.0\\n"\n' > "$tmp/bin/maitri-mail"
chmod 755 "$tmp/bin/maitri-mail"
tools/install.sh --destdir "$tmp/pkg" --binary "$tmp/bin/maitri-mail"

plugin="$tmp/pkg/usr/share/maitri/shell/plugins/mail"
[[ -x $tmp/pkg/usr/bin/maitri-mail ]] || fail "install.sh must place the backend at /usr/bin/maitri-mail"
[[ -f $tmp/pkg/usr/share/licenses/maitri-mail/LICENSE ]] || fail "install.sh must install the license"
for f in manifest.json backend-version backend-api.json ui/Service.qml ui/BarWidget.qml ui/App.qml scripts/backend-runtime.py; do
  [[ -f $plugin/$f ]] || fail "install.sh must stage $f"
done
[[ ! -e $plugin/ui/tests ]] || fail "install.sh must not ship ui/tests"
[[ -x $plugin/scripts/mailto.sh && -x $plugin/scripts/default-mail.sh ]] || fail "plugin scripts must stay executable"
[[ ! -x $plugin/manifest.json ]] || fail "plugin data files must not be executable"
# maitri's PluginRegistry treats any manifest.json or *.manifest.json up to three
# levels below shell/plugins as another first-party plugin.
extra=$(cd "$tmp/pkg/usr/share/maitri/shell/plugins" && find . -mindepth 2 -maxdepth 3 -type f \( -name manifest.json -o -name '*.manifest.json' \) ! -path ./mail/manifest.json)
[[ -z $extra ]] || fail "the staged plugin carries extra manifests the shell would load: $extra"

python3 tests/test_maitri_shell_api.py

printf 'test_maitri.sh ok\n'
