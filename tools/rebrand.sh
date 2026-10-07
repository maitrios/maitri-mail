#!/bin/bash

# Rebrand an upstream omamail tree into maitri-mail. Idempotent and deterministic:
# the same input tree always yields the same output, and running it twice is a
# no-op. tools/sync-upstream.sh runs it after every upstream merge; run
# `tools/rebrand.sh --check` before committing to catch anything that slipped in.
#
#   tools/rebrand.sh [--all]        delete upstream-only files, rename paths, rewrite contents, pin the backend
#   tools/rebrand.sh --no-delete    rename + rewrite only
#   tools/rebrand.sh --paths F...   rewrite contents of the given files only (after a hand merge)
#   tools/rebrand.sh --check        exit 1 and list offenders if any unprotected brand token remains

set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

# A line that mentions omamail or Omarchy on purpose (credit, an upstream
# command name) carries the marker `rebrand:keep` -- as an HTML comment in
# markdown, a `#` comment in shell or YAML -- and is left alone.
#
# Upstream identifiers that must survive the rename: attribution, the upstream
# repos, and hosts maitri does not own. Anything else spelled "omamail" or
# "omarchy" is ours to rename.
PROTECTED_TOKENS=(
  'huacnlee/omamail'
  'huacnlee.github.io/omamail'
  'github.com/basecamp/omarchy'
  'omacom/omarchy'
  'omarchy.org'
  # A JMAP test fixture whose byte size ui/tests/test_jmap.js asserts.
  'logo@omamail-test'
  # Keyring identifiers. Kept as upstream wrote them so an omamail user's saved
  # sign-ins are found by maitri mail without a secret migration.
  '"service".into(), "omamail".into()'
  '("service", "omamail")'
  '"service", "omamail"'
  'attribute.service = omamail'
  'KEYRING_SERVICE = "omamail"'
  '"omarchy-gmail"'
  'org.omamail.credentials.v1'
  'omamail:v1:'
)

# Files whose contents are never rewritten.
CONTENT_EXCLUDE=(
  'tools/rebrand.sh'
  'tools/sync-upstream.sh'
  'LICENSE'
  'MAITRI.md'
  '.github/workflows/sync-upstream.yml'
)

# Upstream-only files maitri-mail does not ship. Applied on every sync so they
# do not resurrect. Globs are expanded against the index.
DELETE_LIST=(
  # Upstream CI, Pages, funding and maintainer prompts. maitri-mail keeps its
  # own workflows on main.
  '.github'
  '.agents'
  '.codex'
  # curl-to-shell installers and the Pages site.
  'install.sh'
  'install.ps1'
  'docs/index.html'
  'tests/test_website_install.py'
  # The standalone Qt desktop app and its macOS, Windows and Linux archives.
  # maitri ships the shell plugin only.
  'app'
  'tests/test_app_make.py'
  # Upstream's GitHub release, backend download and binary pin machinery.
  # maitri-pkgs builds the backend from source and ships it in maitri-mail.
  'scripts/publish.sh'
  'scripts/publish-backend.sh'
  'scripts/release-source.sh'
  'scripts/release-notes.sh'
  'scripts/bump.sh'
  'scripts/install-backend.sh'
  'scripts/uninstall-backend.sh'
  'tests/test_publish.sh'
  'tests/test_publish_backend.py'
  'tests/test_release_source.sh'
  'tests/test_release_notes.sh'
  'tests/test_backend_release.py'
  'tests/test_runtime_release_contract.py'
  # The plugin ships first-party inside maitri, so there is no third-party
  # checkout to link into ~/.config.
  'scripts/link-plugin.sh'
  'tests/test_link_plugin.sh'
  'tests/test_plugin_workflow.py'
)

# Why: omamail tags a release before its pin commit, so the tag still pins the
# previous backend. maitri builds plugin and backend from the same tag, so apply
# that commit here (as scripts/package-backend.py pin does upstream).
pin_backend() {
  python3 - <<'PIN'
import json, tomllib
from pathlib import Path

version = tomllib.loads(Path("Cargo.toml").read_text())["package"]["version"]
Path("backend-version").write_text(version + "\n")
contract = json.loads(Path("backend-api.json").read_text())
contract["releasedApiVersion"] = contract["apiVersion"]
contract["unreleased"] = {"methods": [], "cases": []}
Path("backend-api.json").write_text(json.dumps(contract, indent=2) + "\n")
PIN
  git add -- backend-version backend-api.json
}

mode=all
paths=()
while (( $# )); do
  case "$1" in
    --all) mode=all ;;
    --no-delete) mode=no-delete ;;
    --check) mode=check ;;
    --paths) mode=paths; shift; paths=("$@"); break ;;
    -h|--help) sed -n '3,11p' "$0"; exit 0 ;;
    *) echo "rebrand.sh: unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

# Perl program shared by the path rename, the rewrite and the check: protect
# upstream tokens, rewrite, restore. Order matters: the specific rules run
# before the generic `omamail` -> `maitri-mail` fallback.
#
#   plugin id contexts          omamail       -> maitri.mail
#   Rust crate paths and fns    omamail::     -> maitri_mail::, omamail(  -> maitri_mail(
#   snake_case identifiers      x_omamail_y   -> x_maitri_mail_y
#   camelCase identifiers       omamailX      -> maitriMailX
#   env vars                    OMAMAIL_      -> MAITRI_MAIL_
#   QML namespaces and types    Omamail.X     -> MaitriMail.X, OmamailX -> MaitriMailX
#   display name                Omamail       -> Mail ("maitri mail" in markdown prose)
#   everything else             omamail       -> maitri-mail
#   articles                    an Omarchy    -> a maitri, an Omamail -> a Mail
#   Omarchy                     Omarchy 4     -> maitri, `omarchy shell shell` -> `maitri-shell shell`,
#                               OMARCHY/Omarchy/omarchy -> MAITRI/maitri/maitri
PERL_REWRITE='
  BEGIN { @p = grep { length } split /\n/, $ENV{REBRAND_PROTECT}; $md = $ENV{REBRAND_MARKDOWN}; }
  unless (/rebrand:keep/) {
    s{https://github\.com/omacom/omarchy/blob/quattro/docs/omarchy-shell\.md}{https://github.com/maitrios/maitri/blob/main/docs/maitri-shell.md}g;
    s{https://github\.com/omacom/omarchy/blob/quattro/manual/32-shell-plugins\.md#adding-a-plugin-from-git}{https://github.com/maitrios/maitri/blob/main/docs/maitri-shell.md#installing-a-third-party-plugin}g;
    for my $i (0..$#p) { my $t = $p[$i]; s/\Q$t\E/\x01P${i}\x01/g; }
    s/((?:summon|toggle|hide|call|serviceFor)\(\s*)"omamail"/$1"maitri.mail"/g;
    s/(\bshell\s+(?:summon|toggle|hide|call)\s+)omamail\b/$1maitri.mail/g;
    s/(\bplugin\s+(?:add|enable|disable|update|remove)\s+)omamail\b/$1maitri.mail/g;
    s/(\bid"?\s*:\s*)"omamail"/$1"maitri.mail"/g;
    s/(\bid\s*[!=]==?\s*)"omamail"/$1"maitri.mail"/g;
    s/(\bupdatedId,\s*)"omamail"/$1"maitri.mail"/g;
    s/(manifest\.id\)\s*:\s*)"omamail"/$1"maitri.mail"/g;
    s/(\bmoduleName\s*:\s*)"omamail"/$1"maitri.mail"/g;
    s/(\bplugin_id=)(["\x27]?)omamail\b/$1$2maitri.mail/g;
    s/\b([Aa])n (Omarchy|Omamail)\b/$1 $2/g;
    s/\bomamail::/maitri_mail::/g;
    s/\bomamail(?=\()/maitri_mail/g;
    s/\bomamail_cache_records\b/maitri_mail_cache_records/g;
    s/(?<=[a-z0-9]_)omamail(?=_[a-z0-9])/maitri_mail/g;
    s/omamail(?=[A-Z])/maitriMail/g;
    s/OMAMAIL/MAITRI_MAIL/g;
    s{-//Omamail//}{-//maitri//}g;
    s/\bas Omamail\b/as MaitriMail/g;
    s/Omamail(?=[A-Z]|\.[A-Z])/MaitriMail/g;
    if ($md) { s/Omamail/maitri mail/g } else { s/Omamail/Mail/g }
    s/omamail/maitri-mail/g;
    s/\bOmarchy 4\b/maitri/g;
    s/\bomarchy shell shell\b/maitri-shell shell/g;
    s/OMARCHY/MAITRI/g;
    s/Omarchy/maitri/g;
    s/omarchy/maitri/g;
    for my $i (0..$#p) { my $t = $p[$i]; s/\x01P${i}\x01/$t/g; }
  }
'
export REBRAND_PROTECT REBRAND_MARKDOWN
REBRAND_PROTECT=$(printf '%s\n' "${PROTECTED_TOKENS[@]}")

brand_re='omamail|omarchy'

rename_path() {
  REBRAND_MARKDOWN= perl -pe "$PERL_REWRITE" <<<"$1"
}

is_excluded() {
  local f=$1 x
  for x in "${CONTENT_EXCLUDE[@]}"; do [[ $f == "$x" ]] && return 0; done
  return 1
}

is_text() {
  grep -Iq . "$1" 2>/dev/null
}

is_markdown() {
  [[ $1 == *.md ]]
}

rewrite_file() {
  local f=$1
  is_excluded "$f" && return 0
  [[ -f $f ]] || return 0
  is_text "$f" || return 0
  grep -q -i -E "$brand_re" "$f" || return 0
  if is_markdown "$f"; then
    REBRAND_MARKDOWN=1 perl -pi -e "$PERL_REWRITE" "$f"
  else
    REBRAND_MARKDOWN= perl -pi -e "$PERL_REWRITE" "$f"
  fi
}

delete_upstream_only() {
  local entry
  for entry in "${DELETE_LIST[@]}"; do
    git rm -rqf --ignore-unmatch -- "$entry" "$(rename_path "$entry")" 2>/dev/null || true
  done
}

rename_paths() {
  local old new dir
  # Deepest paths first so a file moves before its parent directory is emptied.
  while IFS= read -r old; do
    new=$(rename_path "$old")
    [[ $new == "$old" ]] && continue
    dir=$(dirname -- "$new")
    mkdir -p -- "$dir"
    git mv -k -- "$old" "$new"
  done < <(git ls-files | grep -i -E "$brand_re" | awk '{ print gsub("/","/") "\t" $0 }' | sort -rn | cut -f2-)
}

rewrite_all() {
  local f
  while IFS= read -r -d '' f; do
    rewrite_file "$f"
  done < <(git ls-files -z)
}

check() {
  local rc=0 f
  if git ls-files | grep -v -x -F -f <(printf '%s\n' "${CONTENT_EXCLUDE[@]}") | grep -qi -E "$brand_re"; then
    echo "rebrand: paths still carry the upstream brand:" >&2
    git ls-files | grep -v -x -F -f <(printf '%s\n' "${CONTENT_EXCLUDE[@]}") | grep -i -E "$brand_re" >&2
    rc=1
  fi
  while IFS= read -r -d '' f; do
    is_excluded "$f" && continue
    [[ -f $f ]] || continue
    is_text "$f" || continue
    grep -q -i -E "$brand_re" "$f" || continue
    if is_markdown "$f"; then
      export REBRAND_MARKDOWN=1
    else
      export REBRAND_MARKDOWN=
    fi
    if ! diff -q "$f" <(perl -pe "$PERL_REWRITE" "$f") >/dev/null; then
      echo "rebrand: unprotected brand token in $f" >&2
      rc=1
    fi
  done < <(git ls-files -z)
  (( rc == 0 )) && echo "rebrand: clean"
  return $rc
}

# --all deletes upstream-only paths, including the upstream .github/ that main
# replaces with its own workflows, and re-pins the backend. It only ever runs
# on the rebranded upstream tree.
if [[ $mode == "all" && $(git branch --show-current) != "upstream" ]]; then
  echo "rebrand.sh: --all rewrites an upstream tag tree; run it on the upstream branch (tools/sync-upstream.sh does)." >&2
  echo "rebrand.sh: on main use --paths <files> or --check." >&2
  exit 1
fi

case "$mode" in
  all)
    delete_upstream_only
    rename_paths
    rewrite_all
    pin_backend
    ;;
  no-delete)
    rename_paths
    rewrite_all
    ;;
  paths)
    for f in "${paths[@]}"; do rewrite_file "$f"; done
    ;;
  check)
    check
    ;;
esac
