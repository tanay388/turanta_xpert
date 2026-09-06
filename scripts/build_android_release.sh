#!/usr/bin/env bash
# Builds a signed Android release (AAB for Play Store, and/or APK for sideload).
#
# Usage (from turanta_xpert/):
#   ./scripts/build_android_release.sh          # both aab + apk (default)
#   ./scripts/build_android_release.sh both
#   ./scripts/build_android_release.sh aab
#   ./scripts/build_android_release.sh apk
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FORMAT="${1:-both}"
PROPS="android/key.properties"
KEYSTORE_HINT="android/upload-keystore.jks"

if [[ ! -f "$PROPS" ]]; then
  echo "Missing $PROPS — release would fall back to debug signing."
  echo "Run: ./scripts/create_upload_keystore.sh"
  exit 1
fi
if [[ ! -f "$KEYSTORE_HINT" ]]; then
  echo "Warning: $KEYSTORE_HINT not found. Check storeFile in key.properties."
fi

# Stale Gradle daemons on Apple Silicon can JVM-crash mid-release
# ("Field too big for insn" / daemon disappeared). Start clean.
stop_gradle_daemons() {
  echo "Stopping Gradle daemons…"
  (cd android && ./gradlew --stop) || true
  rm -f android/hs_err_pid*.log
  # Let the daemon registry finish processing --stop before bundleRelease starts.
  sleep 2
}

# Retry once on transient "daemon has been stopped" failures.
run_flutter_build() {
  local attempt
  for attempt in 1 2; do
    if "$@"; then
      return 0
    fi
    if (( attempt == 1 )); then
      echo "Build failed; waiting for Gradle to settle, then retrying…"
      sleep 3
    fi
  done
  return 1
}

stop_gradle_daemons

build_aab() {
  echo "Building signed App Bundle (Play Store)…"
  run_flutter_build flutter build appbundle --release
  echo "  → build/app/outputs/bundle/release/app-release.aab"
}

build_apk() {
  echo "Building signed APK…"
  run_flutter_build flutter build apk --release
  echo "  → build/app/outputs/flutter-apk/app-release.apk"
}

case "$FORMAT" in
  aab|appbundle|bundle)
    build_aab
    ;;
  apk)
    build_apk
    ;;
  both|all)
    build_aab
    echo
    build_apk
    ;;
  *)
    echo "Usage: $0 [both|aab|apk]"
    exit 1
    ;;
esac

echo
echo "Done."
