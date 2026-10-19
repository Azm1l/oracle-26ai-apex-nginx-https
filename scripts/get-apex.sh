#!/usr/bin/env bash
# Download Oracle APEX, verify it against Oracle's published SHA256, and unzip
# it to ./apex, where the ORDS container installs (or upgrades) it on start.
#
#   ./scripts/get-apex.sh            # edition from .env (APEX_EDITION), default full
#   APEX_EDITION=en ./scripts/get-apex.sh
#
# To move to a newer APEX later: update the version and checksums below from
# https://www.oracle.com/tools/downloads/apex-downloads/, re-run this script,
# then `docker compose restart ords` - ORDS sees the newer files and upgrades.
set -euo pipefail
cd "$(dirname "$0")/.."

APEX_VERSION="26.2"
# From oracle.com/tools/downloads/apex-downloads (files re-released 2026-10-09).
SHA256_FULL="50e27e5451435aa79205acbcd22ee44353d36d96768634695eb01b93fa02d782"
SHA256_EN="9b94ef21c2c33bb4a48488e44435d528768944af68e12002751fe70891c44e01"

if [[ -z "${APEX_EDITION:-}" && -f .env ]]; then
  APEX_EDITION=$(grep -E '^APEX_EDITION=' .env | cut -d= -f2 | tr -d '\r' || true)
fi
case "${APEX_EDITION:-full}" in
  full) ZIP="apex_${APEX_VERSION}.zip";    SHA="$SHA256_FULL" ;;
  en)   ZIP="apex_${APEX_VERSION}_en.zip"; SHA="$SHA256_EN" ;;
  *)    echo "APEX_EDITION must be 'full' or 'en'" >&2; exit 1 ;;
esac

mkdir -p downloads
if [[ ! -f "downloads/${ZIP}" ]]; then
  echo "-> Downloading ${ZIP} ..."
  curl -fL --retry 3 -o "downloads/${ZIP}.part" "https://download.oracle.com/otn_software/apex/${ZIP}"
  mv "downloads/${ZIP}.part" "downloads/${ZIP}"
fi

echo "-> Verifying SHA256 ..."
if command -v sha256sum >/dev/null; then
  ACTUAL=$(sha256sum "downloads/${ZIP}" | cut -d' ' -f1)
else
  ACTUAL=$(shasum -a 256 "downloads/${ZIP}" | cut -d' ' -f1)
fi
if [[ "$ACTUAL" != "$SHA" ]]; then
  echo "SHA256 mismatch for ${ZIP}: expected $SHA, got $ACTUAL" >&2
  echo "Delete downloads/${ZIP} and try again; if it persists, compare with Oracle's download page." >&2
  exit 1
fi

# Replace, never merge: leftover files from an older release would make the
# installer's version check read the wrong release.
echo "-> Unzipping to ./apex ..."
rm -rf apex.new && mkdir apex.new
unzip -q "downloads/${ZIP}" -d apex.new
rm -rf apex && mv apex.new/apex apex && rm -rf apex.new

echo "OK: APEX ${APEX_VERSION} (${APEX_EDITION:-full}) is ready in ./apex"
echo "Next: docker compose up -d   (first start installs ORDS + APEX: 15-25 minutes)"