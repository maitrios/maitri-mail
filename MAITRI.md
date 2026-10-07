# maitri mail — Maintenance Guide

maitri mail is a rebranded fork of [omamail](https://github.com/huacnlee/omamail) by Jason Lee. It tracks omamail's releases the same way [maitri](https://github.com/maitrios/maitri) tracks Omarchy: an `upstream` branch holds a **rebranded** copy of each omamail release tag, and `main` is `upstream` plus maitri's deltas.

## Branches and remotes

| Ref | What it is |
|---|---|
| `main` | `upstream` merged in, plus the maitri deltas listed below. Release tags (`vX.Y.Z`) are cut here. |
| `upstream` | Each omamail release tag, merged with `-s ours`, its tree replaced by the tag's and passed through `tools/rebrand.sh --all`. Never commit to it by hand. |
| remote `omamail` | `https://github.com/huacnlee/omamail.git`. Its tags are fetched into `refs/remotes/omamail/tags/*` so they never collide with maitri mail's own `vX.Y.Z` tags; `tools/sync-upstream.sh` configures this. |

Never merge a raw omamail tag or omamail's `main` into `main`: every upstream line that says "omamail" or "Omarchy" would conflict with the rename.

## Syncing a release

`.github/workflows/sync-upstream.yml` runs daily and on demand. It takes the newest omamail **published** GitHub release (a bare tag can precede a failed publication), runs `tools/sync-upstream.sh --no-merge <tag>`, pushes `upstream`, and opens or updates one pull request from `upstream` into `main` that lists the conflicts. It never merges. It needs a `SYNC_TOKEN` secret: a fine-grained token or GitHub App token on this repository with Contents, Pull requests and Workflows read/write. Workflows write is needed because omamail's history touches `.github/workflows`; a token-created pull request also triggers CI, which `GITHUB_TOKEN` would not.

Merge that pull request with a **merge commit**. Squash or rebase loses the ancestry the next sync uses to tell which release `upstream` already has. If it conflicts, do not use the GitHub editor (it would commit `main` into `upstream`); resolve locally:

```bash
git fetch origin
git switch -c beyer/sync-omamail-v0.10.9 origin/main
git merge origin/upstream
tools/rebrand.sh --paths <resolved files>   # in case a hunk brought the upstream brand back
tools/rebrand.sh --check
make test
```

By hand, without the workflow: `tools/sync-upstream.sh v0.10.9` advances `upstream` and merges it into the current branch; `tools/sync-upstream.sh --latest` prints the newest release `upstream` lacks.

## The rebrand

`tools/rebrand.sh` is the single source of truth. Rules run in this order on every tracked text file, skipping lines marked `rebrand:keep` and the files in `CONTENT_EXCLUDE`:

| Upstream | maitri mail | Where |
|---|---|---|
| plugin id `omamail` | `maitri.mail` | `summon/toggle/hide/call/serviceFor("…")`, `shell summon …`, `plugin enable …`, `id: "…"`, `id === "…"`, `moduleName`, `plugin_id=` |
| `omamail::`, `fn omamail(` | `maitri_mail::`, `maitri_mail(` | Rust crate paths and functions |
| `x_omamail_y` | `x_maitri_mail_y` | snake_case identifiers |
| `omamailFoo` | `maitriMailFoo` | camelCase identifiers |
| `OMAMAIL_*` | `MAITRI_MAIL_*` | environment variables (`MAITRI_MAIL_BIN`, …) |
| `Omamail.Service`, `OmamailLogo`, `as Omamail` | `MaitriMail.Service`, `MaitriMailLogo`, `as MaitriMail` | QML namespaces and type names (`Mail` alone would clash with test aliases) |
| `Omamail` | `Mail` in code and UI, `maitri mail` in Markdown | display name |
| `omamail` | `maitri-mail` | binary, Cargo package, config/cache/state dirs, keyring service, desktop id, MCP server name |
| `an Omarchy`, `an Omamail` | `a maitri`, `a Mail` | articles |
| `Omarchy 4` | `maitri` | the shell generation the plugin targets |
| `OMARCHY`, `Omarchy`, `omarchy` | `MAITRI`, `maitri`, `maitri` | shell commands (`maitri-shell`, `maitri-default-agent`, …), paths (`/usr/share/maitri/shell`, `~/.local/state/maitri/current/theme`) and prose |

Protected tokens survive untouched: `huacnlee/omamail`, `huacnlee.github.io/omamail`, `github.com/basecamp/omarchy`, `omacom/omarchy`, `omarchy.org`, and one JMAP fixture whose byte size a test asserts. Two Omarchy documentation links are rewritten to `docs/maitri-shell.md` in maitri. Paths are renamed with the same rules (`ui/components/OmamailLogo.qml` → `ui/components/MaitriMailLogo.qml`).

`--all` also applies omamail's own release pin commit: a tag is cut before omamail's release workflow advances `backend-version` and folds the unreleased API step in `backend-api.json`, so the tag tree still pins the previous backend. maitri builds the backend from the same tree, so `backend-version` becomes the Cargo version and the contract is folded exactly as `scripts/package-backend.py pin` does upstream.

`tools/rebrand.sh --check` fails on any unprotected brand token or branded path; CI, `make test` (through `tests/test_maitri.sh`) and the release workflow run it.

## What maitri drops

`DELETE_LIST` in `tools/rebrand.sh` is applied on every sync, so these never come back:

- upstream `.github/` (CI, Pages, funding), `.agents/` and `.codex/` maintainer prompts
- `install.sh`, `install.ps1` and the Pages site `docs/index.html`
- `app/`, the standalone Qt desktop host and its macOS, Windows and Linux packaging
- upstream's GitHub release, binary download and pin machinery (`scripts/publish*.sh`, `release-*.sh`, `bump.sh`, `install-backend.sh`, `uninstall-backend.sh`) and their tests
- `scripts/link-plugin.sh`, the third-party plugin dev link

The Rust `standalone` feature and the `ui/` host seams for the standalone app stay in the tree because they are woven through shared code; they compile but nothing builds or ships them.

## maitri deltas on main

Expect sync conflicts in these files; resolve toward maitri's side unless upstream changed the behaviour they wrap.

| File | Delta |
|---|---|
| `scripts/backend-runtime.py` | Status-only probe of the packaged `/usr/bin/maitri-mail`; no download, install or `~/.local/bin` link. `MAITRI_MAIL_BIN` remains the development override. |
| `ui/components/BackendSetup.qml` | No Install backend or Install CLI controls; points at the `maitri-mail` package. |
| `tests/test_backend_runtime.py`, `ui/tests/qml/tst_backend_setup.qml` | Tests for the above. |
| `Makefile`, `tests/test_source.sh` | Dropped standalone app, release and plugin-link targets and checks; `make install` stages the package layout. |
| `README.md`, `MAITRI.md`, `AGENTS.md` (last section), `docs/BACKEND-RUNTIME.md` (opening) | maitri documentation. |
| `manifest.json` | `homepage`. |
| `ui/assets/maitri-mail.svg`, `docs/images/maitri-mail.svg`, `ui/components/GmailIcon.qml`, `ui/components/MaitriMailLogo.qml`, `scripts/notify-mail.py` (icon painting), `tests/test_notification.py`, `ui/tests/qml/tst_maitri_mail_logo.qml`, `ui/tests/qml/tst_bar_widget_icon.qml` | The maitri heart seal mark: a frame and V fold in the foreground with a heart in the accent, replacing omamail's M. The SVG marks shapes with `class="foreground"` / `class="accent"` and `notify-mail.py` paints by class. Always resolve toward maitri's side; `tests/test_maitri.sh` fails if the M comes back. |
| `.github/workflows/`, `tools/`, `tests/test_maitri*.{sh,py}` | maitri-only files. |

## Packaging

`tools/install.sh --destdir DIR` (or `make install DESTDIR=DIR`) stages what maitri-pkgs ships:

- `/usr/bin/maitri-mail`: the backend the plugin launches, and the CLI
- `/usr/share/maitri-plugins/mail/`: `manifest.json`, `backend-version`, `backend-api.json`, `LICENSE`, `ui/` without `ui/tests`, and `scripts/` without the release helpers
- `/usr/share/licenses/maitri-mail/LICENSE`

The plugin requires the backend's `--version` to equal `backend-version` exactly, so the backend and plugin must come from the same tag and the same package.

Release tags are `vX.Y.Z`, matching the synced omamail version, or `vX.Y.Z-maitri.N` for a maitri-only fix on top of it. Pushing one runs `.github/workflows/release.yml`, which checks that the tag, `Cargo.toml`, `manifest.json` and `backend-version` agree, tests the backend, and publishes `maitri-mail-<version>.tar.gz` with `SHA256SUMS`.

## Shell compatibility

omamail is written against Omarchy's shell. maitri's shell is Omarchy 4.0.4's, rebranded, so newer upstream releases may reach for APIs maitri lacks. `tests/test_maitri_shell_api.py` compares the plugin's qs.Ui stubs and every `Style`, `Color` and `Border` member it reads with a maitri checkout (`MAITRI_SHELL_DIR=.../maitri/shell`); CI clones maitrios/maitri for it. A failure there means a sync needs a maitri delta, or maitri's shell needs the API.
