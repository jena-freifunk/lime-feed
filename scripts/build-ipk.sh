#!/usr/bin/env bash
# Build an OpenWrt .ipk for ffj-onboard (PKGARCH=all) without a full SDK.
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
PKG_SRC="$ROOT/packages/ffj-onboard"
FILES="$PKG_SRC/files"
VERSION="${FFJ_ONBOARD_VERSION:-0.1.0}"
RELEASE="${FFJ_ONBOARD_RELEASE:-1}"
OUT_DIR="${1:-$ROOT/dist}"
PKG_NAME="ffj-onboard"
ARCH="all"
IPK_NAME="${PKG_NAME}_${VERSION}-${RELEASE}_${ARCH}.ipk"

command -v tar >/dev/null
command -v gzip >/dev/null

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$TMP/data" "$TMP/control" "$OUT_DIR"
cp -a "$FILES"/. "$TMP/data/"
chmod 0755 "$TMP/data/usr/libexec/rpcd/ffj-onboard"
chmod 0755 "$TMP/data/etc/uci-defaults/97-ffj-onboard"

SIZE="$(du -sk "$TMP/data" | cut -f1)"

cat > "$TMP/control/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}-${RELEASE}
Depends: lime-system, ubus-lime-location, luci-lib-jsonc, libuci-lua, libubus-lua, uhttpd, rpcd
Section: lime
Category: LibreMesh
Architecture: ${ARCH}
Installed-Size: ${SIZE}
Description:  Freifunk Jena node onboard wizard (hostname, shared root password, location)
EOF

echo "2.0" > "$TMP/debian-binary"

(
  cd "$TMP/control"
  tar --format=gnu -czf "$TMP/control.tar.gz" .
)
(
  cd "$TMP/data"
  tar --format=gnu -czf "$TMP/data.tar.gz" .
)

IPK_PATH="$OUT_DIR/$IPK_NAME"
rm -f "$IPK_PATH"
(
  cd "$TMP"
  if command -v ar >/dev/null 2>&1; then
    ar rc "$IPK_PATH" debian-binary control.tar.gz data.tar.gz
  else
    # Fallback: BusyBox/GNU tar "ipk" as concatenated gzip members is invalid;
    # require binutils ar for a real .ipk
    echo "error: 'ar' (binutils) is required to build .ipk" >&2
    exit 1
  fi
)

echo "Built $IPK_PATH"
