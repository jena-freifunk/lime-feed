# SPDX-License-Identifier: AGPL-3.0-or-later
# shellcheck shell=bash
# Load PKG_* from an OpenWrt package Makefile. Source from build scripts.

load_pkg_makefile() {
  local makefile="$1"
  PKG_NAME="$(sed -n 's/^PKG_NAME:=//p' "$makefile" | head -n1)"
  PKG_VERSION="$(sed -n 's/^PKG_VERSION:=//p' "$makefile" | head -n1)"
  PKG_RELEASE="$(sed -n 's/^PKG_RELEASE:=//p' "$makefile" | head -n1)"
  PKG_LICENSE="$(sed -n 's/^PKG_LICENSE:=//p' "$makefile" | head -n1)"
  PKG_MAINTAINER="$(sed -n 's/^PKG_MAINTAINER:=//p' "$makefile" | head -n1)"
  PKG_TITLE="$(sed -n 's/^[[:space:]]*TITLE:=//p' "$makefile" | head -n1)"
  PKG_DESCRIPTION="$(sed -n 's/^[[:space:]]*TITLE:=//p' "$makefile" | head -n1)"
  local depends
  depends="$(sed -n 's/^[[:space:]]*DEPENDS:=//p' "$makefile" | head -n1)"
  depends="${depends//+/}"
  PKG_DEPENDS_APK="$(echo "$depends" | awk '{$1=$1};1')"
  PKG_DEPENDS_IPK="$(echo "$PKG_DEPENDS_APK" | sed 's/ /, /g')"
}

pkg_dirs() {
  local root="$1"
  find "$root/packages" -mindepth 1 -maxdepth 1 -type d | sort
}
