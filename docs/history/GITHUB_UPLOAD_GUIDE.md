# 📱 Upload to GitHub from Mobile

## Method 1: Using GitHub Mobile App

### Step 1: Download GitHub App
**Play Store:** https://play.google.com/store/apps/details?id=com.github.android

### Step 2: Create Repository
1. Open GitHub app
2. Tap **"+"** → **"New Repository"**
3. Name: `v-shots`
4. Private: ✅
5. Create

### Step 3: Upload Files
You'll need to use a file manager app or Termux.

---

## Method 2: Using Termux (Recommended)

### Step 1: Install Termux
**Play Store:** https://play.google.com/store/apps/details?id=com.termux

### Step 2: Open Termux and Run These Commands

```bash
# Install git
pkg install git

# Install node (for GitHub CLI)
pkg install node

# Configure git
git config --global user.name "Your Name"
git config --global user.email "your-email@gmail.com"

# Go to project folder
cd /storage/emulated/0/project_lyra

# Initialize git
git init
git add .
git commit -m "Initial commit"

# Add your GitHub repository
git remote add origin https://github.com/YOUR_USERNAME/v-shots.git

# Push to GitHub
git push -u origin main
```

---

## Method 3: Using GitHub Web (Easiest)

### Step 1: Zip the Project
Use any file manager to zip the `project_lyra` folder.

### Step 2: Go to GitHub
https://github.com

### Step 3: Create Repository
1. Click **"+"** → **"New repository"**
2. Name: `v-shots`
3. Private: ✅
4. Create

### Step 4: Upload Files
1. Click **"Add file"** → **"Upload files"**
2. Drag and drop or select files
3. Click **"Commit changes"**

**Note:** GitHub has a 100 file limit per upload. You may need to upload in batches.

---

## Method 4: Using GitHub CLI (Advanced)

### Install Termux + GitHub CLI

```bash
# Install Termux from Play Store

# Open Termux and run:
pkg update
pkg install gh

# Login to GitHub
gh auth login

# Create repo and push
cd /storage/emulated/0/project_lyra
gh repo create v-shots --private --source=. --push
```

---

## ⚠️ Important Files to Upload

Make sure these files are included:

```
✅ lib/                    (all Dart code)
✅ android/                (Android config)
✅ pubspec.yaml            (dependencies)
✅ .github/workflows/      (build automation)
✅ google-services.json    (in android/app/)
✅ release.keystore        (in android/app/)
✅ debug.keystore          (in android/app/)
```

---

## 🎯 After Upload

Once uploaded, GitHub Actions will automatically:
1. ✅ Install Flutter
2. ✅ Install dependencies
3. ✅ Generate code
4. ✅ Build APK
5. ✅ Create download link

### Find Your APK:

1. Go to your repository
2. Click **"Actions"** tab
3. Click on the latest build
4. Scroll down to **"Artifacts"**
5. Download **v-shots-debug** or **v-shots-release**

---

## 📲 Quick Summary

**Easiest Method:**
1. Install Termux from Play Store
2. Open Termux
3. Run the commands from Method 2
4. Wait for build to complete
5. Download APK from GitHub Actions

**Tell me when you've uploaded the code!** 🎵
