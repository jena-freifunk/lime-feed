#!/usr/bin/env bash
# Build OpenWrt .ipk packages (PKGARCH=all) without a full SDK.
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck source=load-pkg.sh
. "$ROOT/scripts/load-pkg.sh"

OUT_DIR="${1:-$ROOT/dist}"
ARCH="all"

command -v tar >/dev/null
command -v gzip >/dev/null

build_ipk() {
  local pkg_dir="$1"
  load_pkg_makefile "$pkg_dir/Makefile"
  local files="$pkg_dir/files"
  local ipk_name="${PKG_NAME}_${PKG_VERSION}-${PKG_RELEASE}_${ARCH}.ipk"

  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/data" "$tmp/control" "$OUT_DIR"
  cp -a "$files"/. "$tmp/data/"
  if [ -d "$tmp/data/etc/uci-defaults" ]; then
    find "$tmp/data/etc/uci-defaults" -type f -exec chmod 0755 {} +
  fi
  if [ -d "$tmp/data/usr/libexec/rpcd" ]; then
    find "$tmp/data/usr/libexec/rpcd" -type f -exec chmod 0755 {} +
  fi
  if [ -f "$tmp/data/etc/dropbear/authorized_keys" ]; then
    chmod 0600 "$tmp/data/etc/dropbear/authorized_keys"
  fi

  local size
  size="$(du -sk "$tmp/data" | cut -f1)"

  cat > "$tmp/control/control" <<EOF
Package: ${PKG_NAME}
Version: ${PKG_VERSION}-${PKG_RELEASE}
Depends: ${PKG_DEPENDS_IPK}
Section: lime
Category: LibreMesh
Architecture: ${ARCH}
Installed-Size: ${size}
Description:  ${PKG_TITLE}
EOF

  echo "2.0" > "$tmp/debian-binary"

  (
    cd "$tmp/control"
    tar --format=gnu -czf "$tmp/control.tar.gz" .
  )
  (
    cd "$tmp/data"
    tar --format=gnu -czf "$tmp/data.tar.gz" .
  )

  local ipk_path="$OUT_DIR/$ipk_name"
  rm -f "$ipk_path"
  (
    cd "$tmp"
    if command -v ar >/dev/null 2>&1; then
      ar rc "$ipk_path" debian-binary control.tar.gz data.tar.gz
    else
      echo "error: 'ar' (binutils) is required to build .ipk" >&2
      exit 1
    fi
  )

  rm -rf "$tmp"
  echo "Built $ipk_path"
}

for dir in $(pkg_dirs "$ROOT"); do
  build_ipk "$dir"
done
