#!/usr/bin/env bash
# Creates an Android upload keystore for Play Store / Firebase release signing.
#
# Best practice:
#   - One upload keystore PER app (user vs xpert).
#   - Enroll Google Play App Signing (Play holds the app signing key).
#   - Never commit *.jks / key.properties — store backups in a password manager.
#   - Register in Firebase + Maps API key:
#       1) Debug SHA (local) — from print_android_debug_sha.sh
#       2) Upload key SHA — from this keystore (print_android_release_sha.sh)
#       3) Play App Signing SHA — from Play Console → App integrity → App signing
#
# Usage (from app root, e.g. turanta_xpert/):
#   ./scripts/create_upload_keystore.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_DIR="$ROOT/android"
KEYSTORE="$ANDROID_DIR/upload-keystore.jks"
PROPS="$ANDROID_DIR/key.properties"
ALIAS="${KEY_ALIAS:-upload}"

if [[ -f "$KEYSTORE" ]]; then
  echo "Keystore already exists: $KEYSTORE"
  echo "Delete it first if you intentionally want to rotate (update Firebase/Play after)."
  exit 1
fi

echo "Creating upload keystore at:"
echo "  $KEYSTORE"
echo
echo "You will be prompted for:"
echo "  - keystore password (storePassword)"
echo "  - key password (keyPassword) — can match store password"
echo "  - name / org details (can be Turanta / your legal entity)"
echo

keytool -genkey -v \
  -keystore "$KEYSTORE" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias "$ALIAS"

read -r -s -p "Re-enter store password (to write key.properties): " STORE_PASS
echo
read -r -s -p "Re-enter key password: " KEY_PASS
echo

cat > "$PROPS" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$ALIAS
storeFile=upload-keystore.jks
EOF

chmod 600 "$PROPS" "$KEYSTORE"

echo
echo "Wrote $PROPS (gitignored)."
echo "Print release fingerprints with:"
echo "  ./scripts/print_android_release_sha.sh"
echo
echo "Next:"
echo "  1. Backup $KEYSTORE + passwords in 1Password/Bitwarden"
echo "  2. Add SHA-1/SHA-256 to Firebase Android app + Maps API key restrictions"
echo "  3. Build: ./scripts/build_android_release.sh aab"
