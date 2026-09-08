# Local nginx/Plesk simulation

## Objective

This stack tests the nginx/Plesk reverse-proxy role against the real application
containers started by `local/auth`. It does not create fake upstreams or duplicate
Zitadel, Zitadel Login V2, OpenFGA, or their databases.

## Prerequisites

The auth Compose project is named `cdcf-auth-test`, so its default network is
`cdcf-auth-test_default`. This simulation joins that existing network as an
external network and resolves the real services through Docker DNS.

The production nginx configuration declares both `zitadel:8080` and
`zitadel-login:3000`. Because nginx resolves both upstream names at startup, the
base auth stack alone is insufficient: `zitadel-login` must also be running. It
already exists in `local/auth/docker-compose.plesk.yml`; do not start the old
`plesk-proxy` service from that overlay.

Start the application stack and Login V2:

```bash
cd local/auth
docker compose up -d --wait
docker compose -f docker-compose.yml -f docker-compose.plesk.yml \
  up -d --wait zitadel-login
```

Then start and verify this independent nginx simulation:

```bash
cd ../nginx-simulation
docker compose up -d --build --wait
./verify.sh
```

If an older `plesk-proxy` container is already running, stop and remove it first
because it also publishes `127.0.0.1:8090`:

```bash
cd ../auth
docker compose -f docker-compose.yml -f docker-compose.plesk.yml stop plesk-proxy
docker compose -f docker-compose.yml -f docker-compose.plesk.yml rm -f plesk-proxy
```

## Architecture

```text
local/auth
  zitadel:8080
  zitadel-login:3000
        ▲
        │ cdcf-auth-test_default (external Docker network)
        │
local/nginx-simulation
  nginx-host (127.0.0.1:8090 -> :80)
```

`auth/nginx/zitadel.conf` is mounted read-only at
`/etc/nginx/production/zitadel.conf` and remains the sole source of truth. At
startup, `entrypoint.sh` creates an ephemeral runtime configuration and changes
only these environment-specific values:

- `Host`: `$host` to `localhost:8090`;
- `X-Forwarded-Host`: `$host` to `localhost:8090`;
- `X-Forwarded-Proto`: `https` to `http`.

Exact-count checks fail fast if those production directives change. The generated
file is reverse-transformed and compared byte-for-byte with the source, proving
that no other content changed. This preserves the production locations, routes,
timeouts, comments, and Content Security Policy without copying the CSP locally.
`nginx -t` must pass before nginx starts in the foreground.

## What is reproduced

- Ubuntu 24.04;
- nginx installed through APT;
- the real read-only production nginx configuration;
- reverse proxying and Docker DNS to the real auth containers;
- routing to Zitadel and Zitadel Login V2;
- the production CSP and proxy headers;
- an IPv4 healthcheck through `/debug/ready`;
- local HTTP on `127.0.0.1:8090`.

## What is not reproduced

- Plesk itself or its generated configuration;
- TLS termination, Let's Encrypt, or real domain names;
- the VPS firewall, kernel, or host networking;
- a host-installed PostgreSQL server;
- the complete production deployment and operations environment.

The PostgreSQL host simulation remains independent and is not connected by this
stack. A future cleanup can separate Login V2 orchestration from the legacy local
Plesk overlay; until then, start only its `zitadel-login` target as shown above.
