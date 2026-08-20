# V Shots Admin Panel

The remote Home CMS admin UI is intended to be hosted as a static GitHub Pages application and use Supabase as its backend.

## Planned controls

- Home section create/edit/delete
- drag/reorder sections
- enable/disable sections
- YouTube Search / Playlist / Channel / Manual / Trending source types
- region/category and item limits
- publish state

## Security

Use the Supabase publishable/anon key only in the static frontend. Never place the Supabase service-role key or database password in this folder, GitHub Actions, or the mobile app.
