#!/bin/sh
# Build package + static feed tree suitable for GitHub Pages.
# Produces dist/feed/ with .ipk, .apk, Packages, Packages.gz, and packages.adb when apk is available.
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/dist/feed}"
VERSION="${FFJ_ONBOARD_VERSION:-0.1.0}"
RELEASE="${FFJ_ONBOARD_RELEASE:-1}"
IPK_VER="${VERSION}-${RELEASE}"
APK_VER="${VERSION}-r${RELEASE}"

"$ROOT/scripts/build-ipk.sh" "$ROOT/dist"
"$ROOT/scripts/build-apk.sh" "$ROOT/dist"

mkdir -p "$OUT"
cp -a "$ROOT/dist"/ffj-onboard_*.ipk "$OUT/"
cp -a "$ROOT/dist"/ffj-onboard-*.apk "$OUT/"

{
  echo "Package: ffj-onboard"
  echo "Version: ${IPK_VER}"
  echo "Depends: lime-system, ubus-lime-location, luci-lib-jsonc, libuci-lua, libubus-lua, uhttpd, rpcd"
  echo "Section: lime"
  echo "Architecture: all"
  echo "Filename: ffj-onboard_${IPK_VER}_all.ipk"
  IPK="$OUT/ffj-onboard_${IPK_VER}_all.ipk"
  echo "Size: $(wc -c < "$IPK" | tr -d ' ')"
  if command -v sha256sum >/dev/null; then
    echo "SHA256sum: $(sha256sum "$IPK" | cut -d' ' -f1)"
  fi
  echo "Description: Freifunk Jena node onboard wizard"
  echo
} > "$OUT/Packages"

gzip -9c "$OUT/Packages" > "$OUT/Packages.gz"

# shellcheck source=host-apk.sh
. "$ROOT/scripts/host-apk.sh"
if host_apk; then
  (
    cd "$OUT"
    "$APK" mkndx --allow-untrusted -o packages.adb ./*.apk
  )
  rm -f "$OUT/FEED.txt"
fi

if [ ! -f "$OUT/packages.adb" ]; then
  cat > "$OUT/FEED.txt" <<EOF
opkg feed files: Packages Packages.gz *.ipk

For LibreMesh ASU (packages.adb): rebuild this feed with apk-tools v3
(apk mkpkg / apk mkndx) and publish packages.adb next to the .apk, then point
asu_repositories.lime_feed at:

  https://<org>.github.io/lime-feed/packages.adb
EOF
fi

if [ -f "$ROOT/keys/feed.priv" ] && command -v usign >/dev/null 2>&1; then
  usign -S -m "$OUT/Packages" -s "$ROOT/keys/feed.priv" -x "$OUT/Packages.sig"
fi

cat > "$OUT/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>lime-feed</title></head>
<body>
  <h1>lime-feed</h1>
  <p>Freifunk Jena package feed for LibreMesh.</p>
  <ul>
    <li><a href="Packages">Packages</a></li>
    <li><a href="Packages.gz">Packages.gz</a></li>
    <li><a href="ffj-onboard_${IPK_VER}_all.ipk">ffj-onboard_${IPK_VER}_all.ipk</a></li>
    <li><a href="ffj-onboard-${APK_VER}.apk">ffj-onboard-${APK_VER}.apk</a></li>
    <li><a href="packages.adb">packages.adb</a></li>
  </ul>
  <p>LibreMesh ASU: use <code>packages.adb</code> as <code>asu_repositories.lime_feed</code>.</p>
</body>
</html>
EOF

echo "Feed ready at $OUT"
ls -la "$OUT"
