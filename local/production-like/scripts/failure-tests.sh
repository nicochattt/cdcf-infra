#!/usr/bin/env bash
set -euo pipefail

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/.."

pass() { echo "[failure-test] OK: $*"; }
fail() { echo "[failure-test] FAIL: $*" >&2; exit 1; }

restore_stack() {
  docker compose up -d --wait >/dev/null
}
trap restore_stack EXIT

docker compose stop postgres-host >/dev/null
if timeout 15s docker compose run --rm --no-deps openfga-migrate >/dev/null 2>&1; then
  fail 'OpenFGA unexpectedly connected while postgres-host was stopped'
fi
pass 'application database operation fails when postgres-host is stopped'
docker compose up -d --wait postgres-host >/dev/null

docker compose stop zitadel-login >/dev/null
login_code="$(curl --max-time 15 --silent --output /dev/null --write-out '%{http_code}' \
  http://127.0.0.1:8090/ui/v2/login/healthy || true)"
[[ "$login_code" == 000 || "$login_code" == 502 || "$login_code" == 503 || "$login_code" == 504 ]] \
  || fail "Login V2 outage returned HTTP $login_code, expected timeout or proxy 502/503/504"
backend_code="$(curl --silent --output /dev/null --write-out '%{http_code}' \
  http://127.0.0.1:8090/debug/ready)"
[[ "$backend_code" == 200 ]] \
  || fail "Zitadel backend route returned HTTP $backend_code while Login V2 was stopped"
pass 'Login V2 outage is isolated while Zitadel backend routing remains available'

restore_stack
trap - EXIT
./scripts/verify.sh
pass 'stack recovered and all integration checks pass'
