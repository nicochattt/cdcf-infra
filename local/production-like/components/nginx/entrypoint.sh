#!/bin/sh
set -eu

SOURCE_CONFIG=/etc/nginx/production/zitadel.conf
RUNTIME_CONFIG=/etc/nginx/conf.d/default.conf

fail() {
    printf '%s\n' "ERROR: $*" >&2
    exit 1
}

assert_count() {
    expected_count=$1
    directive=$2
    actual_count=$(grep -F -c "$directive" "$SOURCE_CONFIG" || true)

    if [ "$actual_count" -ne "$expected_count" ]; then
        fail "production nginx configuration changed.
Expected exactly ${expected_count} occurrence(s) of:
${directive}
Found: ${actual_count}

Review local/production-like/components/nginx before continuing."
    fi
}

[ -f "$SOURCE_CONFIG" ] || fail "production nginx configuration is missing: $SOURCE_CONFIG"

# These exact-count assertions intentionally make production changes fail fast.
assert_count 2 'proxy_set_header Host $host;'
assert_count 2 'proxy_set_header X-Forwarded-Host $host;'
assert_count 2 'proxy_set_header X-Forwarded-Proto https;'

sed \
    -e 's/proxy_set_header Host $host;/proxy_set_header Host localhost:8090;/g' \
    -e 's/proxy_set_header X-Forwarded-Host $host;/proxy_set_header X-Forwarded-Host localhost:8090;/g' \
    -e 's/proxy_set_header X-Forwarded-Proto https;/proxy_set_header X-Forwarded-Proto http;/g' \
    "$SOURCE_CONFIG" > "$RUNTIME_CONFIG"

# Reverse only the approved local substitutions and require byte-for-byte
# equality with the read-only production source. Any extra drift is fatal.
comparison_config=$(mktemp)
trap 'rm -f "$comparison_config"' EXIT
sed \
    -e 's/proxy_set_header Host localhost:8090;/proxy_set_header Host $host;/g' \
    -e 's/proxy_set_header X-Forwarded-Host localhost:8090;/proxy_set_header X-Forwarded-Host $host;/g' \
    -e 's/proxy_set_header X-Forwarded-Proto http;/proxy_set_header X-Forwarded-Proto https;/g' \
    "$RUNTIME_CONFIG" > "$comparison_config"

cmp -s "$SOURCE_CONFIG" "$comparison_config" || fail \
    'runtime configuration differs from production beyond the approved local transformations.'

nginx -t
printf '%s\n' '[nginx-simulation] Configuration validated; starting nginx.'
exec nginx -g 'daemon off;'
