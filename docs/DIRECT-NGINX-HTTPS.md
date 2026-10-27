# Direct public VPS deployment with Nginx HTTPS

This patch adapts the upstream `Mohamedhrby/oracle-26ai-apex-docker` project for direct domain-to-VPS access without Cloudflare Tunnel.

## Apply the patch

1. Clone the original repository (or use your existing project checkout).
2. Copy these patch files into the repository root, preserving the `scripts/`, `nginx/`, and `docs/` folders.
3. Ensure your original `.env`, `apex/`, and original scripts remain in place.
4. Review `docker-compose.yml` and `.env` before running the setup script.
5. Make sure DNS A points to the VPS public IP and inbound TCP 80/443 are allowed.

Run from the repo root:

```bash
cp .env.example .env
chmod +x scripts/get-apex.sh
sudo ./scripts/get-apex.sh
chmod +x scripts/setup-public-nginx.sh
sudo ./scripts/setup-public-nginx.sh your-domain.com admin@example.com
```

Email is optional:

```bash
sudo ./scripts/setup-public-nginx.sh your-domain.com
```
Wait until proccess done.

```bash
chmod +x ./scripts/set-admin-password.sh
```

The script:
- backs up the original Compose file,
- removes host publication for database 1521 and ORDS 8080,
- adds Nginx on public ports 80 and 443,
- requests a Let's Encrypt certificate using HTTP-01,
- configures `/i/*` static assets and proxies all other paths to ORDS,
- installs a certificate-renewal deploy hook.

It never runs `docker compose down -v`. Named volumes `oradata` and `ords_config` remain defined and are not deleted.

## Expected ports

- Nginx: public TCP 80 and 443.
- ORDS: internal Docker TCP 8080 only.
- Oracle Database: internal Docker TCP 1521 only.

## Operations

```bash
docker compose ps
docker compose logs -f nginx
docker compose logs -f ords
docker compose up -d
```

## Safety notes

- Direct access requires a public IP with inbound connectivity; CGNAT without port forwarding will not work.
- If DNS is managed by Cloudflare, use DNS-only for direct access; do not configure Tunnel for this design.
- Do not expose database port 1521 or ORDS port 8080 to the public Internet.
- Do not run `docker compose down -v`.
- The setup script replaces `docker-compose.yml` with the direct-Nginx variant after making a timestamped backup. Review the generated backup if rollback is needed.
