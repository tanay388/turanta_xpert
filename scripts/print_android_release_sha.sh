#!/usr/bin/env bash
# Prints SHA-1 and SHA-256 for the release upload keystore.
# Add BOTH to Firebase Console → Project settings → your Android app → SHA certificate fingerprints
# and to Google Maps Android API key → Application restrictions.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_DIR="$ROOT/android"
PROPS="$ANDROID_DIR/key.properties"

if [[ ! -f "$PROPS" ]]; then
  echo "Missing $PROPS"
  echo "Run ./scripts/create_upload_keystore.sh first (or copy key.properties.example → key.properties)."
  exit 1
fi

# shellcheck disable=SC1090
storePassword=""
keyPassword=""
keyAlias=""
storeFile=""
while IFS='=' read -r key value; do
  [[ -z "${key:-}" || "$key" =~ ^# ]] && continue
  case "$key" in
    storePassword) storePassword="$value" ;;
    keyPassword) keyPassword="$value" ;;
    keyAlias) keyAlias="$value" ;;
    storeFile) storeFile="$value" ;;
  esac
done < "$PROPS"

KEYSTORE="$ANDROID_DIR/$storeFile"
if [[ ! -f "$KEYSTORE" ]]; then
  echo "Keystore not found: $KEYSTORE"
  exit 1
fi

echo "Package tip: com.turanta.turanta_xpert"
echo "Keystore: $KEYSTORE"
echo "Alias:    $keyAlias"
echo
keytool -list -v \
  -keystore "$KEYSTORE" \
  -alias "$keyAlias" \
  -storepass "$storePassword" \
  -keypass "$keyPassword" 2>/dev/null \
  | grep -E 'SHA1:|SHA-1:|SHA256:|SHA-256:'
