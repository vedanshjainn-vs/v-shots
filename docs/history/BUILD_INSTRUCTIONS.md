# 🎵 V Shots — Build Instructions

## 🚀 Automatic Build (GitHub Actions)

Your project is already configured for automatic building!

### Step 1: Upload to GitHub

**Option A: Using Termux (Android)**

1. Install **Termux** from Play Store
2. Open Termux and run:

```bash
pkg update
pkg install git

cd /storage/emulated/0/project_lyra

git init
git add .
git commit -m "Initial commit"

git remote add origin https://github.com/YOUR_USERNAME/v-shots.git
git branch -M main
git push -u origin main
```

**Option B: Using Computer**

1. Copy project to computer
2. Open terminal in project folder
3. Run same commands as above

**Option C: GitHub Web Upload**

1. Go to https://github.com/new
2. Create repo named `v-shots`
3. Upload files manually

---

### Step 2: Wait for Build

After uploading:
1. Go to your repository
2. Click **"Actions"** tab
3. You'll see a build running
4. Wait 5-10 minutes

---

### Step 3: Download APK

1. Click on the completed build
2. Scroll down to **"Artifacts"**
3. Download:
   - **v-shots-debug.apk** — For testing
   - **v-shots-release.apk** — For production

---

## 📱 Install on Phone

### Method 1: Direct Download
1. Open GitHub on phone
2. Go to Actions → Latest Build → Artifacts
3. Download APK
4. Open and install

### Method 2: Transfer from Computer
1. Download APK on computer
2. Transfer via USB/Email/Drive
3. Install on phone

---

## 🔧 Build Locally (If You Have Computer)

```bash
# Install Flutter
# https://docs.flutter.dev/get-started/install

# Clone repository
git clone https://github.com/YOUR_USERNAME/v-shots.git
cd v-shots

# Install dependencies
flutter pub get

# Generate code
dart run build_runner build --delete-conflicting-outputs

# Build APK
flutter build apk --debug

# APK location: build/app/outputs/flutter-apk/app-debug.apk
```

---

## ⚠️ Troubleshooting

### Build Fails?
- Check **Actions** tab for error messages
- Make sure all files are uploaded
- Check `pubspec.yaml` is valid

### APK Won't Install?
- Enable **"Install from Unknown Sources"**
- Check Android version (min SDK 24)

### Need Help?
- Check GitHub Actions logs
- Ask me for help!

---

## 📊 Build Status

| Item | Status |
|------|--------|
| GitHub Actions | ✅ Configured |
| Auto Build | ✅ Ready |
| APK Output | ✅ Debug + Release |

---

**Upload your code to GitHub and the APK will build automatically!** 🎵
