# DeepSeek Harness for Omarchy

[![Omarchy](https://img.shields.io/badge/Omarchy-Linux-blue.svg)](https://omarchy.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Arch%20Linux%20%7C%20Hyprland-lightgrey.svg)]()

One Omarchy bar icon to start, stop, and open the
[DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) web UI
(`dsh web`).

- 🟢 **Running** — the icon is drawn at full strength (white).
- ⚪ **Stopped** — the same icon is dimmed, so the bar reads at a glance.
- 🖱️ **Left click** toggles the server; **right click** opens the web UI.
- 🔒 Self-contained and unprivileged: no systemd units, no privileged helpers, no second Quickshell process.

---

## Requirements

| Dependency | Why | Notes |
|---|---|---|
| Omarchy 4 (Quattro) | Hosts the shell and bar | The bar widget runs inside `omarchy-shell`. |
| `dsh` (DeepSeek Harness CLI) | The command this plugin toggles | Must be on `PATH`. |
| `ss` (iproute2) | Finds the process listening on the port | Present on Arch Linux by default. |
| `setsid` (util-linux) | Starts `dsh web` in its own session | Present on Arch Linux by default. |
| `xdg-open` (optional) | Opens the web UI on right click | Skip if you never use right click. |

Install `dsh` however you prefer. If you manage tools with
[mise](https://mise.jdx.dev/), this keeps it updated automatically because
`omarchy update` already runs `mise up`:

```sh
mise use -g npm:@deepseek-ai/dsh@latest
```

> `dsh` currently publishes pre-releases only, so mise needs
> `mise settings set prereleases true` for `latest` to resolve.

## Installation

### Omarchy plugin manager (recommended)

```sh
omarchy plugin add https://github.com/devmercenario/omarchy-dsh.git --enable --yes
```

### Manual

1. Copy this directory to `~/.config/omarchy/plugins/devmercenario.dsh/`.
2. `omarchy-shell shell rescanPlugins`
3. `omarchy plugin enable devmercenario.dsh`
4. Optionally move the icon: `omarchy bar move devmercenario.dsh --section right`

## Removal

```sh
omarchy plugin remove devmercenario.dsh --yes
```

The plugin stores nothing outside `$XDG_RUNTIME_DIR/omarchy-dsh/` and
`$XDG_STATE_HOME/omarchy-dsh/`; both are safe to delete after removal.

## Usage

| Action | Effect |
|---|---|
| Left click | Start `dsh web --no-open` if stopped, stop it if running. |
| Right click | Open the running web UI (uses the tokenized URL `dsh` prints). |

Shell IPC is also available:

```sh
omarchy-shell shell call devmercenario.dsh toggle ''
omarchy-shell shell call devmercenario.dsh open ''
omarchy-shell shell call devmercenario.dsh status ''
```

A helper CLI ships with the plugin for scripting and troubleshooting:

```sh
~/.config/omarchy/plugins/devmercenario.dsh/bin/omarchy-dsh status --json
~/.config/omarchy/plugins/devmercenario.dsh/bin/omarchy-dsh toggle
```

## Settings

Configured per widget in `~/.config/omarchy/shell.json` (see the widget
documentation in the Omarchy shell for the settings UI).

| Key | Type | Default | Meaning |
|---|---|---|---|
| `dshBin` | string | `dsh` | The `dsh` executable to run. |
| `host` | string | `127.0.0.1` | Address `dsh web` binds. |
| `port` | integer | `3080` | Port `dsh web` binds. |
| `refreshIntervalSec` | integer | `5` | How often the widget polls status. |
| `idleOpacity` | number | `0.35` | Icon opacity while stopped. |
| `glyph` | string | `""` | Optional Nerd Font glyph instead of the bundled icon. |

## How it works

`BarWidget.qml` is a thin view: it polls `bin/omarchy-dsh status --json`
and paints the icon, and it forwards clicks to `bin/omarchy-dsh
toggle`/`open`. All process handling lives in the helper:

- State (PID and process group) is kept in an owner-only directory under
  `$XDG_RUNTIME_DIR`, never in a shared temporary path.
- `start` launches `dsh web` in a **new session**, so `stop` can signal the
  whole process group without ever touching another process.
- `stop` verifies the target is a live, same-user process whose argv is
  `dsh … web` before signaling it, then waits and falls back to `SIGKILL`.
- The process listening on the configured port is authoritative, so two
  instances on different ports never interfere.

## Icon

`assets/dsh.svg` is the **DeepSeek whale logo**, used to identify the
DeepSeek Harness service this plugin controls. The DeepSeek name and logo are
trademarks of DeepSeek; this plugin is an independent community project and is
not affiliated with or endorsed by DeepSeek. Set the `glyph` setting if you
would rather use a Nerd Font glyph.

## License

MIT — see [LICENSE](LICENSE). This is an independent community plugin and is
not affiliated with or endorsed by DeepSeek or Omarchy.
