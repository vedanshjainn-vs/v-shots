# V Shots Admin Panel

Static GitHub Pages CMS for remote Home configuration.

**Live URL:** https://vedanshjainn-vs.github.io/v-shots/

## What it controls

- Home section create / edit / reorder / show-hide
- Source types: YouTube Search, Playlist, Channel, Trending, Manual video IDs, Personalized
- Discover category queries
- Feature flags (`enable_remote_home`, playback flags)

The Flutter app reads published rows from Supabase (`home_layout_config`, `discovery_categories`, `home_section_items`, `feature_flags`). Pull-to-refresh on Home reloads remote config immediately; otherwise the app caches for 1 hour.

## Security

- Google OAuth + email allowlist
- Writes go through the Supabase **anon** key and RLS (`is_home_admin()`)
- Never put the database password, service-role key, GitHub tokens, or BrowserStack keys in this folder
