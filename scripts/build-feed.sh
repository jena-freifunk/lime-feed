#!/usr/bin/env bash
# Build packages + static feed tree suitable for GitHub Pages.
# Produces dist/feed/ with .ipk, .apk, Packages, Packages.gz, and packages.adb when apk is available.
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
# shellcheck source=load-pkg.sh
. "$ROOT/scripts/load-pkg.sh"

OUT="${1:-$ROOT/dist/feed}"
SIGN_KEY="${FFJ_FEED_KEY:-$ROOT/keys/feed.pem}"
[ -f "$SIGN_KEY" ] || SIGN_KEY=""

"$ROOT/scripts/build-ipk.sh" "$ROOT/dist"
"$ROOT/scripts/build-apk.sh" "$ROOT/dist"

mkdir -p "$OUT"
shopt -s nullglob
cp -a "$ROOT/dist"/*.ipk "$OUT/" 2>/dev/null || true
cp -a "$ROOT/dist"/*.apk "$OUT/" 2>/dev/null || true

: > "$OUT/Packages"
for dir in $(pkg_dirs "$ROOT"); do
  load_pkg_makefile "$dir/Makefile"
  ipk_ver="${PKG_VERSION}-${PKG_RELEASE}"
  ipk="$OUT/${PKG_NAME}_${ipk_ver}_all.ipk"
  {
    echo "Package: ${PKG_NAME}"
    echo "Version: ${ipk_ver}"
    echo "Depends: ${PKG_DEPENDS_IPK}"
    echo "Section: lime"
    echo "Architecture: all"
    echo "Filename: ${PKG_NAME}_${ipk_ver}_all.ipk"
    echo "Size: $(wc -c < "$ipk" | tr -d ' ')"
    if command -v sha256sum >/dev/null; then
      echo "SHA256sum: $(sha256sum "$ipk" | cut -d' ' -f1)"
    fi
    echo "Description: ${PKG_TITLE}"
    echo
  } >> "$OUT/Packages"
done

gzip -9c "$OUT/Packages" > "$OUT/Packages.gz"

# shellcheck source=host-apk.sh
. "$ROOT/scripts/host-apk.sh"
if host_apk; then
  (
    cd "$OUT"
    "$APK" --allow-untrusted ${SIGN_KEY:+--sign-key "$SIGN_KEY"} mkndx -o packages.adb ./*.apk
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

{
  echo '<!DOCTYPE html>'
  echo '<html lang="en">'
  echo '<head><meta charset="utf-8"><title>lime-feed</title></head>'
  echo '<body>'
  echo '  <h1>lime-feed</h1>'
  echo '  <p>Freifunk Jena package feed for LibreMesh.</p>'
  echo '  <ul>'
  echo '    <li><a href="Packages">Packages</a></li>'
  echo '    <li><a href="Packages.gz">Packages.gz</a></li>'
  for f in "$OUT"/*.ipk "$OUT"/*.apk; do
    [ -f "$f" ] || continue
    b="$(basename "$f")"
    echo "    <li><a href=\"$b\">$b</a></li>"
  done
  echo '    <li><a href="packages.adb">packages.adb</a></li>'
  echo '  </ul>'
  echo '  <p>LibreMesh ASU: use <code>packages.adb</code> as <code>asu_repositories.lime_feed</code>.</p>'
  echo '</body>'
  echo '</html>'
} > "$OUT/index.html"

echo "Feed ready at $OUT"
ls -la "$OUT"
