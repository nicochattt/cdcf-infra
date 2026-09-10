# Local environments

This directory provides two complementary Docker environments for auth and
authorization development.

## Fast development

Use [`dev`](dev/) for daily work. It runs the pinned Zitadel and OpenFGA images
with simple containerized PostgreSQL databases. An optional Compose overlay adds
Login V2 and a local reverse proxy based on the production nginx configuration.

```bash
cd local/dev
docker compose up -d --wait
```

## Production-like validation

Use [`production-like`](production-like/) before proposing infrastructure or
routing changes. It assembles independently testable PostgreSQL, application,
and nginx components and exercises boundaries that the fast environment omits.

```bash
cd local/production-like
docker compose up -d --build --wait
./scripts/verify.sh
```

Two hybrid scenarios are also available when only one production-like boundary
needs to be isolated:

```bash
# Production-like PostgreSQL with the pinned application images, without nginx
docker compose -f local/production-like/scenarios/compose.postgres.yaml up -d --build --wait

# Production-like nginx with the fast dev databases and application stack
docker compose -f local/production-like/scenarios/compose.nginx.yaml up -d --build --wait
```

This remains a Docker approximation. It does not reproduce Plesk, managed TLS,
the VPS kernel, firewall rules, permissions, production secrets, or production
data.

## Layout

```text
local/
├── dev/                         fast daily environment
└── production-like/
    ├── compose.yaml             complete production-like assembly
    ├── components/
    │   ├── postgres/            Ubuntu/PostgreSQL host boundary
    │   ├── applications/        Zitadel, Login V2, and OpenFGA
    │   └── nginx/               reverse-proxy boundary
    ├── scenarios/               hybrid boundary assemblies
    └── scripts/                 integration checks and reset helpers
```
