#!/usr/bin/env bash
# Build OpenWrt/LibreMesh .apk packages (PKGARCH=all) with apk mkpkg.
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck source=host-apk.sh
. "$ROOT/scripts/host-apk.sh"
# shellcheck source=load-pkg.sh
. "$ROOT/scripts/load-pkg.sh"
host_apk

OUT_DIR="${1:-$ROOT/dist}"
SIGN_KEY="${FFJ_FEED_KEY:-$ROOT/keys/feed.pem}"
[ -f "$SIGN_KEY" ] || SIGN_KEY=""

build_apk() {
  local pkg_dir="$1"
  load_pkg_makefile "$pkg_dir/Makefile"
  local files="$pkg_dir/files"
  local pkg_ver="${PKG_VERSION}-r${PKG_RELEASE}"
  local apk_name="${PKG_NAME}-${pkg_ver}.apk"

  local tmp rootfs scripts
  tmp="$(mktemp -d)"
  rootfs="$tmp/root"
  scripts="$tmp/scripts"
  mkdir -p "$rootfs" "$scripts" "$OUT_DIR" "$rootfs/lib/apk/packages"

  cp -a "$files"/. "$rootfs/"
  if [ -d "$rootfs/etc/uci-defaults" ]; then
    find "$rootfs/etc/uci-defaults" -type f -exec chmod 0755 {} +
  fi
  if [ -d "$rootfs/usr/libexec/rpcd" ]; then
    find "$rootfs/usr/libexec/rpcd" -type f -exec chmod 0755 {} +
  fi
  if [ -f "$rootfs/etc/dropbear/authorized_keys" ]; then
    chmod 0600 "$rootfs/etc/dropbear/authorized_keys"
  fi

  (
    cd "$rootfs"
    find . \( -type f -o -type l \) -printf '/%P\n' | sort >"$rootfs/lib/apk/packages/${PKG_NAME}.list"
  )

  cat >"$scripts/post-install" <<EOF
#!/bin/sh
[ "\${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s "\${IPKG_INSTROOT}/lib/functions.sh" ] || exit 0
. "\${IPKG_INSTROOT}/lib/functions.sh"
export root="\${IPKG_INSTROOT}"
export pkgname="${PKG_NAME}"
add_group_and_user
default_postinst
EOF
  if [ -d "$rootfs/usr/libexec/rpcd" ]; then
    cat >>"$scripts/post-install" <<'EOF'
[ -n "${IPKG_INSTROOT}" ] || {
	/etc/init.d/rpcd restart >/dev/null 2>&1 || true
	/etc/init.d/uhttpd restart >/dev/null 2>&1 || true
}
EOF
  fi
  echo 'exit 0' >>"$scripts/post-install"

  {
    echo "#!/bin/sh"
    echo "export PKG_UPGRADE=1"
    sed '/^\s*#!/d' "$scripts/post-install"
  } >"$scripts/post-upgrade"

  cat >"$scripts/pre-deinstall" <<EOF
#!/bin/sh
[ -s "\${IPKG_INSTROOT}/lib/functions.sh" ] || exit 0
. "\${IPKG_INSTROOT}/lib/functions.sh"
export root="\${IPKG_INSTROOT}"
export pkgname="${PKG_NAME}"
default_prerm
EOF

  chmod 0755 "$scripts/post-install" "$scripts/post-upgrade" "$scripts/pre-deinstall"

  local apk_path="$OUT_DIR/$apk_name"
  rm -f "$apk_path"

  cat >"$tmp/mkpkg.sh" <<EOF
#!/bin/sh
exec "$APK" ${SIGN_KEY:+--sign-key "$SIGN_KEY"} mkpkg \\
  --info "name:${PKG_NAME}" \\
  --info "version:${pkg_ver}" \\
  --info "description:${PKG_TITLE}" \\
  --info "arch:noarch" \\
  --info "license:${PKG_LICENSE}" \\
  --info "maintainer:${PKG_MAINTAINER}" \\
  --info "tags:openwrt:section=lime" \\
  --info "depends:${PKG_DEPENDS_APK}" \\
  --script "post-install:${scripts}/post-install" \\
  --script "post-upgrade:${scripts}/post-upgrade" \\
  --script "pre-deinstall:${scripts}/pre-deinstall" \\
  --files "${rootfs}" \\
  --output "${apk_path}"
EOF
  chmod 0755 "$tmp/mkpkg.sh"

  if command -v fakeroot >/dev/null 2>&1; then
    fakeroot -- "$tmp/mkpkg.sh"
  else
    "$tmp/mkpkg.sh"
  fi

  rm -rf "$tmp"
  echo "Built $apk_path"
}

for dir in $(pkg_dirs "$ROOT"); do
  build_apk "$dir"
done
