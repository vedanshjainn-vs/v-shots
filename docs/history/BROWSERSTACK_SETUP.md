# 📱 BrowserStack Cloud Device Testing Setup

## What is BrowserStack?

BrowserStack lets you test your APK on real Android devices in the cloud. No need to manually install on your phone.

---

## Step 1: Create BrowserStack Account

**Link:** https://www.browserstack.com/app-automate

1. Click **"Start Free"**
2. Sign up with email
3. You get **100 free minutes** per month

---

## Step 2: Get Your Credentials

After signing up:

1. Go to: https://www.browserstack.com/accounts/settings
2. Find **"Username"** and **"Access Key"**
3. Copy both values

---

## Step 3: Add to GitHub Secrets

1. Go to your repo: https://github.com/vedanshjainn-vs/v-shots
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **"New repository secret"**
4. Add these two secrets:

| Name | Value |
|------|-------|
| `BROWSERSTACK_USERNAME` | Your BrowserStack username |
| `BROWSERSTACK_ACCESS_KEY` | Your BrowserStack access key |

---

## Step 4: That's It!

Now every push to GitHub will:
1. ✅ Build the APK
2. ✅ Upload to BrowserStack
3. ✅ Test on real device
4. ✅ Report results

---

## Alternative: Firebase Test Lab (Free)

If you don't want BrowserStack, use Firebase Test Lab:

1. Go to: https://console.firebase.google.com
2. Select your project
3. Go to **Test Lab**
4. Get your Firebase token: `firebase login:ci`
5. Add `FIREBASE_TOKEN` to GitHub Secrets

---

## What Gets Tested?

| Test | Description |
|------|-------------|
| **Splash Screen** | App launches, splash appears and disappears |
| **Login Screen** | Login form loads correctly |
| **Home Screen** | Home content loads |
| **Navigation** | Can navigate between screens |
| **Player** | Player screen opens |
| **Crash Detection** | Any crashes are caught |

---

## Need Help?

If you provide your BrowserStack credentials, I'll add them to GitHub Secrets for you.

**Required:**
```
1. BrowserStack Username: ________________
2. BrowserStack Access Key: ________________
```

---

## Quick Links

| Service | Link |
|---------|------|
| BrowserStack | https://www.browserstack.com/app-automate |
| Firebase Test Lab | https://console.firebase.google.com |
| GitHub Secrets | https://github.com/vedanshjainn-vs/v-shots/settings/secrets/actions |
