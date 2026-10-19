#!/usr/bin/env bash
set -Eeuo pipefail

# Run from the repository root after cloning the upstream project.
# This script ONLY configures Nginx/Certbot. It does NOT create or rewrite docker-compose.yml.
# Apply the provided docker-compose.yml patch to the upstream file once before running.
# It never executes `docker compose down -v`.

DOMAIN="${1:-}"
EMAIL="${2:-}"

if [[ -z "$DOMAIN" ]]; then
  read -r -p "Domain (contoh ords.example.com): " DOMAIN
fi
if [[ -z "$EMAIL" ]]; then
  read -r -p "Email Let's Encrypt (opsional, tekan Enter untuk tanpa email): " EMAIL
fi
if [[ -z "$DOMAIN" || "$DOMAIN" != *.* || "$DOMAIN" == *" "* ]]; then
  echo "ERROR: Domain tidak valid."
  exit 1
fi
if [[ ! -f docker-compose.yml || ! -d ./apex/images ]]; then
  echo "ERROR: Jalankan dari root repo; docker-compose.yml dan ./apex/images harus ada."
  exit 1
fi
if ! grep -Eq '^[[:space:]]+nginx:\s*$' docker-compose.yml; then
  echo "ERROR: service nginx belum ada di docker-compose.yml. Terapkan file Compose patch dari ZIP terlebih dahulu."
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: Docker Compose plugin tidak ditemukan."
  exit 1
fi

echo
echo "Domain: $DOMAIN"
echo "Project: $PWD"
echo
echo "Pastikan DNS A domain sudah mengarah ke IP publik VPS dan port 80/443"
echo "diizinkan pada firewall provider/Ubuntu. Untuk Cloudflare DNS, gunakan DNS only."
read -r -p "Ketik SETUJU untuk melanjutkan: " CONFIRM
[[ "$CONFIRM" == "SETUJU" ]] || { echo "Dibatalkan."; exit 1; }

STAMP="$(date +%Y%m%d-%H%M%S)"
cp -a nginx/default.conf "nginx/default.conf.bak.$STAMP" 2>/dev/null || true
mkdir -p certbot/www

# Write HTTP bootstrap config so Let's Encrypt HTTP-01 can validate the domain.
cat > nginx/default.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type text/plain;
        try_files \$uri =404;
    }

    location / {
        return 200 "Nginx bootstrap is ready for HTTPS setup.\\n";
        add_header Content-Type text/plain;
    }
}
EOF

# docker-compose.yml is managed separately; this script must not rewrite it.

if ! docker compose config >/tmp/oracle-apex-compose-validate.yml; then
  echo "ERROR: docker compose config gagal. Backup: docker-compose.yml.bak.$STAMP"
  exit 1
fi

echo "Starting Compose stack with temporary HTTP bootstrap..."
docker compose up -d
docker compose exec -T nginx nginx -t

if ! command -v certbot >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y certbot
fi

CERTBOT_ARGS=(certonly --non-interactive --agree-tos --webroot -w "$PWD/certbot/www" -d "$DOMAIN")
if [[ -n "$EMAIL" ]]; then
  CERTBOT_ARGS+=(--email "$EMAIL")
else
  CERTBOT_ARGS+=(--register-unsafely-without-email)
fi

echo "Requesting Let's Encrypt certificate..."
if ! certbot "${CERTBOT_ARGS[@]}"; then
  echo "ERROR: Certbot gagal. Nginx masih dalam mode bootstrap HTTP."
  echo "Periksa DNS A, port 80 dari internet, dan firewall. Setelah diperbaiki, jalankan ulang script."
  exit 1
fi

CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
if [[ ! -s "$CERT_DIR/fullchain.pem" || ! -s "$CERT_DIR/privkey.pem" ]]; then
  echo "ERROR: Sertifikat tidak ditemukan di $CERT_DIR"
  exit 1
fi

cat > nginx/default.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
        default_type text/plain;
        try_files \$uri =404;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    # APEX static files: /i/example.js -> /usr/share/nginx/html/example.js
    location ^~ /i/ {
        alias /usr/share/nginx/html/;
        expires 7d;
        add_header Cache-Control "public";
        access_log off;
    }

    # Other paths (APEX pages, REST, SQL Developer Web, etc.) go to ORDS.
    location / {
        proxy_pass http://ords:8080;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

docker compose up -d
docker compose exec -T nginx nginx -t
docker compose exec -T nginx nginx -s reload || true

mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cat > /etc/letsencrypt/renewal-hooks/deploy/reload-apex-nginx.sh <<EOF
#!/usr/bin/env sh
cd "$PWD" || exit 1
docker compose exec -T nginx nginx -s reload
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-apex-nginx.sh

echo
echo "Setup selesai. Verifikasi:"
echo "  docker compose ps"
echo "  curl -I http://$DOMAIN/"
echo "  curl -I https://$DOMAIN/"
echo "  curl -I https://$DOMAIN/i/apex_version.txt"
echo "  docker ps --format 'table {{.Names}}\\t{{.Ports}}'"
echo
echo "Hasil akhir: hanya Nginx memublikasikan port 80/443; DB dan ORDS internal."
echo "docker-compose.yml was left unchanged by this script."
