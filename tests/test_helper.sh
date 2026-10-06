#!/usr/bin/env bash
# Helper lifecycle tests. Runs against a faithful `dsh web` test double whose
# argv contains `dsh` and `web` (like the real node process), so it never
# touches a real server and never depends on a network.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$root/bin/omarchy-dsh"
[[ -x $helper ]] || { echo "FAIL: $helper is not executable" >&2; exit 1; }

command -v python3 >/dev/null 2>&1 || { echo "note: python3 missing; skipping helper tests"; exit 0; }

tmp="$(mktemp -d)"
port=$(( 40000 + RANDOM % 20000 ))
cleanup() {
  "$helper" stop --port "$port" >/dev/null 2>&1 || true
  rm -rf "$tmp"
}
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

cat > "$tmp/dsh" <<'EOF'
#!/usr/bin/env bash
port=9999; host=127.0.0.1
while (( $# > 0 )); do
  case "$1" in
    --port) port="${2:-}"; shift 2;;
    --host) host="${2:-}"; shift 2;;
    *) shift;;
  esac
done
PORT="$port" HOST="$host" exec -a dsh python3 -c '
import http.server, os, socketserver
host = os.environ.get("HOST", "127.0.0.1")
port = int(os.environ.get("PORT", "3080"))
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer((host, port), http.server.SimpleHTTPRequestHandler) as s:
    s.serve_forever()
' web --no-open
EOF
chmod +x "$tmp/dsh"

h() { "$helper" "$@" --bin "$tmp/dsh" --port "$port"; }

# Initially stopped.
json="$(h status --json)"
echo "$json" | jq -e . >/dev/null || fail "status --json is not valid JSON: $json"
[[ $json == *'"running":false'* ]] || fail "expected stopped initially: $json"
if h status >/dev/null 2>&1; then fail "status must exit non-zero while stopped"; fi

# Start.
h start >/dev/null || fail "start failed"
sleep 0.6
json="$(h status --json)"
echo "$json" | jq -e . >/dev/null || fail "status --json is not valid JSON: $json"
[[ $json == *'"running":true'* ]] || fail "expected running after start: $json"
pid="$(echo "$json" | jq -r .pid)"
[[ $pid =~ ^[0-9]+$ ]] || fail "expected a numeric pid while running: $json"

# Idempotent start must not launch a second server.
h start >/dev/null || fail "second start failed"
json="$(h status --json)"
[[ "$(echo "$json" | jq -r .pid)" == "$pid" ]] || fail "start was not idempotent: $json"

# Toggle stops it.
h toggle >/dev/null || fail "toggle failed"
sleep 0.6
json="$(h status --json)"
[[ $json == *'"running":false'* ]] || fail "expected stopped after toggle: $json"
if h status >/dev/null 2>&1; then fail "status must exit non-zero after stop"; fi

# Toggle starts it again.
h toggle >/dev/null || fail "second toggle failed"
sleep 0.6
json="$(h status --json)"
[[ $json == *'"running":true'* ]] || fail "expected running after second toggle: $json"

h stop >/dev/null || fail "stop failed"
sleep 0.4
json="$(h status --json)"
[[ $json == *'"running":false'* ]] || fail "expected stopped after stop: $json"

echo "helper OK (port $port)"
