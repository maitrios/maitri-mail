#!/bin/bash

# Stage the packaged maitri-mail layout under a DESTDIR. maitri-pkgs runs this
# from package(); `make install DESTDIR=...` does the same.
#
#   tools/install.sh --destdir DIR [--binary PATH]
#
#   /usr/bin/maitri-mail                         backend + CLI (the plugin's fixed path)
#   /usr/share/maitri/shell/plugins/mail/        first-party shell plugin (id maitri.mail)
#   /usr/share/licenses/maitri-mail/LICENSE

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

destdir=""
binary="$ROOT/target/release/maitri-mail"
while (( $# )); do
  case "$1" in
    --destdir) destdir=${2:?--destdir needs a value}; shift ;;
    --binary) binary=${2:?--binary needs a value}; shift ;;
    -h|--help) sed -n '6,11p' "$0"; exit 0 ;;
    *) echo "install.sh: unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

[[ -n $destdir ]] || { echo "install.sh: --destdir is required" >&2; exit 2; }
[[ -x $binary ]] || { echo "install.sh: build the backend first: $binary" >&2; exit 1; }

plugin_dir="$destdir/usr/share/maitri/shell/plugins/mail"

# Development and release helpers that never run inside the installed plugin.
DEV_ONLY=(
  scripts/package-backend.py
  scripts/generate-provider-domain.py
)

is_dev_only() {
  local f=$1 x
  for x in "${DEV_ONLY[@]}"; do [[ $f == "$x" ]] && return 0; done
  return 1
}

install -Dm755 "$binary" "$destdir/usr/bin/maitri-mail"
install -Dm644 "$ROOT/LICENSE" "$destdir/usr/share/licenses/maitri-mail/LICENSE"

for f in manifest.json backend-version backend-api.json LICENSE; do
  install -Dm644 "$ROOT/$f" "$plugin_dir/$f"
done

while IFS= read -r -d '' path; do
  rel=${path#"$ROOT/"}
  is_dev_only "$rel" && continue
  if [[ -x $path ]]; then
    install -Dm755 "$path" "$plugin_dir/$rel"
  else
    install -Dm644 "$path" "$plugin_dir/$rel"
  fi
done < <(find "$ROOT/ui" "$ROOT/scripts" -path "$ROOT/ui/tests" -prune -o -type f \
  ! -name '*.pyc' ! -path '*/__pycache__/*' -print0 | sort -z)
