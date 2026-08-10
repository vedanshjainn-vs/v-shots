# 🔒 V Shots — Security Policy & Guidelines

Security is a primary design goal of **V Shots**. This document outlines our vulnerability disclosure process, secret management rules, and data access control architecture.

---

## 🚫 Critical Security Rules

1. **No Hardcoded Secrets:**
   - Database passwords, service role keys, CI tokens, keystores, and OAuth client secrets must **never** be committed to source code or included in client assets.
2. **Public-by-Design Anon Key:**
   - Only the Supabase `anon` key is used on the client. It is strictly constrained by PostgreSQL Row Level Security (RLS).
3. **Strict `.gitignore` Enforcement:**
   - All `.env`, `.env.*`, `*.keystore`, `*.jks`, `local.properties`, and `google-services.json` files are ignored by git.
4. **Secret Scanning:**
   - Automated secret scanners (Gitleaks) run in CI/CD before any build artifact is approved.

---

## 🛡️ Data Access & Row Level Security (RLS)

Every database table enforces Row Level Security:

### 1. `profiles`
- **Read:** Public access (`USING (true)`).
- **Write:** Only the authenticated owner can modify their profile (`auth.uid() = id`).

### 2. `shots`
- **Read:** Public shots readable by everyone; private shots readable only by the author; followers-only shots readable by approved followers.
- **Write:** Users can create, update, or delete only their own shots (`auth.uid() = user_id`).

### 3. `likes` & `bookmarks`
- **Write:** Authenticated users can insert/delete records only for their own user ID (`auth.uid() = user_id`).

### 4. `comments`
- **Write:** Authenticated users can create comments as themselves and delete only their own comments.

### 5. `storage.objects`
- Storage buckets (`avatars`, `shots`, `thumbnails`) allow uploads only for authenticated sessions into user-scoped directories (`auth.role() = 'authenticated'`).

---

## 🔐 Reporting Security Vulnerabilities

If you discover a security vulnerability in V Shots, please report it privately:

- **Email:** security@vshots.live (or repository owner)
- **GitHub:** Submit a [Security Advisory](https://github.com/vedanshjainn-vs/v-shots/security/advisories)

Please allow reasonable time for remediation before public disclosure.
