#!/bin/sh
# Build an OpenWrt/LibreMesh .apk for ffj-onboard (PKGARCH=all) with apk mkpkg.
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck source=host-apk.sh
. "$ROOT/scripts/host-apk.sh"
host_apk

FILES="$ROOT/packages/ffj-onboard/files"
VERSION="${FFJ_ONBOARD_VERSION:-0.1.0}"
RELEASE="${FFJ_ONBOARD_RELEASE:-1}"
OUT_DIR="${1:-$ROOT/dist}"
PKG_NAME="ffj-onboard"
# apk-tools requires -rN for PKG_RELEASE (OpenWrt: 0.1.0-r1, not 0.1.0-1)
PKG_VER="${VERSION}-r${RELEASE}"
APK_NAME="${PKG_NAME}-${PKG_VER}.apk"
DEPENDS="lime-system ubus-lime-location luci-lib-jsonc libuci-lua libubus-lua uhttpd rpcd"

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

ROOTFS="$TMP/root"
SCRIPTS="$TMP/scripts"
mkdir -p "$ROOTFS" "$SCRIPTS" "$OUT_DIR" "$ROOTFS/lib/apk/packages"

cp -a "$FILES"/. "$ROOTFS/"
chmod 0755 "$ROOTFS/usr/libexec/rpcd/ffj-onboard"
chmod 0755 "$ROOTFS/etc/uci-defaults/97-ffj-onboard"

(
  cd "$ROOTFS"
  find . \( -type f -o -type l \) -printf '/%P\n' | sort >"$ROOTFS/lib/apk/packages/${PKG_NAME}.list"
)

cat >"$SCRIPTS/post-install" <<EOF
#!/bin/sh
[ "\${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s "\${IPKG_INSTROOT}/lib/functions.sh" ] || exit 0
. "\${IPKG_INSTROOT}/lib/functions.sh"
export root="\${IPKG_INSTROOT}"
export pkgname="${PKG_NAME}"
add_group_and_user
default_postinst
[ -n "\${IPKG_INSTROOT}" ] || {
	/etc/init.d/rpcd restart >/dev/null 2>&1 || true
	/etc/init.d/uhttpd restart >/dev/null 2>&1 || true
}
exit 0
EOF

{
  echo "#!/bin/sh"
  echo "export PKG_UPGRADE=1"
  sed '/^\s*#!/d' "$SCRIPTS/post-install"
} >"$SCRIPTS/post-upgrade"

cat >"$SCRIPTS/pre-deinstall" <<EOF
#!/bin/sh
[ -s "\${IPKG_INSTROOT}/lib/functions.sh" ] || exit 0
. "\${IPKG_INSTROOT}/lib/functions.sh"
export root="\${IPKG_INSTROOT}"
export pkgname="${PKG_NAME}"
default_prerm
EOF

chmod 0755 "$SCRIPTS/post-install" "$SCRIPTS/post-upgrade" "$SCRIPTS/pre-deinstall"

APK_PATH="$OUT_DIR/$APK_NAME"
rm -f "$APK_PATH"

cat >"$TMP/mkpkg.sh" <<EOF
#!/bin/sh
exec "$APK" mkpkg \\
  --info "name:${PKG_NAME}" \\
  --info "version:${PKG_VER}" \\
  --info "description:Freifunk Jena node onboard wizard (hostname, shared root password, location)" \\
  --info "arch:noarch" \\
  --info "license:AGPL-3.0-or-later" \\
  --info "maintainer:Freifunk Jena" \\
  --info "tags:openwrt:section=lime" \\
  --info "depends:${DEPENDS}" \\
  --script "post-install:${SCRIPTS}/post-install" \\
  --script "post-upgrade:${SCRIPTS}/post-upgrade" \\
  --script "pre-deinstall:${SCRIPTS}/pre-deinstall" \\
  --files "${ROOTFS}" \\
  --output "${APK_PATH}"
EOF
chmod 0755 "$TMP/mkpkg.sh"

if command -v fakeroot >/dev/null 2>&1; then
  fakeroot -- "$TMP/mkpkg.sh"
else
  "$TMP/mkpkg.sh"
fi

echo "Built $APK_PATH"
