# 🚀 V Shots — Deployment Guide

This guide details the steps required to build, test, and release the **V Shots** Android application (`com.vshots.live`) to Google Play Store and CI/CD pipelines.

---

## 📋 Table of Contents

1. [Environment & Prerequisites](#1-environment--prerequisites)
2. [Local Release Build](#2-local-release-build)
3. [Keystore Generation & Management](#3-keystore-generation--management)
4. [GitHub Actions CI/CD Setup](#4-github-actions-cicd-setup)
5. [BrowserStack Real-Device Testing](#5-browserstack-real-device-testing)
6. [Google Play Console Deployment](#6-google-play-console-deployment)

---

## 1. Environment & Prerequisites

- **Flutter SDK:** `>= 3.44.0` (Dart `>= 3.10.0`)
- **Java Development Kit:** JDK 17 (Temurin recommended)
- **Android Target SDK:** `36` (Min SDK `24`)
- **Gradle Version:** `8.9` / AGP `8.9.0`

---

## 2. Local Release Build

### A. Debug APK (For fast local testing)

```bash
flutter build apk --debug
```
The output file is located at `build/app/outputs/flutter-apk/app-debug.apk`.

### B. Release Android App Bundle (AAB)

To generate an optimized Play Store bundle:

```bash
export ANDROID_KEYSTORE_PATH="/path/to/release.keystore"
export ANDROID_KEYSTORE_PASSWORD="your_store_password"
export ANDROID_KEY_ALIAS="your_key_alias"
export ANDROID_KEY_PASSWORD="your_key_password"

flutter build appbundle --release
```
The output file is located at `build/app/outputs/bundle/release/app-release.aab`.

---

## 3. Keystore Generation & Management

To generate a new release signing keystore:

```bash
keytool -genkey -v -keystore release.keystore \
  -alias vshots \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storetype JKS
```

### Encode for CI/CD Secrets:
```bash
base64 -w 0 release.keystore > keystore_base64.txt
```
Copy the contents into the `ANDROID_KEYSTORE_BASE64` secret in GitHub.

---

## 4. GitHub Actions CI/CD Setup

Configure the following GitHub Secrets under **Repository Settings → Secrets and variables → Actions**:

| Secret Name | Purpose | Example |
| :--- | :--- | :--- |
| `SUPABASE_URL` | Supabase endpoint | `https://xxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Public client key (RLS enforced) | `eyJhbGciOi...` |
| `GOOGLE_ANDROID_CLIENT_ID`| Android OAuth Client ID | `10253...apps.googleusercontent.com` |
| `GOOGLE_WEB_CLIENT_ID` | Web Client ID for Supabase token auth | `10253...apps.googleusercontent.com` |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded release `.keystore` | `MIIK...` |
| `ANDROID_KEYSTORE_PASSWORD` | Release keystore password | `******` |
| `ANDROID_KEY_ALIAS` | Key alias name | `vshots` |
| `ANDROID_KEY_PASSWORD` | Key password | `******` |
| `BROWSERSTACK_USERNAME` | BrowserStack user account | `vedanshjain_xxxx` |
| `BROWSERSTACK_ACCESS_KEY` | BrowserStack API access key | `******` |

---

## 5. BrowserStack Real-Device Testing

The GitHub Actions workflow uploads the debug APK to BrowserStack App Automate via REST API:

```bash
curl -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" \
  -X POST "https://api-cloud.browserstack.com/app-automate/upload" \
  -F "file=@build/app/outputs/flutter-apk/app-debug.apk" \
  -F "custom_id=v-shots-build"
```

Verify tests on:
- Google Pixel 8 (Android 14)
- Samsung Galaxy S24 (Android 14)
- OnePlus 11 (Android 13)

---

## 6. Google Play Console Deployment

1. Go to [Google Play Console](https://play.google.com/console).
2. Select your application **V Shots** (`com.vshots.live`).
3. Navigate to **Testing → Internal testing** or **Production**.
4. Create a new release and upload `app-release.aab`.
5. Enter release notes and roll out the release.
