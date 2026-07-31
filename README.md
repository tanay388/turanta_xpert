# Turanta Xpert

Partner / expert Flutter app for Turanta — phone OTP login and daily check-in / check-out.

## Stack

- Flutter + Riverpod (`hooks_riverpod`) + `go_router`
- Firebase Auth (phone OTP), Core, Messaging, Crashlytics, Analytics
- **No** `shared_ui_kit` — UI is built in-app

## Partner registration flow

After Firebase OTP, the app calls NestJS:

```http
GET /user?role=partner
Authorization: Bearer <firebase_id_token>
device-id: <uuid>
device-platform: ios|android
device-brand: ...
device-model: ...
os-version: ...
app-version: ...
notification-token: <optional fcm>
```

- New accounts are created as `role=partner`, `status=pending_approval`
- Device details are stored on `user_device` (single active device for partners)
- Then KYC wizard → `PUT /partner/kyc` → pending approval screen
- Home / check-in unlocks only when admin sets `status=active`

API base URL defaults to `http://localhost:3000` (iOS sim) / `http://10.0.2.2:3000` (Android emulator). Override with `--dart-define=API_BASE_URL=...`.

## Run

```bash
cd turanta_xpert
flutter pub get
flutter run
```

## Fix iOS Phone Auth crash (`PhoneAuthProvider.swift` nil unwrap)

If Send OTP crashes on the iOS Simulator, Firebase Phone Auth is missing its URL scheme / client IDs.

1. Firebase Console → **Authentication → Sign-in method**
2. Enable **Phone** (required)
3. Enable **Google** as well (even if you only use phone) — this adds `CLIENT_ID` / `REVERSED_CLIENT_ID` to the iOS plist
4. Re-download `GoogleService-Info.plist` for the Xpert iOS app, or re-run:

```bash
cd turanta_xpert
flutterfire configure
```

5. Open the new plist, copy `REVERSED_CLIENT_ID`, and add it under `CFBundleURLSchemes` in `ios/Runner/Info.plist` (alongside the existing `app-1-…` scheme).
6. Full rebuild (Info.plist changes need a clean run):

```bash
flutter clean
flutter run
```

### Simulator tip

On Simulator, prefer Firebase **test phone numbers** (Authentication → Phone → Phone numbers for testing) so you skip SMS/reCAPTCHA. Example: `+91 99999 99999` / code `123456`.


Do this once before phone OTP will work. The repo ships a **placeholder** `lib/firebase_options.dart`.

### 1. Prerequisites

- [Firebase CLI](https://firebase.google.com/docs/cli) installed and logged in
- [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup)

```bash
# Login to Firebase (browser)
firebase login

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Ensure ~/.pub-cache/bin is on your PATH
export PATH="$PATH:$HOME/.pub-cache/bin"
```

### 2. Create or pick a Firebase project

In [Firebase Console](https://console.firebase.google.com/):

1. Create a project (e.g. `turanta-xpert`) **or** reuse an existing Turanta project.
2. Enable **Authentication → Sign-in method → Phone**.
3. (Android) Add an Android app with package name: `com.turanta.turanta_xpert`
4. (iOS) Add an iOS app with bundle id: `com.turanta.turantaXpert`
5. Download / register SHA-1 for Android debug builds if phone auth requires it:

```bash
cd android
./gradlew signingReport
# Copy SHA-1 from debug variant into Firebase Console → Project settings → Your apps
```

### 3. Run FlutterFire configure

From the `turanta_xpert` directory:

```bash
cd turanta_xpert
flutterfire configure
```

You will be prompted to:

1. Select the Firebase project
2. Select platforms (`android`, `ios`)
3. Confirm app ids / create apps if needed

This **overwrites** `lib/firebase_options.dart` and writes:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Then ensure Android Gradle plugins are applied in `android/app/build.gradle.kts`:

```kotlin
plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
```

(`android/settings.gradle.kts` already declares the plugin versions.)

### 4. Verify

```bash
flutter clean
flutter pub get
flutter run
```

Phone OTP should send SMS after Firebase Phone Auth is enabled and the device/emulator can reach Firebase.

### Optional: same Firebase project as `turanta_user`

If experts and users share one Firebase project, run `flutterfire configure` against that project and register a **second** Android/iOS app for Xpert (different package / bundle id). Auth users are shared; your backend should still resolve partners via `GET /partners/me` (or equivalent) using the Firebase ID token.

## App flow (v1 UI)

1. Splash → Login (phone) → OTP → Home
2. Home: **Check in / Check out** toggle (local for now; wire to `POST /partners/me/availability` next)
3. Today stats + quick actions placeholders
