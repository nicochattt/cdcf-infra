# Local auth stack

This directory contains a disposable local Zitadel and OpenFGA environment.
The optional proxy overlay mounts the production nginx configuration as its
read-only source:

```text
../../auth/nginx/zitadel.conf
```

There is intentionally no maintained local copy of that configuration. Routing
and the Content Security Policy therefore come from the same file used in
production.

## Base stack

```bash
cd local/auth
docker compose up -d --wait
```

Zitadel is exposed at `http://localhost:8080` and OpenFGA at
`http://localhost:8081`.

## Local Plesk proxy simulation

Login V2 is configured during Zitadel's first boot. Reset the disposable local
volumes before switching to this variant:

```bash
cd local/auth
docker compose -f docker-compose.yml -f docker-compose.plesk.yml down -v
docker compose -f docker-compose.yml -f docker-compose.plesk.yml up -d --wait
```

The proxy is exposed at `http://localhost:8090`; the admin console is available
at `http://localhost:8090/ui/console/`.

## Scope and known differences

This is not a complete production validation. It does not test Plesk itself,
Plesk-managed TLS, Let's Encrypt, VPS filesystem permissions,
`host.docker.internal`, host PostgreSQL, or production `pg_hba.conf` rules.
The local databases are containerized for ease of use.

At container startup, the overlay generates an ephemeral nginx configuration
from that source and changes only these environment-specific directives:

- `Host` becomes `localhost:8090`;
- `X-Forwarded-Host` becomes `localhost:8090`;
- `X-Forwarded-Proto` becomes `http`.

These directives cannot be overridden from a second nginx file without
redeclaring the complete `location` blocks. Doing that would duplicate the
routing and CSP-sensitive configuration this stack is intended to test. The
generated file exists only inside the running container; the production source
remains unchanged.

## Stop or reset

```bash
# Keep local database data
docker compose -f docker-compose.yml -f docker-compose.plesk.yml down

# Delete all disposable local data
docker compose -f docker-compose.yml -f docker-compose.plesk.yml down -v
```
