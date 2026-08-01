#!/usr/bin/env bash
# Prints SHA-1 and SHA-256 fingerprints for the Android debug keystore.
# Add these to Google Cloud Console → APIs & Services → Credentials → your Android API key:
#   Application restrictions → Android apps
#   Package: com.turanta.turanta_xpert
#   SHA-1 / SHA-256: (output below)
#
# Also add the same fingerprints in Firebase → Project settings → Android app.
# For production, ALSO add upload-key + Play App Signing SHAs
# (see ./print_android_release_sha.sh).
set -euo pipefail
KEYSTORE="${HOME}/.android/debug.keystore"
if [[ ! -f "$KEYSTORE" ]]; then
  echo "Debug keystore not found at $KEYSTORE"
  exit 1
fi
keytool -list -v -keystore "$KEYSTORE" -alias androiddebugkey -storepass android -keypass android 2>/dev/null \
  | grep -E 'SHA1:|SHA-1:|SHA256:|SHA-256:'
