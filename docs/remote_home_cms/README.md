# V Shots Remote Home CMS

This directory documents the remote Home configuration contract.

The mobile app reads published Home configuration from Supabase. The configuration is intentionally remote so Home sections can be changed without a Play Store update.

## Safety

- Only public YouTube metadata/IDs should be stored here.
- Never store YouTube API keys, Supabase service-role keys, database passwords, OAuth client secrets, GitHub tokens, or BrowserStack credentials in the app or this repository.
- Playback remains through the app's existing official YouTube player/browser implementation.

## Initial configuration model

A Home section has:

- `title`
- `section_type`
- `source_type`
- `source_value`
- `sort_order`
- `max_items`
- `enabled`
- optional `region_code`
- optional `category_id`
- optional `refresh_minutes`

Supported source types are intended to include `youtube_search`, `youtube_playlist`, `youtube_channel`, `youtube_manual`, and `youtube_trending`.

The mobile client should fail safely to its existing Home behavior if remote configuration cannot be loaded.
