# Production-like nginx component

## Purpose

This component reproduces the internal nginx reverse-proxy boundary used in
production. It routes requests to the real Zitadel and Zitadel Login V2
containers while using the nginx configuration that is shipped to production:

```text
auth/nginx/zitadel.conf
```

The file is mounted read-only. There is no maintained local copy of the routes or
Content Security Policy.

This component has two supported uses:

- as a standalone nginx test connected to the applications started by
  `local/dev`;
- as part of the complete `local/production-like` environment.

## Difference from the development proxy

`local/dev/compose.proxy.yaml` provides a lightweight proxy based directly on
`nginx:alpine`. It is intended for fast daily development.

This production-like component builds its own Ubuntu 24.04 image and installs
nginx from the Ubuntu packages. It does not reuse the development proxy container
or image. Both implementations consume the same production nginx configuration,
but this component additionally validates its transformation before nginx starts.

## Runtime configuration

Production expects HTTPS termination and the public authentication hostname.
The local environment uses plain HTTP on `localhost:8090`. At startup,
`entrypoint.sh` generates an ephemeral nginx configuration and changes only:

- `Host`: `$host` to `localhost:8090`;
- `X-Forwarded-Host`: `$host` to `localhost:8090`;
- `X-Forwarded-Proto`: `https` to `http`.

Before nginx starts, the entrypoint:

1. verifies the exact number of production directives to transform;
2. applies the three local substitutions;
3. reverses them and compares the result byte-for-byte with the production file;
4. runs `nginx -t`;
5. starts nginx in the foreground.

This makes a production configuration change fail explicitly when the local
transformation needs to be reviewed. The production CSP, locations, comments and
all other directives remain unchanged.

## Complete production-like integration

The recommended use is through the top-level Compose project:

```bash
cd local/production-like
docker compose up -d --build --wait
./scripts/verify.sh
```

`local/production-like/compose.yaml` includes this component and attaches
`nginx-host` to the same application network as Zitadel and Login V2. The
integration overrides add health-based dependencies on both upstream services.

```text
http://localhost:8090
          |
          v
      nginx-host
       /       \
      v         v
 zitadel     zitadel-login
  :8080          :3000
```

The integration verification checks:

- nginx container health and configuration validity;
- Docker DNS resolution for `zitadel` and `zitadel-login`;
- direct reachability of both upstreams from nginx;
- `/debug/ready` through the reverse proxy;
- the Login V2 health route through the reverse proxy;
- OIDC discovery and the expected `http://localhost:8090` issuer.

## Standalone component test

The component can also proxy the services from `local/dev`. Both Zitadel and
Login V2 must be created together during a blank first boot because the Login V2
machine user and PAT are first-boot settings:

```bash
cd local/dev
docker compose -f compose.yaml -f compose.proxy.yaml down -v
docker compose -f compose.yaml -f compose.proxy.yaml \
  up -d --wait zitadel-login
```

Do not start `plesk-proxy` for this test because it also publishes port 8090.
Then start the standalone nginx component:

```bash
cd ../production-like/components/nginx
docker compose up -d --build --wait
./verify.sh
```

In this mode, `nginx-host` joins the external development network named
`cdcf-auth-test_default`. The standalone verification checks the production
configuration mount, approved local substitutions, CSP preservation, Docker DNS,
both real upstreams, OIDC discovery and the admin-console route.

## What this does not reproduce

- Plesk itself or its generated outer reverse-proxy configuration;
- TLS termination and certificate management;
- Let's Encrypt;
- the VPS firewall, kernel and host network;
- production domains, secrets, permissions, traffic and data.
