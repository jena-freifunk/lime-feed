#!/bin/sh
# Generate usign keypair for the package feed (do not commit feed.priv).
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
KEYS="$ROOT/keys"
mkdir -p "$KEYS"

if [ -f "$KEYS/feed.priv" ]; then
  echo "keys/feed.priv already exists — refusing to overwrite" >&2
  exit 1
fi

if command -v usign >/dev/null 2>&1; then
  usign -G -s "$KEYS/feed.priv" -p "$KEYS/feed.pub" -c "lime-feed"
elif command -v openssl >/dev/null 2>&1; then
  # Fallback documentation key material for ASU PEM-style entries
  openssl ecparam -name prime256v1 -genkey -noout -out "$KEYS/feed.pem"
  openssl ec -in "$KEYS/feed.pem" -pubout -out "$KEYS/feed.pub.pem"
  echo "Generated OpenSSL EC keypair (feed.pem / feed.pub.pem)."
  echo "Prefer 'usign' for OpenWrt opkg feeds when available."
  exit 0
else
  echo "Install usign or openssl to generate keys" >&2
  exit 1
fi

echo "Wrote $KEYS/feed.priv and $KEYS/feed.pub"
echo "Add the contents of feed.pub to firmware-selector asu_repository_keys."
echo "Store feed.priv as a GitHub Actions secret (FFJ_FEED_PRIV); never commit it."
