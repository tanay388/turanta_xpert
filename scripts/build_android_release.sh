#!/usr/bin/env bash
# Builds a signed Android release (AAB for Play Store, or APK for sideload).
#
# Usage (from turanta_xpert/):
#   ./scripts/build_android_release.sh          # appbundle (default)
#   ./scripts/build_android_release.sh aab
#   ./scripts/build_android_release.sh apk
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FORMAT="${1:-aab}"
PROPS="android/key.properties"
KEYSTORE_HINT="android/upload-keystore.jks"

if [[ ! -f "$PROPS" ]]; then
  echo "Missing $PROPS — release would fall back to debug signing."
  echo "Run: ./scripts/create_upload_keystore.sh"
  exit 1
fi
if [[ ! -f "$KEYSTORE_HINT" ]]; then
  # storeFile path is relative to android/; still warn if default missing
  echo "Warning: $KEYSTORE_HINT not found. Check storeFile in key.properties."
fi

case "$FORMAT" in
  aab|appbundle|bundle)
    echo "Building signed App Bundle (Play Store)…"
    flutter build appbundle --release
    echo
    echo "Output: build/app/outputs/bundle/release/app-release.aab"
    ;;
  apk)
    echo "Building signed APK…"
    flutter build apk --release
    echo
    echo "Output: build/app/outputs/flutter-apk/app-release.apk"
    ;;
  *)
    echo "Usage: $0 [aab|apk]"
    exit 1
    ;;
esac
