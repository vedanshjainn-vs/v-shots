# V Shots Remote Home CMS

Home sections can be changed without a Play Store update. The mobile app reads **published** rows from Supabase and falls back to compiled shelves if remote config is missing or `enable_remote_home` is false.

## Admin

- UI: `admin/` (GitHub Pages → https://vedanshjainn-vs.github.io/v-shots/)
- Auth: Google OAuth, allowlisted emails only
- Writes: Supabase anon key + RLS (`is_home_admin()`)

## Tables

| Table | App use |
| --- | --- |
| `home_layout_config` | Home shelf order, titles, source type, query / playlist / channel |
| `home_section_items` | Pinned videos for `youtube_manual` shelves |
| `discovery_categories` | Discover mood queries |
| `feature_flags` | `enable_remote_home` and playback flags |
| `home_config` | Publish stamp / version |

## Source types

| `source_type` | Client behavior |
| --- | --- |
| `youtube_search` | Catalog shelf via existing search pipeline |
| `youtube_playlist` | Search/playlist id as catalog query |
| `youtube_channel` | Channel id / handle as catalog query |
| `youtube_trending` | Trending catalog (`viewCount`) |
| `youtube_manual` | Pinned `home_section_items` YouTube video IDs |
| `personalized` | On-device recommendation engine |

Section keys `made_for_you`, `because_listened`, `trending_for_you`, `artists_for_you`, `official_music`, `discover_something_new`, and `continue_listening` are **always** treated as personalized, even if an older row still says `youtube_search`. That prevents CMS from turning Made For You into a dummy search.

Continue Listening is prepended by the client if the CMS does not include it.

## Safety

- Only public YouTube metadata/IDs belong in these tables.
- Never store API keys, service-role keys, database passwords, OAuth client secrets, GitHub tokens, or BrowserStack credentials in the app or this repository.
- Playback stays on the existing official YouTube player / in-app browser.
- Pull-to-refresh on Home calls `RemoteConfigService.refresh()` then rebuilds shelves.
