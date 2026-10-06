#!/usr/bin/env bash
# QML checks for the bar widget: syntax via Qt6 qmllint when available, plus
# structural assertions on the parts the manifest promises.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fail() { echo "FAIL: $*" >&2; exit 1; }

qml="BarWidget.qml"
[[ -f $qml ]] || fail "missing $qml"

# Prefer a Qt6 qmllint: the Qt5 build commonly on PATH cannot parse Quickshell
# QML and exits non-zero without a useful message.
lint=""
for cand in /usr/lib/qt6/bin/qmllint "$(command -v qmllint 2>/dev/null || true)"; do
  [[ -n $cand && -x $cand ]] || continue
  if "$cand" --version 2>/dev/null | grep -qE '^qmllint 6'; then lint="$cand"; break; fi
done

if [[ -n $lint ]]; then
  if ! "$lint" "$qml" >/tmp/omarchy-dsh-qmllint.out 2>&1; then
    cat /tmp/omarchy-dsh-qmllint.out >&2
    fail "qmllint reported errors"
  fi
  echo "qmllint 6 OK ($qml)"
else
  echo "note: no Qt6 qmllint found; skipped syntax check"
fi

grep -q 'moduleName: "devmercenario.dsh"' "$qml" || fail "moduleName does not match the manifest id"
grep -q 'IpcHandler' "$qml" || fail "no IpcHandler for shell IPC"
grep -q 'BarIconButton' "$qml" || fail "no BarIconButton"
grep -q 'assets/dsh.svg' "$qml" || fail "bundled icon is not referenced"
grep -q 'runVerb("toggle")' "$qml" || fail "left click does not toggle the server"
grep -q 'runVerb("open")' "$qml" || fail "no open action"
grep -q 'idleOpacity' "$qml" || fail "no idle opacity state"
grep -q 'statusProc' "$qml" || fail "no status polling process"

python3 - "$qml" <<'PY'
import sys
src = open(sys.argv[1], encoding="utf-8").read()
for left, right in (("{", "}"), ("(", ")"), ("[", "]")):
    if src.count(left) != src.count(right):
        print(f"unbalanced {left}{right}: {src.count(left)} vs {src.count(right)}", file=sys.stderr)
        sys.exit(1)
PY

echo "barwidget OK"
