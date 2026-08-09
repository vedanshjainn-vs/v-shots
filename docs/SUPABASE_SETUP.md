# 🗄️ V Shots — Supabase Database & Auth Setup

This document explains how to set up and verify the **Supabase** backend for V Shots.

---

## 📋 1. Execute SQL Migrations

Run the SQL migration script located at `supabase/migrations/20260810000001_vshots_nova_schema.sql` (or `supabase_setup.sql`) inside the [Supabase SQL Editor](https://supabase.com/dashboard/project/_/sql).

The script automatically sets up:
- Tables: `profiles`, `shots`, `likes`, `comments`, `follows`, `bookmarks`, `notifications`
- Triggers: Auto-create profile on signup (`handle_new_user`), auto-increment/decrement like & comment counters
- Performance indexes on frequently queried columns (`user_id`, `created_at`, `shot_id`, `follower_id`)
- Row Level Security (RLS) policies on all tables
- Storage buckets: `avatars`, `shots`, `thumbnails` with public read and authenticated write access

---

## 🔑 2. Google OAuth Configuration in Supabase

1. Navigate to **Authentication → Providers → Google** in your Supabase Dashboard.
2. Toggle Google **Enabled**.
3. In **Client ID (for OAuth)**, paste your Web OAuth Client ID (`GOOGLE_WEB_CLIENT_ID`).
4. In **Client Secret**, paste the Web Client Secret from Google Cloud Console.
5. Under **Authorized Client IDs**, add the Android Client ID (`GOOGLE_ANDROID_CLIENT_ID`).
6. Copy the **Callback URL (for OAuth)** shown in Supabase (e.g. `https://xxxx.supabase.co/auth/v1/callback`) and add it to **Authorized redirect URIs** in Google Cloud Console Credentials.

---

## 📦 3. Verify Storage Buckets

In the Supabase Dashboard under **Storage**, ensure the following buckets are present and public:
- `avatars` (Public: Yes)
- `shots` (Public: Yes)
- `thumbnails` (Public: Yes)

RLS policies will allow authenticated app users to upload and view media securely.
