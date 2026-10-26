# maitri mail

Mail and calendar for [maitri](https://github.com/maitrios/maitri). It lives in the maitri shell: an envelope with the unread count on the bar, and the inbox opens as its own window. Multiple accounts, keyboard-first, and it follows your maitri theme.

maitri mail is a fork of [omamail](https://github.com/huacnlee/omamail) by [Jason Lee](https://github.com/huacnlee), rebranded and packaged for maitri. All the mail and calendar work is his; maitri keeps the shell integration, packaging and a scripted sync that pulls in every omamail release. <!-- rebrand:keep -->

<img width="800" alt="maitri mail reading mail" src="docs/images/full-mail.webp" />

## Install

maitri mail ships with maitri as the `maitri-mail` package and sits on the default bar. Click the envelope, then add your mailbox.

If it is missing, add it from the maitri menu with **Install › Mail**, or:

```bash
maitri pkg add maitri-mail
```

**Remove › Mail** takes it out again; your accounts, cache and keyring entries stay.

To open it from the keyboard and make it the `mailto:` handler, choose **Settings → Default mail client → Set as default**. That binds `SUPER+SHIFT+E` (and `SUPER+SHIFT+ALT+E` for a new message) in a marked block of `~/.config/hypr/bindings.lua`, and **Undo** removes the block. To bind a toggle of your own instead, pick a free key such as:

```lua
o.bind("SUPER + ALT + M", "Mail", "maitri-shell shell toggle maitri.mail '{}'")
```

Press `?` in the window for the shortcut sheet, or see the [keyboard guide](docs/KEYS.md).

## Features

- **Multiple mailboxes:** Gmail, Outlook, Microsoft 365, HEY, JMAP and IMAP/SMTP, including Fastmail, iCloud and self-hosted servers.
- **Mail and calendar:** read, search, compose, manage attachments and respond to meeting invitations. Available actions depend on your provider.
- **Keyboard navigation:** `j`/`k` to move, `r` to reply, `c` to compose, `/` to search and `?` for all shortcuts.
- **AI assistance:** ask about selected messages and review suggested drafts with Claude, OpenCode or Codex. It follows your maitri default agent, or pick one in Settings.
- **Desktop integration:** the bar widget, desktop notifications, and `mailto:` handling.
- **Privacy controls:** credentials stay in the system keyring and remote images stay blocked until you load them.

## Add your mailbox

Choose a provider in Settings. Gmail needs a Google OAuth client, and Outlook and Microsoft 365 need a Microsoft app registration, each created once in your own Google Cloud or Microsoft Entra account; maitri ships no shared OAuth secrets. HEY uses the official [HEY CLI](https://github.com/basecamp/hey-cli). JMAP and IMAP usually use an app password or API token.

See [mailbox setup](docs/MAILBOXES.md) for provider instructions and limitations, including Microsoft 365 and Proton Mail Bridge.

## Where things live

| Path | What |
| --- | --- |
| `/usr/bin/maitri-mail` | The backend the plugin runs, which is also the `maitri-mail` CLI |
| `/usr/share/maitri-plugins/mail/` | The first-party add-on plugin the maitri shell loads, id `maitri.mail` |
| `~/.config/maitri-mail/` | Accounts and settings |
| `~/.cache/maitri-mail/`, `~/.local/state/maitri-mail/` | Message cache, drafts, diagnostics and AI history |

The plugin never downloads or replaces its backend. It checks that `/usr/bin/maitri-mail` reports the exact version in `backend-version`, and `maitri update` keeps the two in step.

### Coming from omamail <!-- rebrand:keep -->

maitri mail keeps omamail's keyring entries as they are, so saved sign-ins carry over. Its files live in `~/.config/maitri-mail`, `~/.cache/maitri-mail` and `~/.local/state/maitri-mail`; maitri's migration moves the omamail directories there and retires the old third-party plugin. See [MAITRI.md](MAITRI.md#moving-an-omamail-user-to-maitri-mail) for the full list. <!-- rebrand:keep -->

## Develop

Install Rust, Node, Python 3.11+ and Qt 6 (`qt6-declarative` on Arch), then:

```bash
make test                       # Rust, JS, shell and offscreen QML suites
cargo build --release --locked  # target/release/maitri-mail
make install DESTDIR=/tmp/pkg   # stage the packaged layout
```

To run a checkout's backend in the shell, start `maitri-shell` with `MAITRI_MAIL_BIN` pointing at the binary (`./dev run` prints the steps). To load a checkout of the plugin itself, symlink it to `/usr/share/maitri-plugins/mail` in place of the packaged copy and run `maitri-shell shell rescanPlugins`.

Working agreements for code changes are in [AGENTS.md](AGENTS.md). How the fork tracks omamail, and what it changes, is in [MAITRI.md](MAITRI.md). <!-- rebrand:keep -->

## License

MIT, like omamail. See [LICENSE](LICENSE); copyright stays with Jason Lee for the upstream work. <!-- rebrand:keep -->

maitri mail is not affiliated with Google, Microsoft or 37signals. Gmail, Outlook and HEY belong to their respective trademark owners.
