// ═════════════════════════════════════════════════════════════════════════
// V SHOTS — Configured Playlist Source (Verified IDs Only)
//
// These are REAL playlist ids copied by the user from the official YouTube
// Music channel (youtube.com/playlist?list=...). V Shots NEVER guesses a
// playlist id. Each entry below is a real id.
//
// RUNTIME-EDITABLE: This file is only the OFFLINE / first-launch fallback.
// At runtime the app also reads the Supabase `configured_playlists` table via
// RemoteConfigService (see supabase_configured_playlists.sql). To add/remove/
// rename playlists WITHOUT shipping an app update, just edit that Supabase
// table — the app picks it up on the next config refresh.
//
// DISPLAY TITLES: The names below are friendly fallbacks. Whenever a live
// YouTube Data API key is present, PlaylistContentService resolves the REAL
// title/artwork/description from YouTube (playlists.list?id=...) and uses
// that instead, so sections show the true playlist name — never a fabricated
// one. Feel free to rename these fallbacks; they only apply when offline.
// ═════════════════════════════════════════════════════════════════════════

/// A playlist id + display title supplied explicitly (user-verified).
class ConfiguredPlaylist {
  const ConfiguredPlaylist({
    required this.id,
    required this.title,
    this.category = 'More From YouTube Music',
  });

  final String id;
  final String title;
  final String category;
}

/// Real, user-verified playlist ids from the official YouTube Music channel.
const List<ConfiguredPlaylist> kConfiguredPlaylists = [
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_kCicKSTh7ylcZSwvrN0vV4dI3eqEpXR4A',
      title: 'Trending Now Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_n9Fbdw7e6ap-98_A-8JYBmPv64v-Uaq1g',
      title: 'New Music Mix'),
  ConfiguredPlaylist(
      id: 'PL4fGSI1pDJn4tiNLMZVGGt2Kghgw__2u0', title: 'Top Hits'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_kuo_NioExeUmw07dFf8BzQ64DFFTlgE7Q',
      title: 'Global Pop Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_lj-zBExVYl7YN_NxXboDIh4A-wKGfgzNY',
      title: 'Bollywood Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_lyVnWI5JnuwKJiuE-n1x-Un0mj9WlEyZw',
      title: 'Hindi Hits Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_nTbyVypdXPQd00z15bTWjZr7pG-26yyQ4', title: 'Punjabi Mix'),
  ConfiguredPlaylist(
      id: 'PL4fGSI1pDJn5RgLW0Sb_zECecWdH_4zOX', title: 'Romantic Hits'),
  ConfiguredPlaylist(
      id: 'PL4fGSI1pDJn5JXkyIohg2RstsbL2SnRew', title: 'Chill & Lo-Fi'),
  ConfiguredPlaylist(
      id: 'PL4fGSI1pDJn4ivDqrsepD3tvHsp0KTDRM', title: 'Workout Energy'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_ksEjgm3H_7zOJ_RHzRjN1wY-_FFcs7aAU', title: 'Party Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_nNhhgRET3NcJ4SJBvqhAIJ6t7vjsQYowc',
      title: 'Sad Songs Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_kkkZR6KAV5kBSqDCeaBb_pDDhA83VGFwg',
      title: 'Devotional Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_mk3xwsayv9PxawuXS-U6ao9eMeNmSwYAM', title: 'EDM Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_l8CaYQvBQWVT2st1VsW9JjODWisR_vd3U', title: 'Indie Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_kmPRjHDECIcuVwnKsx2Ng7fyNgFKWNJFs', title: 'Hip-Hop Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_lPzT2bIPNJ_6II2vlgcE_-Mw1fMTfPheA',
      title: 'English Pop Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_lycab9oGCf-Wrf032tl6Lxn2W68QjdXls',
      title: 'Road Trip Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_nlKphX00YtBNjlGZcmPifGNAPXUSjezNM',
      title: 'Focus & Study'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_lBa7h-v-su4TAsDNvyelrswt9YYYU7x4g', title: 'Acoustic Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_krbBs7P2iEb30IODyVbiOXWyhZtAIX9Uk', title: '90s Hits'),
  ConfiguredPlaylist(
      id: 'PL4fGSI1pDJn4pTWyM3t61lOyZ6_4jcNOw', title: 'Sufi & Ghazals'),
  ConfiguredPlaylist(
      id: 'OLAK5uy_lSTp1DIuzZBUyee3kDsXwPgP25WdfwB40', title: 'Featured Album'),
  ConfiguredPlaylist(
      id: 'PL4fGSI1pDJn6puJdseH2Rt9sMvt9E2M4i', title: 'Party Bangers'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_l_Bj8rMsjkhFMMs-eLrA17_zjr9r6g_Eg',
      title: 'Trending Mix 2'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_nlOMew8qv8HGXb9HbshuU1OgH3aL_JMKA', title: 'Fresh Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_nGC5IUV3lYF-P_wGb-LzMPFydA-RkPblc',
      title: 'New Music Mix 2'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_m_cn307EUnwiDOgAsOMM27CHhuJCX2ygk', title: 'Top 40 Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_n7VIYx-oWOJQanlpBG6GRyLZxpWYMltB8', title: 'Morning Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_mN9vO_dypsJubNdWlO5JSTtCA0SI3o-88', title: 'Night Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_mypHeJ-B5f7-OgrxJcXeiHSotjIJ_UDhQ', title: 'Chill Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_lbfDqlFOiRJekoTwNgiES65gcham4ZelA', title: 'Love Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_mUvTtdERIHEiVAHIkV3GRndrY-H4M2nnA', title: 'Energy Mix'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_mLJf8i5vYsqR7oTk6CNO4Ge49J3OU4sRs',
      title: 'Indie & Acoustic'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_kw2wIlEv9llILhO0qoMTLsBBhmjzuibAc', title: 'Global Mix'),
  ConfiguredPlaylist(
      id: 'OLZy5IP9FKwvoxKpxGYLUO7ErQdOxKYL1tg', title: 'YouTube Music'),
  ConfiguredPlaylist(
      id: 'RDCLAK5uy_kiDNaS5nAXxdzsqFElFKKKs0GUEFJE26w', title: 'Fresh Picks'),
];
