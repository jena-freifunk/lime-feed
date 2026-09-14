# shellcheck shell=sh
# Resolve host apk-tools v3 (mkpkg / mkndx). Source this file; do not execute.

host_apk() {
  APK="${APK_BIN:-apk}"
  if ! command -v "$APK" >/dev/null 2>&1 && [ ! -x "$APK" ]; then
    echo "error: apk-tools v3 not found (need mkpkg). Install it or set APK_BIN." >&2
    return 1
  fi
  if ! "$APK" --version >/dev/null 2>&1; then
    libdir=""
    for d in \
      ${APK_LIBDIR:+"$APK_LIBDIR"} \
      "$HOME/apk-tools/build/src" \
      /usr/local/lib \
      /usr/local/lib/x86_64-linux-gnu
    do
      if [ -f "$d/libapk.so.3.0.0" ]; then
        libdir="$d"
        break
      fi
    done
    if [ -z "$libdir" ]; then
      echo "error: $APK cannot load libapk.so.3.0.0. Set APK_LIBDIR to the directory that contains it." >&2
      return 1
    fi
    export LD_LIBRARY_PATH="$libdir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  fi
  "$APK" --version >/dev/null
}
