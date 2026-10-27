# Oracle APEX + Nginx HTTPS Setup

This repository provides a deployment patch and operational setup for running Oracle APEX on Oracle AI Database 26ai (Free), ORDS, and Nginx with HTTPS on a public VPS.

It is intended to be used on top of the upstream Oracle APEX/ORDS project structure, preserving the upstream database and APEX configuration while adding a public HTTPS layer via Nginx and Let's Encrypt.

## What this repo contains

- `docker-compose.yml` — Compose stack for:
  - Oracle database
  - ORDS
  - Nginx
- `nginx/default.conf` — HTTP/HTTPS reverse proxy and static asset handling
- `scripts/setup-public-nginx.sh` — script to configure DNS, certbot, and HTTPS
- `certbot/` — challenge and certificate-related directories
- `.env.example` — environment variable template
- `docs/` — supporting project notes
- `PATCH-README.md` — usage notes for patching an upstream repo

## Project goal

The goal is to expose Oracle APEX securely over the internet with:

- public HTTP redirect to HTTPS
- TLS certificates from Let's Encrypt
- Nginx acting as the public entry point
- Oracle database and ORDS kept internal to the Docker network

## Architecture

The stack is structured as follows:

- `database` service: Oracle AI Database 26ai Free
- `ords` service: Oracle REST Data Services (ORDS)
- `nginx` service: public HTTPS endpoint

Key point:

- DB and ORDS are not published to the host directly
- Only Nginx exposes ports 80 and 443
- APEX static assets are served from `/usr/share/nginx/html`
- All non-static requests are proxied to `http://ords:8080`

## Requirements

Before running the setup, make sure you have:

- Linux VPS or server with public IP
- Docker Engine + Docker Compose plugin
- Domain name pointing to the server IP
- Firewall allowing inbound TCP 80 and 443
- A valid upstream Oracle APEX repo cloned locally

## Quick start

1. Clone the upstream Oracle APEX project.
2. Copy this repository's files into the repository root, preserving the upstream `.env`, `apex/`, and helper scripts.
3. Replace the upstream `docker-compose.yml` with the one in this repo.
4. Create `.env` from `.env.example` and set strong passwords.
5. Download and unpack the APEX source bundle before starting the stack:

```bash
chmod +x scripts/get-apex.sh
./scripts/get-apex.sh
```

This script downloads the Oracle APEX ZIP, validates the published SHA256 checksum, and extracts it into `./apex` so the ORDS container can install or upgrade APEX on first boot.

6. Run the public HTTPS setup:

```bash
chmod +x scripts/setup-public-nginx.sh
sudo ./scripts/setup-public-nginx.sh your-domain.example.com
```

You can optionally pass a contact email as the second argument:

```bash
sudo ./scripts/setup-public-nginx.sh your-domain.example.com admin@example.com
```

## Important operational notes

- Keep `.env` and the `apex/` directory from the upstream project.
- Do not run `docker compose down -v` unless you explicitly want to delete persistent data.
- This repository is a patch/setup bundle, not a full replacement for the upstream application source.
- The setup script only configures Nginx and certificates; it does not rewrite the Docker Compose file.
- Run `./scripts/get-apex.sh` before `docker compose up -d` when setting up a fresh environment.

## Environment variables

The example file includes:

```env
ORACLE_PWD=...
ORDS_PUBLIC_PWD=...
APEX_PUBLIC_PWD=...
APEX_ADMIN_PWD=...
DB_PORT=1521
ORDS_PORT=8080
APEX_EDITION=full
```

Set these in a real `.env` file before running Docker Compose.

## Validation

After setup, verify with:

```bash
docker compose ps
curl -I http://your-domain.example.com/
curl -I https://your-domain.example.com/
curl -I https://your-domain.example.com/i/apex_version.txt
```

## File summary

### `docker-compose.yml`
Defines the full Oracle DB + ORDS + Nginx stack and keeps the database and ORDS internal to Docker networking.

### `scripts/get-apex.sh`
Downloads Oracle APEX, verifies the published checksum, and extracts it into `./apex`.

### `scripts/setup-public-nginx.sh`
Handles:

- temporary HTTP bootstrap for ACME challenge
- certbot certificate generation via webroot
- final HTTPS redirect config
- Nginx reload after certificate renewal

### `nginx/default.conf`
Contains the final HTTP-to-HTTPS redirect and proxy rules.

## Notes for maintainers

This repo is designed for a specific deployment flow, and the project should be treated as infrastructure automation rather than a standalone application codebase.

If you are using this repo as a patch on top of an upstream APEX project, keep the upstream files intact and apply the patch carefully.

## License

This project does not declare a repository license in the GitHub metadata. Use it according to the upstream project policy and your local deployment requirements.

## Related files

- `PATCH-README.md`
- `.env.example`
- `docker-compose.yml`
- `scripts/get-apex.sh`
- `scripts/setup-public-nginx.sh`
