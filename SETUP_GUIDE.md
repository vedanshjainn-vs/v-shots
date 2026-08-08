# 🎵 V Shots — Setup Guide

## ✅ Configuration Complete

| Item | Value |
|------|-------|
| **Package Name** | `com.vshots.live` |
| **App Name** | V Shots |
| **Min SDK** | 24 (Android 7.0) |
| **Target SDK** | 34 (Android 14) |

---

## 📋 Next Steps (In Order)

### Step 1: Create Supabase Project

**Link:** https://supabase.com

1. Sign in with Google/GitHub
2. Click "New Project"
3. Settings:
   - **Name:** `v-shots`
   - **Password:** Create strong password (SAVE IT!)
   - **Region:** Mumbai (India)
4. Wait 2-3 minutes
5. Go to **Settings** → **API**
6. Copy these two values:

```
Project URL: https://________________.supabase.co
Anon Key: eyJ______________________________
```

**Send me these two values!**

---

### Step 2: Create Firebase Project

**Link:** https://console.firebase.google.com

1. Sign in with Google
2. Click "Create a project"
3. Settings:
   - **Name:** `v-shots`
   - **Analytics:** ON
4. Click "Create"
5. Click **Android icon** to add app
6. Settings:
   - **Package name:** `com.vshots.live`
   - **App name:** `V Shots`
7. Click "Register app"
8. **Download `google-services.json`**
9. Upload this file to me

**Send me the `google-services.json` file!**

---

### Step 3: Get SHA-1 Fingerprint

Open Terminal/Command Prompt and run:

**For Windows:**
```cmd
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**For Mac/Linux:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Look for this line:
```
SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
```

**Send me the SHA1 value!**

---

### Step 4: Set Up Google Sign-In

**Link:** https://console.cloud.google.com

1. Sign in with same Google account
2. Select your Firebase project
3. Go to **APIs & Services** → **Credentials**
4. Click **"+ CREATE CREDENTIALS"** → **OAuth client ID**
5. If asked to configure consent screen:
   - **Email:** Your email
   - Click Save → Save → Back to Dashboard
6. Create OAuth Client:
   - **Type:** Android
   - **Name:** V Shots Android
   - **Package name:** `com.vshots.live`
   - **SHA-1:** (paste from Step 3)
7. Click "Create"

**Send me the Client ID!**

---

## 📤 What to Send Me

Please send these in order:

```
1. Supabase URL: ________________
2. Supabase Anon Key: ________________
3. google-services.json file (upload)
4. SHA-1 Fingerprint: ________________
5. Google OAuth Client ID: ________________
```

---

## 🔧 After You Send These

I will:
1. ✅ Configure Supabase connection
2. ✅ Set up Firebase
3. ✅ Configure Google Sign-In
4. ✅ Create database tables
5. ✅ Set up authentication
6. ✅ Build the app
7. ✅ Give you the APK to test

---

## 📱 App Details

| Feature | Status |
|---------|--------|
| Package Name | ✅ `com.vshots.live` |
| App Name | ✅ V Shots |
| Android Config | ✅ Ready |
| Firebase Config | ⏳ Waiting for google-services.json |
| Supabase Config | ⏳ Waiting for credentials |
| Google Sign-In | ⏳ Waiting for OAuth Client ID |

---

## 🆘 Need Help?

If you're stuck on any step, just tell me:
- Which step number
- What's happening
- Screenshot if possible

I'll guide you through it!
