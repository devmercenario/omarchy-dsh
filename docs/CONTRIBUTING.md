# Contributing & engineering guide

> Technical notes for extending or maintaining `omarchy-dsh`. User-facing
> documentation lives in the root [README](../README.md).

## Tenets

1. **English only** — code, comments, UI strings, docs, and commit messages.
2. **Never edit `/usr/share/omarchy`** — it is package-owned and rewritten on
   every `omarchy update`. Everything here lives in user space.
3. **Stay in user space and unprivileged** — no `sudo`, no `pkexec`, no
   systemd units. The plugin runs inside `omarchy-shell` as the user.
4. **Idempotent and reversible** — `start` never launches a second server;
   `stop` only ever touches a verified `dsh … web` process.
5. **Follow Omarchy conventions** — Quickshell/`qs.*` styling tokens, the
   plugin manifest contract, and the `omarchy <group> <action>` CLI shape.

## Layout

```
omarchy-dsh/
├── manifest.json              Omarchy plugin manifest (id devmercenario.dsh)
├── BarWidget.qml              Bar widget entry point; poll + paint + clicks
├── assets/dsh.svg             Original icon (not the official logo)
├── bin/omarchy-dsh            State/process helper (start|stop|toggle|…)
├── tests/                     Suites, preflight, vendored baseline scanner
├── .github/workflows/         CI
└── .githooks/pre-push         Runs tests/preflight.sh before pushing
```

## Design notes

- **Port ownership is authority.** `find_running_pid` first asks `ss` who
  listens on the configured port and only accepts that PID if it is a
  same-user `dsh … web`. The PID file is a fallback used while a server is
  still binding. This is what keeps two instances on different ports from
  crossing wires.
- **State lives in `$XDG_RUNTIME_DIR/omarchy-dsh/`** (owner-only). Never a
  predictable shared temporary path — a stale PID there could otherwise be
  used to signal the wrong process.
- **One session per server.** `start` uses `setsid`; `stop` signals the
  process group, so the whole tree goes down and nothing else is affected.
- **The widget is disposable.** All behaviour lives in the helper, so a
  widget reload (or a second monitor) cannot corrupt state.

## Testing

```sh
bash tests/run_tests.sh      # manifest + QML + helper suites
bash tests/preflight.sh      # the four marketplace gates, run locally
git config core.hooksPath .githooks   # run preflight on every push
```

The helper suite runs against a faithful `dsh web` test double (its argv
contains `dsh` and `web`, like the real node process), so it never touches a
real server.

### QML linting

`qmllint` on `PATH` is often Qt5 and cannot parse Quickshell's `qs.*` imports.
`tests/test_barwidget.sh` therefore prefers `/usr/lib/qt6/bin/qmllint` when it
exists and skips with a notice otherwise.

## Vendored security baseline

`tests/marketplace-baseline/` holds unmodified copies of the Omarchy plugin
marketplace's Automated Security Baseline scanner. They are excluded from the
scanner's own scope. See [NOTICE](../tests/marketplace-baseline/NOTICE.md) for
the source commit. Keep them unmodified so the local result matches the
marketplace's exactly.

## Submitting

1. Commit, then run `bash tests/preflight.sh` (it scans `HEAD`).
2. Push to the public repository.
3. Submit through the marketplace issue form with one category and one to
   three tags.
