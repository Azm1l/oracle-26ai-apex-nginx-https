# Patch: Oracle APEX direct VPS + Nginx HTTPS

This patch is intended to be applied to a fresh clone of the upstream repository. The upstream repo remains the project base.

## What to do

1. Clone the upstream repo.
2. Copy the files from this ZIP into the repository root, preserving the upstream `.env`, `apex/` contents, and upstream helper scripts.
3. Replace the repository's `docker-compose.yml` once with the `docker-compose.yml` included in this patch. This is the single final Compose file: database + ORDS + Nginx. The setup script does **not** create or rewrite Compose.
4. Ensure DNS `ords.calistalab.my.id` points to the VPS public IP and inbound TCP ports 80 and 443 are allowed.
5. Run from the repository root:

```bash
chmod +x scripts/setup-public-nginx.sh
sudo ./scripts/setup-public-nginx.sh ords.calistalab.my.id
```

The script configures the temporary HTTP challenge, obtains a Let's Encrypt certificate, and writes the Nginx HTTP->HTTPS/proxy configuration. It does not rewrite `docker-compose.yml` and never runs `docker compose down -v`.

## Important

- Keep `.env` and the `apex/` folder from the upstream repo; do not replace them with anything from this patch.
- The Compose file publishes only Nginx ports 80/443. Database 1521 and ORDS 8080 are not published to the host.
- Do not run `docker compose down -v` unless you intentionally want to delete persistent data.
- This is a patch to apply locally; it does not modify the upstream GitHub repository.
