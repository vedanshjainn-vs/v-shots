# V Shots Admin Panel

Static GitHub Pages CMS for remote Home configuration. Mobile-first responsive
(320px → 1440px+), draft-then-publish model.

**Live URL:** https://vedanshjainn-vs.github.io/v-shots/

**Demo mode (layout preview without auth):** append `?demo=1` — loads sample
data, skips sign-in, and disables network writes.

## What it controls

- **Home Management**: create / edit / reorder (drag or ↑↓) / preview /
  show-hide / publish-unpublish per section; title, subtitle, source type
  (YouTube Search/Playlist/Channel/Trending/Manual/JioSaavn/Personalized),
  query, region, max items, refresh; section-level Provider (Auto/YouTube/
  JioSaavn); manual items with per-item Title/Artist/Artwork/YouTube/JioSaavn
  URLs and per-item provider — with validation matching the app's legal
  boundary (no media URLs, no unofficial JioSaavn API).
- **Discover categories** (name, emoji, kind, query, active, order).
- **Feature flags** (Supabase-backed; the app reads them on launch).

The Flutter app reads published rows from Supabase (`home_layout_config`,
`discovery_categories`, `home_section_items`, `feature_flags`).
Pull-to-refresh on Home reloads remote config immediately; otherwise the app
caches for 1 hour. If Supabase is unreachable the app falls back to compiled
defaults.

## Security

- Google OAuth + email allowlist + `claim_home_admin()` RPC
- Writes go through the Supabase **anon** key and RLS (`is_home_admin()`)
- Never put the database password, service-role key, GitHub tokens, or
  BrowserStack keys in this folder

## Local dev

```bash
cd admin
python3 -m http.server 8090   # then open http://localhost:8090/?demo=1
```
