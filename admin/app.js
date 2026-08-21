/* ═══════════════════════════════════════════════════════════════════════════
   V Shots Admin — Home CMS / Discover / Feature flags
   Mobile-first SPA. Draft-then-publish model: edits stay local until
   "Publish Home" (the only network write for Home content).
   Legal boundary mirrors the Flutter app:
     • JioSaavn: ONLY public webpage URLs (permalink / search). No media URLs,
       no stream extraction, no unofficial API.
     • YouTube: ONLY public watch URLs / video IDs. No media URLs.
   ═══════════════════════════════════════════════════════════════════════════ */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/* ── Constants ────────────────────────────────────────────────────────────── */
const SUPABASE_URL = 'https://jzxtxqjheggyoqwohqjg.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp6eHR4cWpoZWdneW9xd29ocWpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxODM4OTcsImV4cCI6MjEwMTc1OTg5N30.fD6pKQ4VRG-AoF-nLdpU9iMK1qWz4N-diqMUOJESVw8';
const PRODUCTION_REDIRECT_URL = 'https://vedanshjainn-vs.github.io/v-shots/';
const AUTHORIZED_EMAILS = [
  'lovesongs1106@gmail.com',
  'vedanshjainn@gmail.com',
  'mrvedansh11@gmail.com',
];

const SOURCE_TYPES = [
  { id: 'youtube_search', label: 'YouTube Search', hint: 'Search query, e.g. trending punjabi songs official audio', valueField: 'query' },
  { id: 'youtube_playlist', label: 'YouTube Playlist', hint: 'Playlist URL or PL… id — the app fetches the whole playlist automatically', valueField: 'url' },
  { id: 'youtube_channel', label: 'YouTube Channel', hint: 'Channel URL, UC… id, or @handle — the app fetches latest uploads automatically', valueField: 'url' },
  { id: 'youtube_trending', label: 'YouTube Trending', hint: 'Region code (IN / US / GB …) — real regional trending via the official API', valueField: 'region' },
  { id: 'youtube_manual', label: 'Manual (YouTube)', hint: 'Pin exact YouTube videos below', valueField: 'none' },
  { id: 'jiosaavn_manual', label: 'Manual (JioSaavn)', hint: 'Paste exact https://www.jiosaavn.com/song/... permalinks. Never invent IDs.', valueField: 'none' },
  { id: 'jiosaavn_playlist', label: 'JioSaavn Playlist (page)', hint: 'Paste a https://www.jiosaavn.com/featured/... or /s/playlist/... URL — the app opens the official playlist page. No manual songs, no unofficial API.', valueField: 'url' },
  { id: 'personalized', label: 'Personalized (app engine)', hint: 'Uses the on-device recommendation engine — no query needed', valueField: 'none' },
];

/* Stable personalized keys — matches HomeFeedService._personalizedKeys in the app. */
const PERSONALIZED_KEYS = [
  { id: 'continue_listening', title: 'Continue Listening', engine: 'Recently played (offline)' },
  { id: 'made_for_you', title: 'Made For You', engine: 'Music Intelligence V3' },
  { id: 'because_listened', title: 'Because You Listened To', engine: 'Recommendation engine (seeded)' },
  { id: 'trending_for_you', title: 'Trending For You', engine: 'Recommendation engine' },
  { id: 'discover_something_new', title: 'Discover Something New', engine: 'Recommendation engine (viral)' },
  { id: 'artists_for_you', title: 'Artists For You', engine: 'Taste profile top artists' },
  { id: 'official_music', title: 'Official Music', engine: 'Verified/official uploads filter' },
];

/* Flags the Flutter app actually reads (RemoteFeatureFlags).
   Only these keys are shown/toggled in this panel — flags the app never
   reads are not displayed, so no toggle here is a no-op. */
const KNOWN_FLAGS = [
  { key: 'enable_remote_home', description: 'Home fetches layout from Supabase CMS. OFF = compiled defaults only.', appReads: true },
  { key: 'enable_jiosaavn_web_playback', description: 'Allow JioSaavn webpage playback in the in-app WebView. Safe default: OFF.', appReads: true },
  { key: 'enable_jiosaavn_search_fallback', description: 'If no exact permalink, open the JioSaavn search page.', appReads: true },
  { key: 'enable_jiosaavn_exact_urls', description: 'Honor exact JioSaavn permalinks from CMS items (PlaybackRouter).', appReads: true },
  { key: 'enable_youtube_web_playback', description: 'Master switch for YouTube webpage playback (PlaybackRouter). OFF = YouTube targets unavailable.', appReads: true },
  { key: 'enable_discovery_remote_categories', description: 'Discover mood list comes from Supabase categories.', appReads: true },
  { key: 'enable_social', description: 'Comments / creator / UGC surfaces.', appReads: true },
];

const NAV_ITEMS = [
  { id: 'dashboard', label: 'Dashboard', icon: '📊', section: 'main' },
  { id: 'home-cms', label: 'Home Management', icon: '🏠', section: 'content' },
  { id: 'discover', label: 'Discover categories', icon: '🔍', section: 'content' },
  { id: 'providers', label: 'Providers', icon: '🔌', section: 'content' },
  { id: 'feature-flags', label: 'Feature flags', icon: '🚩', section: 'system' },
  { id: 'users', label: 'Admins', icon: '👥', section: 'system' },
  { id: 'settings', label: 'Settings', icon: '⚙️', section: 'system' },
];

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { autoRefreshToken: true, persistSession: true, detectSessionInUrl: true },
});

const state = {
  user: null,
  admin: false,
  page: 'home-cms',
  demo: new URLSearchParams(location.search).has('demo'),
  dirty: false,
  busy: false,
  sync: null, // { ok, error, at, sections, items } — set by loadHome()
  homeLoaded: false, // server rows loaded; renderHomeCMS must NOT refetch
                      // while a draft is being edited (was wiping edits!)
  data: { sections: [], items: {}, categories: [], flags: [] },
};

/* ── Utils ────────────────────────────────────────────────────────────────── */
const $ = (id) => document.getElementById(id);
const esc = (x) => String(x ?? '')
  .replaceAll('&', '&amp;').replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const uid = () => crypto.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2)}`;

function toast(msg, type = 'success') {
  let wrap = document.querySelector('.toast-wrap');
  if (!wrap) {
    wrap = document.createElement('div');
    wrap.className = 'toast-wrap';
    document.body.appendChild(wrap);
  }
  const t = document.createElement('div');
  t.className = `toast ${type}`;
  t.textContent = msg;
  wrap.appendChild(t);
  setTimeout(() => { t.style.opacity = '0'; t.style.transition = 'opacity .3s'; }, 3200);
  setTimeout(() => t.remove(), 3600);
}

function setBusy(btn, busy, busyText) {
  if (!btn) return;
  if (busy) {
    btn.dataset.original = btn.innerHTML;
    btn.disabled = true;
    btn.classList.add('btn-busy');
    btn.innerHTML = `<span class="spinner"></span> ${esc(busyText || 'Saving…')}`;
  } else {
    btn.disabled = false;
    btn.classList.remove('btn-busy');
    if (btn.dataset.original) btn.innerHTML = btn.dataset.original;
  }
}

/* ── URL validation (legal boundary — mirrors the Flutter app) ────────────── */
const MEDIA_EXT_RE = /\.(mp3|m4a|m3u8|mp4|aac|ogg|wav|flac|webm|mpd)([?#].*)?$/i;
const FORBIDDEN_HOST_RE = /(api\.|cdn|stream|download|media|saavn\.me)/i;
/* Mirrors the Flutter app's JioSaavnWebProvider.pageHosts exactly. */
const JIOSAAVN_HOSTS = ['jiosaavn.com', 'www.jiosaavn.com'];

function isForbiddenMediaUrl(url) {
  const v = String(url || '').trim();
  if (!v) return { ok: true };
  if (!/^https:\/\//i.test(v)) return { ok: false, text: 'Must be an HTTPS URL' };
  try {
    const u = new URL(v);
    if (MEDIA_EXT_RE.test(u.pathname)) return { ok: false, text: 'Direct media/stream URLs are not allowed (.mp3/.m4a/.m3u8/…) — no extraction' };
    if (FORBIDDEN_HOST_RE.test(u.hostname)) return { ok: false, text: 'CDN / media-host URLs are not allowed' };
    return { ok: true };
  } catch (_) {
    return { ok: false, text: 'Not a valid URL' };
  }
}

function extractYoutubeId(input) {
  const v = String(input || '').trim();
  if (!v) return null;
  if (/^(javascript|data|file):/i.test(v)) return null;
  if (MEDIA_EXT_RE.test(v)) return null;
  const bare = v.match(/^[A-Za-z0-9_-]{11}$/);
  if (bare) return v;
  const m = v.match(/(?:youtube\.com\/(?:watch\?(?:[^#]*&)?v=|embed\/|shorts\/|live\/)|youtu\.be\/)([A-Za-z0-9_-]{11})/);
  return m ? m[1] : null;
}

function inspectYoutubeInput(input) {
  const v = String(input || '').trim();
  if (!v) return { ok: true, id: null, text: '' };
  const bad = isForbiddenMediaUrl(v);
  if (!bad.ok) return { ok: false, id: null, text: bad.text };
  const id = extractYoutubeId(v);
  if (id) return { ok: true, id, text: `✓ Video ${id}` };
  return { ok: false, id: null, text: 'Not a YouTube video URL / ID' };
}

function inspectJioSaavnUrl(url) {
  const v = String(url || '').trim();
  if (!v) return { ok: true, text: '' };
  const bad = isForbiddenMediaUrl(v);
  if (!bad.ok) return { ok: false, text: bad.text };
  try {
    const u = new URL(v);
    if (!JIOSAAVN_HOSTS.includes(u.hostname.toLowerCase())) {
      return { ok: false, text: 'Must be a jiosaavn.com URL (the app only opens jiosaavn.com pages)' };
    }
    if (u.pathname.startsWith('/song/') && u.pathname.split('/').filter(Boolean).length >= 3) {
      return { ok: true, text: '✓ Exact song permalink' };
    }
    if (u.pathname.startsWith('/search/songs/')) {
      return { ok: true, text: 'Search URL (used only when search fallback is enabled)' };
    }
    if (u.pathname.startsWith('/featured/') || u.pathname.startsWith('/s/playlist/')) {
      return { ok: true, text: '✓ Official playlist page (the app opens this page — no API/scraping)' };
    }
    return { ok: false, text: 'Must be a /song/ permalink, /search/songs/ page, or playlist page' };
  } catch (_) {
    return { ok: false, text: 'Not a valid URL' };
  }
}

/* ── Auth ─────────────────────────────────────────────────────────────────── */
function redirectUrl() {
  if (location.hostname.includes('github.io')) return PRODUCTION_REDIRECT_URL;
  return `${location.origin}${location.pathname}`;
}

function isAuthorizedEmail(email) {
  return AUTHORIZED_EMAILS.includes((email || '').toLowerCase().trim());
}

async function checkAuth() {
  const { data: { session } } = await supabase.auth.getSession();
  const user = session?.user || null;
  state.user = user;
  if (!user) { state.admin = false; return false; }
  if (!isAuthorizedEmail(user.email)) {
    await supabase.auth.signOut();
    state.admin = false;
    return false;
  }
  try { await supabase.rpc('claim_home_admin'); } catch (e) {
    console.warn('[AUTH] claim_home_admin:', e);
  }
  state.admin = true;
  return true;
}

async function signIn() {
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: redirectUrl(), queryParams: { prompt: 'select_account' } },
  });
  if (error) renderLogin(error.message);
}

async function signOut() {
  await supabase.auth.signOut();
  state.admin = false;
  state.user = null;
  renderLogin();
}

function renderLogin(errorMsg) {
  document.title = 'V Shots Admin';
  $('app').innerHTML = `
    <div class="login-screen">
      <div class="login-card">
        <div class="login-logo">V</div>
        <div class="login-title">V Shots Admin</div>
        <div class="login-subtitle">Sign in with an authorized Google account to manage Home, Discover and feature flags.</div>
        <button class="login-btn" id="login-btn">
          <svg width="18" height="18" viewBox="0 0 24 24"><path fill="currentColor" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"/><path fill="currentColor" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/><path fill="currentColor" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/><path fill="currentColor" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/></svg>
          Sign in with Google
        </button>
        ${errorMsg ? `<div class="login-error">${esc(errorMsg)}</div>` : ''}
        <p class="muted small mt16">Authorized accounts: lovesongs1106@gmail.com · vedanshjainn@gmail.com · mrvedansh11@gmail.com</p>
      </div>
    </div>`;
  $('login-btn').onclick = signIn;
}

/* ── Shell ────────────────────────────────────────────────────────────────── */
function renderAdmin() {
  document.title = 'V Shots Admin';
  $('app').innerHTML = `
    <div class="admin-layout">
      <div class="backdrop" id="backdrop"></div>
      <aside class="sidebar" id="sidebar">
        <div class="sidebar-header">
          <div class="sidebar-logo">V</div>
          <div>
            <div class="sidebar-title">V Shots Admin</div>
            <div class="sidebar-subtitle">Remote Home CMS</div>
          </div>
        </div>
        <nav class="sidebar-nav" id="sidebar-nav"></nav>
        ${state.demo ? '<div class="banner" style="margin:8px 12px">🧪 Demo mode — network writes disabled.</div>' : ''}
      </aside>
      <div class="main">
        <header class="topbar">
          <div class="topbar-left">
            <button class="btn btn-icon menu-btn" id="menu-btn" aria-label="Open menu">☰</button>
            <div class="topbar-title" id="page-title">Home Management</div>
          </div>
          <div class="topbar-actions">
            <div class="topbar-status" title="Supabase connected"></div>
            <span class="topbar-email">${esc(state.user?.email || (state.demo ? 'demo' : ''))}</span>
            <button class="btn btn-sm" id="logout-btn">Sign out</button>
          </div>
        </header>
        <div class="content" id="content"><div style="text-align:center;padding:60px"><div class="spinner"></div></div></div>
      </div>
    </div>`;

  const nav = $('sidebar-nav');
  let section = '';
  NAV_ITEMS.forEach((item) => {
    if (item.section !== section) {
      section = item.section;
      const label = section === 'content' ? 'Content' : section === 'system' ? 'System' : '';
      if (label) nav.innerHTML += `<div class="nav-section">${label}</div>`;
    }
    nav.innerHTML += `<div class="nav-item${state.page === item.id ? ' active' : ''}" data-page="${item.id}"><span class="icon">${item.icon}</span>${item.label}</div>`;
  });
  const closeDrawer = () => { $('sidebar').classList.remove('open'); $('backdrop').classList.remove('show'); };
  $('menu-btn').onclick = () => { $('sidebar').classList.toggle('open'); $('backdrop').classList.toggle('show'); };
  $('backdrop').onclick = closeDrawer;
  nav.querySelectorAll('.nav-item').forEach((el) => {
    el.onclick = () => {
      state.page = el.dataset.page;
      closeDrawer();
      renderAdmin();
    };
  });
  if (state.demo) {
    $('logout-btn').textContent = 'Exit demo';
    $('logout-btn').onclick = () => { location.search = ''; };
  } else {
    // Public mode — no sign-out, just a label.
    $('logout-btn').textContent = 'Public mode';
    $('logout-btn').disabled = true;
  }
  loadPage();
}

async function loadPage() {
  const content = $('content');
  const item = NAV_ITEMS.find((n) => n.id === state.page);
  $('page-title').textContent = item?.label || 'Dashboard';
  content.innerHTML = '<div style="text-align:center;padding:60px"><div class="spinner"></div></div>';
  // Entering Home Management from nav = fresh entry (discard any draft).
  if (state.page === 'home-cms') { state.homeLoaded = false; state.dirty = false; }
  try {
    switch (state.page) {
      case 'dashboard': await renderDashboard(content); break;
      case 'home-cms': await renderHomeCMS(content); break;
      case 'discover': await renderDiscover(content); break;
      case 'providers': await renderProviders(content); break;
      case 'feature-flags': await renderFlags(content); break;
      case 'users': renderUsers(content); break;
      default: renderSettings(content); break;
    }
  } catch (e) {
    content.innerHTML = `<div class="card"><div class="card-title">Could not load this page</div><p class="login-error mt8">${esc(e.message || e)}</p>
      <button class="btn mt12" onclick="location.reload()">Reload</button></div>`;
  }
}

/* ── Data loading ─────────────────────────────────────────────────────────── */
/// Races a promise against a timeout so a dead network surfaces a REAL
/// error quickly (supabase-js silently retries fetch failures with backoff).
function withTimeout(promise, ms, label) {
  return Promise.race([
    promise,
    new Promise((_, reject) => setTimeout(() => reject(new Error(`${label} — request timed out after ${Math.round(ms / 1000)}s`)), ms)),
  ]);
}

async function loadHome() {
  if (state.demo) {
    state.data = demoData();
    state.sync = { ok: true, error: null, at: new Date().toISOString(), sections: state.data.sections.length, items: 2 };
    return;
  }
  const { data: sections, error } = await withTimeout(
    supabase.from('home_layout_config').select('*').order('sort_order'),
    15000, 'home_layout_config fetch',
  );
  if (error) {
    state.sync = { ok: false, error: error.message || String(error), at: new Date().toISOString() };
    throw error;
  }
  state.data.sections = sections || [];
  const { data: items, error: itemsErr } = await withTimeout(
    supabase.from('home_section_items').select('*').order('sort_order'),
    15000, 'home_section_items fetch',
  );
  if (itemsErr) {
    state.sync = { ok: false, error: itemsErr.message || String(itemsErr), at: new Date().toISOString() };
    throw itemsErr;
  }
  const grouped = {};
  (items || []).forEach((row) => { (grouped[row.section_id] ||= []).push(row); });
  state.data.items = grouped;
  state.sync = {
    ok: true, error: null, at: new Date().toISOString(),
    sections: (sections || []).length, items: (items || []).length,
  };
}

function demoData() {
  const sections = [
    s('trending_now', 'trending_now', 'Trending Now', 'What the world is playing', 'youtube_search', 'trending songs official music video 2026', 15, true, true, 'auto'),
    s('new_releases', 'new_releases', 'New Releases', 'Fresh drops this week', 'youtube_search', 'new music releases official audio 2026', 15, true, true, 'auto'),
    s('made_for_you', 'made_for_you', 'Made For You', '', 'personalized', 'made_for_you', 12, true, true, 'auto'),
    s('because_listened', 'because_listened', 'Because You Listened To', '', 'personalized', 'because_listened', 12, true, true, 'auto'),
    s('india_hits', 'india_hits', 'India Hits', 'Hindi cinema favourites', 'youtube_search', 'top bollywood hindi songs official music video', 15, true, true, 'auto'),
    s('punjabi', 'punjabi', 'Punjabi Bangers', 'Desi energy', 'youtube_search', 'latest punjabi pop hits official audio', 15, true, true, 'auto'),
    s('hindi_indie', 'hindi_indie', 'Hindi Indie', '', 'youtube_search', 'hindi indie songs official audio', 15, true, true, 'auto'),
    s('chill_lofi', 'chill_lofi', 'Chill & LoFi', 'Late night focus', 'youtube_search', 'chill lofi late night beats official audio', 15, true, true, 'auto'),
    s('editors_picks', 'editors_picks', 'Editor Picks', 'Hand-pinned', 'youtube_manual', '', 8, true, true, 'jiosaavn'),
    s('trending_for_you', 'trending_for_you', 'Trending For You', '', 'personalized', 'trending_for_you', 12, false, true, 'auto'),
  ];
  const items = {
    editors_picks: [
      { id: uid(), section_id: 'editors_picks', content_id: 'dQw4w9WgXcQ', youtube_video_id: 'dQw4w9WgXcQ', title: 'Never Gonna Give You Up', artist: 'Rick Astley', artwork_url: '', jiosaavn_url: '', provider: 'auto', playback_provider: 'auto', fallback_provider: 'none', sort_order: 0, is_enabled: true },
      { id: uid(), section_id: 'editors_picks', content_id: 'jsv_demo', youtube_video_id: '', title: 'Tum Hi Ho', artist: 'Arijit Singh', artwork_url: '', jiosaavn_url: 'https://www.jiosaavn.com/song/tum-hi-ho/RTdzdkFmQWs', provider: 'jiosaavn', playback_provider: 'jiosaavn', fallback_provider: 'youtube', sort_order: 1, is_enabled: true },
    ],
  };
  return { sections, items, categories: [], flags: KNOWN_FLAGS.map((f) => ({ key: f.key, value: f.key === 'enable_remote_home' || f.key === 'enable_jiosaavn_search_fallback', description: f.description })) };
}
function s(id, key, title, subtitle, sourceType, sourceValue, maxItems, visible, published, provider) {
  return {
    id, section_key: key, title, subtitle, section_type: sourceType === 'personalized' ? 'personalized' : 'home_section',
    source_type: sourceType, source_value: sourceValue, query: sourceValue, sort_order: 0,
    max_items: maxItems, visible, published, region_code: null, category_id: null, refresh_minutes: 60,
    provider, playback_provider: provider === 'jiosaavn' ? 'jiosaavn' : 'auto', fallback_provider: 'none',
  };
}

/* ── Helpers ──────────────────────────────────────────────────────────────── */
function sourceById(id) { return SOURCE_TYPES.find((t) => t.id === id) || SOURCE_TYPES[0]; }
function personalizedById(id) { return PERSONALIZED_KEYS.find((k) => k.id === id); }
function isManualSource(type) { return type === 'youtube_manual' || type === 'jiosaavn_manual' || type === 'manual'; }
function isPersonalizedSource(type) { return type === 'personalized'; }

function kindBadge(sec) {
  const t = sec.source_type || 'youtube_search';
  if (t === 'personalized') {
    const pk = personalizedById(sec.section_key || sec.id);
    if (pk?.id === 'continue_listening') return '<span class="badge badge-green">Continue</span>';
    return '<span class="badge badge-purple">Personalized</span>';
  }
  if (isManualSource(t)) return '<span class="badge badge-pink">Manual</span>';
  return '<span class="badge badge-blue">Catalog</span>';
}

function sourceLabel(sec) {
  const t = sec.source_type || 'youtube_search';
  if (t === 'personalized') {
    const pk = personalizedById(sec.section_key || sec.id);
    return pk ? `Engine: ${pk.engine}` : 'Recommendation engine';
  }
  return sourceById(t).label;
}

function providerChip(sec) {
  const p = (sec.provider || 'auto').toLowerCase();
  const label = p.includes('jiosaavn') ? 'JioSaavn' : p.includes('youtube') ? 'YouTube' : 'Auto';
  const cls = p.includes('jiosaavn') ? 'badge-green' : p.includes('youtube') ? 'badge-red' : 'badge-gray';
  return `<span class="badge ${cls}">▶ ${label}</span>`;
}

/* ══ DASHBOARD ═══════════════════════════════════════════════════════════════ */
async function renderDashboard(el) {
  try { await loadHome(); } catch (_) {}
  const sections = state.data.sections;
  const live = sections.filter((x) => x.visible !== false && x.published !== false).length;
  const hidden = sections.length - live;
  const manualCount = Object.values(state.data.items).reduce((n, arr) => n + arr.length, 0);
  el.innerHTML = `
    <div class="stats-grid">
      <div class="stat-card"><div class="stat-label">Home sections</div><div class="stat-value">${sections.length}</div></div>
      <div class="stat-card"><div class="stat-label">Live (visible + published)</div><div class="stat-value" style="color:var(--green)">${live}</div></div>
      <div class="stat-card"><div class="stat-label">Hidden / unpublished</div><div class="stat-value" style="color:var(--yellow)">${hidden}</div></div>
      <div class="stat-card"><div class="stat-label">Manual items</div><div class="stat-value" style="color:var(--pink)">${manualCount}</div></div>
    </div>
    <div class="card">
      <div class="card-title">How Home CMS works</div>
      <p class="muted mt8" style="font-size:14px;line-height:1.6">
        Edit shelves here, then <b style="color:var(--text)">Publish Home</b>. The V Shots app fetches
        <code>home_layout_config</code> + <code>home_section_items</code> on launch (1-hour cache, pull-to-refresh
        forces it) and rebuilds Home without a Play Store update. Personalized rows keep the on-device
        recommendation engine. Catalog rows use YouTube search / playlist / channel / trending / pinned videos.
        JioSaavn rows open the real JioSaavn webpage in the app's WebView — never an unofficial API.
        If Supabase is unreachable, the app falls back to compiled defaults.
      </p>
      <div class="btn-group mt12">
        <button class="btn btn-primary" id="go-cms">Open Home Management</button>
        <button class="btn" id="go-preview">Preview Home</button>
      </div>
    </div>`;
  $('go-cms').onclick = () => { state.page = 'home-cms'; renderAdmin(); };
  $('go-preview').onclick = () => openPreview(null);
}

/* ══ HOME MANAGEMENT ════════════════════════════════════════════════════════ */
async function renderHomeCMS(el) {
  // 1) LOADING state — explicit, never mistaken for empty.
  el.innerHTML = `<div style="text-align:center;padding:48px 12px">
      <div class="spinner"></div>
      <div class="muted small mt12">Loading Home sections…</div>
    </div>`;
  // CRITICAL: fetch from the server ONLY on entry/reload. While the user is
  // editing a draft, re-renders must keep the in-memory draft — a refetch
  // here silently discarded every edit (the real "changes not saving" bug).
  if (!state.homeLoaded) {
    try { await loadHome(); } catch (e) {
      // 2) ERROR state — real reason + Retry. NEVER "No sections yet" here.
      const reason = e?.message || String(e);
      el.innerHTML = `<div class="card">
        <div class="card-title">Couldn't load Home sections</div>
        <p class="login-error mt8">Supabase request failed: ${esc(reason)}</p>
        <p class="muted small mt8">Project: ${SUPABASE_URL.replace('https://', '')} — if this persists, check the network or Supabase status.</p>
        <button class="btn btn-primary mt12" id="retry-load">↻ Retry</button>
      </div>`;
      $('retry-load').onclick = () => renderHomeCMS(el);
      return;
    }
    state.homeLoaded = true;
  }
  const sections = state.data.sections;
  const live = sections.filter((x) => x.visible !== false && x.published !== false).length;

  el.innerHTML = `
    <div class="banner">🌐 Public mode — no login required (owner-approved). Anyone with this URL can view and publish Home content.</div>
    ${state.dirty ? '<div class="banner">⚠️ Unsaved changes — edits are live in the app only after you <b>Publish Home</b>.</div>' : ''}
    <div class="card">
      <div class="card-header">
        <div>
          <div class="card-title">Home Management</div>
          <div class="card-subtitle">Order is top-to-bottom in the app. Continue Listening is auto-added at the top by the app if you do not include it.</div>
        </div>
        <div class="btn-group">
          <button class="btn" id="add-catalog">+ Catalog</button>
          <button class="btn" id="add-personalized">+ Personalized</button>
          <button class="btn" id="add-jiosaavn">+ JioSaavn section</button>
          <button class="btn" id="preview-home">👁 Preview</button>
        </div>
      </div>
      <div class="sections-list" id="sections-list"></div>
    </div>
    <div class="publish-bar">
      <div class="publish-summary">
        ${state.dirty ? '<span class="dirty-dot"></span>' : ''}
        <span id="pub-status" style="font-weight:700">${state.dirty ? 'Unsaved changes' : 'Saved'}</span> ·
        <b>${sections.length}</b> sections · <b style="color:var(--green)">${live}</b> live ·
        <b style="color:var(--yellow)">${sections.length - live}</b> hidden/unpublished ·
        ${Object.values(state.data.items).reduce((n, a) => n + a.length, 0)} manual items
      </div>
      <button class="btn" id="reload-home">Reload</button>
      <button class="btn btn-success" id="publish-home">📡 Publish Home</button>
    </div>`;

  const list = $('sections-list');
  if (!sections.length) {
    list.innerHTML = `<div class="empty-state"><div class="icon">🏠</div><div class="title">No sections yet</div>
      <div class="desc">Add a catalog, personalized or JioSaavn section, then Publish.</div></div>`;
  } else {
    sections.forEach((sec, i) => {
      const items = state.data.items[sec.id] || [];
      const isPersonalized = isPersonalizedSource(sec.source_type);
      const isManual = isManualSource(sec.source_type);
      const published = sec.published !== false;
      const visible = sec.visible !== false;
      const d = document.createElement('div');
      d.className = 'section-card';
      d.dataset.index = i;
      d.innerHTML = `
        <div class="section-top">
          <div class="drag-handle" data-drag aria-label="Drag to reorder" title="Drag to reorder">⠿</div>
          <div class="section-order">${i + 1}</div>
          <div class="section-title-inline">${esc(sec.title || 'Untitled')}</div>
          <div class="section-badges">
            ${kindBadge(sec)}
            <span class="chip key-chip" title="Stable key">${esc(sec.section_key || sec.id)}</span>
          </div>
        </div>
        <div class="section-meta">
          <div class="meta-line"><span class="label">Source:</span><span class="value">${esc(sourceLabel(sec))}</span> ${providerChip(sec)}</div>
          ${!isPersonalized && !isManual ? `<div class="meta-line"><span class="label">Query:</span><span class="value">${esc(sec.source_value || sec.query || '—')}</span></div>` : ''}
          ${isPersonalized ? `<div class="meta-line"><span class="label">Type:</span><span class="value">Personalized · ${esc(personalizedById(sec.section_key || sec.id)?.engine || 'Recommendation engine')}</span></div>` : ''}
          ${isManual ? `<div class="meta-line"><span class="label">Items:</span><span class="value">${items.length} pinned</span></div>` : ''}
          <div class="meta-line"><span class="label">Max items:</span><span class="value">${sec.max_items || 15}</span></div>
        </div>
        <div class="section-toggles">
          <label class="toggle-label"><span class="switch"><input type="checkbox" data-toggle="visible" ${visible ? 'checked' : ''}><span class="slider"></span></span> Show in app</label>
          <label class="toggle-label"><span class="switch"><input type="checkbox" data-toggle="published" ${published ? 'checked' : ''}><span class="slider"></span></span> Published</label>
          <span class="badge ${published ? 'badge-green' : 'badge-yellow'}" data-pub-badge>${published ? 'Published' : 'Unpublished'}</span>
        </div>
        <div class="section-actions">
          <button class="btn btn-sm" data-action="edit">✏️ Edit</button>
          <button class="btn btn-sm" data-action="preview">👁 Preview</button>
          <span class="spacer"></span>
          <button class="btn btn-sm btn-icon" data-action="up" ${i === 0 ? 'disabled' : ''} aria-label="Move up">↑</button>
          <button class="btn btn-sm btn-icon" data-action="down" ${i === sections.length - 1 ? 'disabled' : ''} aria-label="Move down">↓</button>
          <button class="btn btn-sm btn-danger" data-action="delete">Delete</button>
        </div>`;
      list.appendChild(d);

      d.querySelector('[data-action="edit"]').onclick = () => openSectionEditor(sec, i);
      d.querySelector('[data-action="preview"]').onclick = () => openPreview(sec);
      d.querySelector('[data-action="up"]').onclick = () => {
        if (i > 0) { [sections[i], sections[i - 1]] = [sections[i - 1], sections[i]]; state.dirty = true; renderHomeCMS(el); }
      };
      d.querySelector('[data-action="down"]').onclick = () => {
        if (i < sections.length - 1) { [sections[i], sections[i + 1]] = [sections[i + 1], sections[i]]; state.dirty = true; renderHomeCMS(el); }
      };
      d.querySelector('[data-action="delete"]').onclick = () => {
        if (!confirm(`Delete "${sec.title}"? This takes effect on next Publish.`)) return;
        sections.splice(i, 1);
        delete state.data.items[sec.id];
        state.dirty = true;
        renderHomeCMS(el);
      };
      d.querySelectorAll('[data-toggle]').forEach((chk) => {
        chk.onchange = () => {
          sec[chk.dataset.toggle] = chk.checked;
          state.dirty = true;
          const badge = d.querySelector('[data-pub-badge]');
          if (badge) {
            badge.textContent = sec.published !== false ? 'Published' : 'Unpublished';
            badge.className = `badge ${sec.published !== false ? 'badge-green' : 'badge-yellow'}`;
          }
          $('publish-home') && renderHomeCMS(el); // refresh summary counts
        };
      });
    });
  }

  $('add-catalog').onclick = () => {
    sections.push({
      id: uid(), section_key: `home_${Date.now()}`, title: 'New section', subtitle: '',
      section_type: 'home_section', source_type: 'youtube_search', source_value: '', query: '',
      max_items: 15, visible: true, published: true, region_code: '', category_id: null, refresh_minutes: 60,
      provider: 'auto', playback_provider: 'auto', fallback_provider: 'none',
    });
    state.dirty = true;
    openSectionEditor(sections[sections.length - 1], sections.length - 1);
  };
  $('add-personalized').onclick = () => {
    const used = new Set(sections.map((x) => x.section_key));
    const next = PERSONALIZED_KEYS.find((k) => !used.has(k.id)) || PERSONALIZED_KEYS[1];
    sections.push({
      id: next.id === 'continue_listening' ? `continue_${Date.now()}` : next.id,
      section_key: next.id, title: next.title, subtitle: '',
      section_type: 'personalized', source_type: 'personalized', source_value: next.id, query: '',
      max_items: 12, visible: true, published: true, region_code: '', category_id: null, refresh_minutes: 60,
      provider: 'auto', playback_provider: 'auto', fallback_provider: 'none',
    });
    state.dirty = true;
    renderHomeCMS(el);
    toast(`Added "${next.title}" (draft — publish to apply)`);
  };
  $('add-jiosaavn').onclick = () => {
    sections.push({
      id: uid(), section_key: `jiosaavn_${Date.now()}`, title: 'JioSaavn Section', subtitle: '',
      section_type: 'home_section', source_type: 'jiosaavn_manual', source_value: '', query: '',
      max_items: 8, visible: false, published: false, region_code: '', category_id: null, refresh_minutes: 60,
      provider: 'jiosaavn', playback_provider: 'jiosaavn', fallback_provider: 'youtube',
    });
    state.data.items[sections[sections.length - 1].id] = [];
    state.dirty = true;
    openSectionEditor(sections[sections.length - 1], sections.length - 1);
    toast('JioSaavn section added — paste real /song/ permalinks, then publish. Search fallback needs the flag ON.', 'warn');
  };
  $('preview-home').onclick = () => openPreview(null);
  $('reload-home').onclick = () => { state.dirty = false; state.homeLoaded = false; renderHomeCMS(el); toast('Reloaded from Supabase'); };
  $('publish-home').onclick = () => validateAndPublish(el);

  initDragReorder(list);

  // Live data-source status footer — makes it obvious the panel is talking
  // to the real production DB (and shows sync health).
  const sync = state.sync;
  const footer = document.createElement('div');
  footer.className = 'muted small';
  footer.style.cssText = 'display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-top:12px';
  footer.innerHTML = `
    <span class="chip">Supabase: jzxtxqjheggyoqwohqjg</span>
    <span class="chip">${sections.length} sections · ${Object.values(state.data.items).reduce((n, a) => n + a.length, 0)} items</span>
    <span class="chip">synced ${sync?.at ? new Date(sync.at).toLocaleTimeString() : '—'}</span>
    <span class="chip" style="${sync?.ok ? 'color:var(--green)' : 'color:var(--red)'}">${sync?.ok ? '● connected' : '● error'}</span>`;
  el.appendChild(footer);
}

/* ── Touch + mouse drag reorder ───────────────────────────────────────────── */
function initDragReorder(listEl) {
  let active = null, startY = 0, moved = false, lastTarget = null;
  listEl.querySelectorAll('.drag-handle').forEach((handle) => {
    handle.addEventListener('pointerdown', (e) => {
      if (e.pointerType === 'mouse' && e.button !== 0) return;
      active = handle.closest('.section-card');
      startY = e.clientY; moved = false; lastTarget = null;
      active.classList.add('dragging');
      try { handle.setPointerCapture(e.pointerId); } catch (_) {}
    });
    handle.addEventListener('pointermove', (e) => {
      if (!active) return;
      if (!moved && Math.abs(e.clientY - startY) < 6) return;
      moved = true;
      const found = document.elementFromPoint(e.clientX, e.clientY);
      const card = found ? found.closest('.section-card') : null;
      if (card && card !== active && card.parentElement === listEl) {
        if (lastTarget && lastTarget !== card) lastTarget.classList.remove('drag-over');
        card.classList.add('drag-over');
        lastTarget = card;
      }
    });
    const finish = () => {
      if (!active) return;
      const card = active;
      active = null;
      card.classList.remove('dragging');
      if (lastTarget) lastTarget.classList.remove('drag-over');
      if (moved && lastTarget && lastTarget !== card) {
        const from = Number(card.dataset.index);
        const to = Number(lastTarget.dataset.index);
        const arr = state.data.sections;
        const [item] = arr.splice(from, 1);
        arr.splice(to, 0, item);
        state.dirty = true;
      }
      renderHomeCMS($('content'));
    };
    handle.addEventListener('pointerup', finish);
    handle.addEventListener('pointercancel', finish);
  });
}

/* ── Section editor modal ─────────────────────────────────────────────────── */
function openSectionEditor(sec, index) {
  const draft = JSON.parse(JSON.stringify(sec));
  const items = state.data.items[sec.id] || [];
  const isPersonalized = isPersonalizedSource(draft.source_type);
  const isManual = isManualSource(draft.source_type);

  openModal(`
    <div class="modal-title">Edit section</div>
    <div class="modal-subtitle muted small">${esc(sec.id)}${sec.id !== sec.section_key ? ` · key ${esc(sec.section_key)}` : ''}</div>`,
  `
    <div class="form-row cols-2">
      <div class="form-group">
        <label class="form-label">Title</label>
        <input class="form-input" data-f="title" value="${esc(draft.title)}" placeholder="Section title">
        <div class="field-error" data-err="title">Title is required</div>
      </div>
      <div class="form-group">
        <label class="form-label">Subtitle <span class="muted">(optional)</span></label>
        <input class="form-input" data-f="subtitle" value="${esc(draft.subtitle || '')}" placeholder="Why this section?">
      </div>
    </div>
    <div class="form-row cols-2">
      <div class="form-group">
        <label class="form-label">Type</label>
        <select class="form-select" data-f="source_type">
          ${SOURCE_TYPES.map((t) => `<option value="${t.id}" ${draft.source_type === t.id ? 'selected' : ''}>${t.label}</option>`).join('')}
        </select>
      </div>
      <div class="form-group">
        <label class="form-label">Provider (playback routing)</label>
        <select class="form-select" data-f="provider">
          <option value="auto" ${(draft.provider || 'auto') === 'auto' ? 'selected' : ''}>Auto — smart fallback</option>
          <option value="youtube" ${(draft.provider || '').includes('youtube') ? 'selected' : ''}>YouTube only</option>
          <option value="jiosaavn" ${(draft.provider || '').includes('jiosaavn') ? 'selected' : ''}>JioSaavn (webpage)</option>
        </select>
        <div class="form-hint">Auto = JioSaavn permalink if enabled → YouTube → JioSaavn search fallback.</div>
      </div>
    </div>
    <div class="form-group" data-block="personalized" style="${isPersonalized ? '' : 'display:none'}">
      <label class="form-label">Personalized engine</label>
      <select class="form-select" data-f="section_key">
        ${PERSONALIZED_KEYS.map((k) => `<option value="${k.id}" ${draft.section_key === k.id ? 'selected' : ''}>${k.title} — ${k.engine}</option>`).join('')}
      </select>
      <div class="form-hint">Personalized sections use the on-device recommendation engine — they are never a literal YouTube search.</div>
    </div>
    <div data-block="catalog" style="${isPersonalized ? 'display:none' : ''}">
      <div class="form-row cols-2">
        <div class="form-group">
          <label class="form-label" data-sv-label>${isManual ? '' : 'Query / source value'}</label>
          <input class="form-input" data-f="source_value" value="${esc(draft.source_value || draft.query || '')}" placeholder="${esc(sourceById(draft.source_type).hint)}">
          <div class="field-error" data-err="source_value">Required for this source type</div>
          <div class="form-hint" data-sv-hint></div>
        </div>
        <div class="form-group" data-block="region" style="${draft.source_type === 'youtube_trending' ? '' : 'display:none'}">
          <label class="form-label">Region code <span class="muted">(trending)</span></label>
          <input class="form-input" data-f="region_code" value="${esc(draft.region_code || '')}" placeholder="IN / US / GB / blank">
        </div>
      </div>
      <div class="form-hint">${esc(sourceById(draft.source_type).hint)}</div>
      <div data-block="jpl-note" style="${draft.source_type === 'jiosaavn_playlist' ? '' : 'display:none'}">
        <div class="banner">🎧 The app opens the OFFICIAL JioSaavn playlist page in its WebView — the playlist plays there, so no songs need to be added manually. Track listing/metadata is intentionally NOT scraped (no unofficial API).</div>
      </div>
    </div>
    <div class="form-row cols-3">
      <div class="form-group">
        <label class="form-label">Max items</label>
        <input class="form-input" type="number" min="1" max="100" data-f="max_items" value="${draft.max_items || 15}">
      </div>
      <div class="form-group">
        <label class="form-label">Refresh (minutes)</label>
        <input class="form-input" type="number" min="5" max="1440" data-f="refresh_minutes" value="${draft.refresh_minutes || 60}">
      </div>
      <div class="form-group" style="display:flex;gap:16px;align-items:center;padding-top:22px">
        <label class="form-check"><span class="switch"><input type="checkbox" data-f="visible" ${draft.visible !== false ? 'checked' : ''}><span class="slider"></span></span> Show in app</label>
        <label class="form-check"><span class="switch"><input type="checkbox" data-f="published" ${draft.published !== false ? 'checked' : ''}><span class="slider"></span></span> Published</label>
      </div>
    </div>
    <div data-block="manual" style="${isManual ? '' : 'display:none'}">
      <hr class="divider">
      <div class="card-subtitle" style="margin-bottom:4px">Manual items — Title, Artist, Artwork, YouTube &amp; JioSaavn URLs, per-item provider.</div>
      <div class="form-hint" style="margin-bottom:10px">JioSaavn: only public webpage URLs (permalink / search). Media &amp; stream URLs are rejected — no extraction.</div>
      <div class="items-list" data-items></div>
      <button class="btn btn-sm mt8" data-add-item>+ Add item</button>
    </div>`,
  `
    <button class="btn" data-cancel>Cancel</button>
    <button class="btn" data-preview-sec>👁 Resolve &amp; Preview</button>
    <button class="btn btn-primary" data-save>Save section</button>
  `);

  const modal = document.querySelector('.modal');
  const srcSelect = modal.querySelector('[data-f="source_type"]');
  const syncBlocks = () => {
    const t = srcSelect.value;
    const st = sourceById(t);
    modal.querySelector('[data-block="personalized"]').style.display = t === 'personalized' ? '' : 'none';
    modal.querySelector('[data-block="catalog"]').style.display = t === 'personalized' ? 'none' : '';
    modal.querySelector('[data-block="manual"]').style.display = isManualSource(t) ? '' : 'none';
    const regionGroup = modal.querySelector('[data-block="region"]');
    if (regionGroup) regionGroup.style.display = t === 'youtube_trending' ? '' : 'none';
    const jplNote = modal.querySelector('[data-block="jpl-note"]');
    if (jplNote) jplNote.style.display = t === 'jiosaavn_playlist' ? '' : 'none';
    const svInput = modal.querySelector('[data-f="source_value"]');
    svInput.placeholder = esc(st.hint);
    svInput.style.display = (st.valueField === 'none' || isManualSource(t)) ? 'none' : '';
    const svLabel = modal.querySelector('[data-sv-label]');
    if (svLabel) {
      svLabel.style.display = (st.valueField === 'none' || isManualSource(t)) ? 'none' : '';
      svLabel.textContent = st.valueField === 'url' ? 'URL' : 'Search query';
    }
    // live URL validation for url-typed sources
    const svHint = modal.querySelector('[data-sv-hint]');
    if (svHint) {
      svHint.textContent = '';
      svInput.oninput = () => {
        const v = svInput.value.trim();
        if (!v) { svHint.textContent = ''; return; }
        if (t === 'youtube_playlist') {
          const ok = /list=[A-Za-z0-9_-]{10,}/.test(v) || /^PL[A-Za-z0-9_-]{10,}$/.test(v) || /^RDCLAK5uy_[A-Za-z0-9_-]+$/.test(v);
          svHint.textContent = ok ? '✓ playlist reference detected' : '⚠ not a playlist URL / PL… id';
          svHint.style.color = ok ? 'var(--green)' : 'var(--red)';
        } else if (t === 'youtube_channel') {
          const ok = /^(UC[A-Za-z0-9_-]{22}|@[A-Za-z0-9_.-]{3,64})$/.test(v) || /\/channel\/UC|youtube\.com\/@/.test(v);
          svHint.textContent = ok ? '✓ channel reference detected' : '⚠ not a channel URL / UC id / @handle';
          svHint.style.color = ok ? 'var(--green)' : 'var(--red)';
        } else if (t === 'jiosaavn_playlist') {
          const jio = inspectJioSaavnUrl(v);
          const isPl = /\/featured\/|\/s\/playlist\//.test(v);
          svHint.textContent = (jio.ok && isPl) ? '✓ official JioSaavn playlist page' : (jio.ok ? jio.text : '⚠ ' + jio.text);
          svHint.style.color = (jio.ok && isPl) ? 'var(--green)' : 'var(--red)';
        } else {
          svHint.textContent = '';
        }
      };
      svInput.oninput();
    }
  };
  srcSelect.onchange = syncBlocks;
  syncBlocks();

  /* items editor */
  const itemsBox = modal.querySelector('[data-items]');
  const renderItems = () => {
    itemsBox.innerHTML = items.map((it, idx) => {
      const jio = inspectJioSaavnUrl(it.jiosaavn_url || '');
      const yt = inspectYoutubeInput(it.youtube_video_id || '');
      const provider = (it.provider || 'auto').toLowerCase();
      const playback = (it.playback_provider || 'auto').toLowerCase();
      const fallback = (it.fallback_provider || 'none').toLowerCase();
      return `
      <div class="item-card" data-idx="${idx}">
        <div class="item-head">
          <span class="badge badge-gray">#${idx + 1}</span>
          <span class="title">${esc(it.title || 'Untitled item')}</span>
          <button class="btn btn-sm btn-danger" data-del aria-label="Remove item">✕</button>
        </div>
        <div class="form-row cols-2">
          <div class="form-group">
            <label class="form-label">Title</label>
            <input class="form-input" data-if="title" value="${esc(it.title || '')}" placeholder="Song title">
          </div>
          <div class="form-group">
            <label class="form-label">Artist</label>
            <input class="form-input" data-if="artist" value="${esc(it.artist || '')}" placeholder="Artist">
          </div>
        </div>
        <div class="form-group">
          <label class="form-label">Artwork URL <span class="muted">(HTTPS image, optional)</span></label>
          <input class="form-input" data-if="artwork_url" value="${esc(it.artwork_url || '')}" placeholder="https://… (blank = YouTube thumbnail)">
        </div>
        <div class="form-row cols-2">
          <div class="form-group">
            <label class="form-label">YouTube URL / ID</label>
            <input class="form-input ${!yt.ok ? 'invalid' : ''}" data-if="youtube_video_id" value="${esc(it.youtube_video_id || '')}" placeholder="dQw4w9WgXcQ or watch URL">
            <div class="form-hint" data-yt-status style="color:${yt.ok && yt.id ? 'var(--green)' : yt.text ? 'var(--red)' : 'var(--text2)'}">${esc(yt.text || 'Optional if a JioSaavn permalink is set')}</div>
          </div>
          <div class="form-group">
            <label class="form-label">JioSaavn URL <span class="muted">(permalink only)</span></label>
            <input class="form-input ${jio.ok && it.jiosaavn_url ? '' : (!jio.ok ? 'invalid' : '')}" data-if="jiosaavn_url" value="${esc(it.jiosaavn_url || '')}" placeholder="https://www.jiosaavn.com/song/…">
            <div class="form-hint" style="color:${jio.ok && it.jiosaavn_url ? 'var(--green)' : !jio.ok ? 'var(--red)' : 'var(--text2)'}">${esc(jio.text || 'Optional if a YouTube video is set')}</div>
          </div>
        </div>
        <div class="form-row cols-3">
          <div class="form-group">
            <label class="form-label">Provider</label>
            <select class="form-select" data-if="provider">
              <option value="auto" ${provider === 'auto' ? 'selected' : ''}>Auto</option>
              <option value="youtube" ${provider.includes('youtube') ? 'selected' : ''}>YouTube</option>
              <option value="jiosaavn" ${provider.includes('jiosaavn') ? 'selected' : ''}>JioSaavn</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">Playback</label>
            <select class="form-select" data-if="playback_provider">
              <option value="auto" ${playback === 'auto' ? 'selected' : ''}>Auto</option>
              <option value="youtube" ${playback.includes('youtube') && !playback.includes('jiosaavn') ? 'selected' : ''}>YouTube</option>
              <option value="jiosaavn" ${playback.includes('jiosaavn') ? 'selected' : ''}>JioSaavn</option>
            </select>
          </div>
          <div class="form-group">
            <label class="form-label">Fallback</label>
            <select class="form-select" data-if="fallback_provider">
              <option value="none" ${fallback === 'none' || !fallback ? 'selected' : ''}>None</option>
              <option value="youtube" ${fallback.includes('youtube') ? 'selected' : ''}>YouTube</option>
              <option value="jiosaavn" ${fallback.includes('jiosaavn') ? 'selected' : ''}>JioSaavn</option>
            </select>
          </div>
        </div>
        <label class="form-check"><span class="switch"><input type="checkbox" data-if-en ${it.is_enabled !== false ? 'checked' : ''}><span class="slider"></span></span> Enabled</label>
      </div>`;
    }).join('') || '<div class="muted small">No items yet — add one below.</div>';

    itemsBox.querySelectorAll('.item-card').forEach((card) => {
      const idx = Number(card.dataset.idx);
      card.querySelector('[data-del]').onclick = () => { items.splice(idx, 1); renderItems(); };
      card.querySelectorAll('[data-if]').forEach((input) => {
        input.onchange = () => {
          items[idx][input.dataset.if] = input.value;
          if (input.dataset.if === 'youtube_video_id') items[idx].content_id = extractYoutubeId(input.value) || input.value;
          renderItems();
        };
      });
      const en = card.querySelector('[data-if-en]');
      if (en) en.onchange = () => { items[idx].is_enabled = en.checked; };
    });
  };
  renderItems();
  modal.querySelector('[data-add-item]').onclick = () => {
    items.push({
      id: uid(), section_id: sec.id, youtube_video_id: '', content_id: '', title: '', artist: '',
      artwork_url: '', jiosaavn_url: '',
      provider: draft.source_type === 'jiosaavn_manual' ? 'jiosaavn' : 'auto',
      playback_provider: draft.source_type === 'jiosaavn_manual' ? 'jiosaavn' : 'auto',
      fallback_provider: draft.source_type === 'jiosaavn_manual' ? 'youtube' : 'none',
      sort_order: items.length, is_enabled: true,
    });
    renderItems();
  };

  modal.querySelector('[data-cancel]').onclick = closeModal;
  modal.querySelector('[data-preview-sec]').onclick = () => {
    const t = srcSelect.value;
    const value = (modal.querySelector('[data-f="source_value"]').value || '').trim();
    const maxItems = Math.max(1, Math.min(50, parseInt(modal.querySelector('[data-f="max_items"]').value, 10) || 15));
    resolveAndPreviewContent(t, value, maxItems, draft.title || '');
  };
  modal.querySelector('[data-save]').onclick = () => {
    /* read form back into draft */
    modal.querySelectorAll('[data-f]').forEach((input) => {
      const f = input.dataset.f;
      if (input.type === 'checkbox') draft[f] = input.checked;
      else if (f === 'max_items' || f === 'refresh_minutes') draft[f] = parseInt(input.value, 10) || 15;
      else draft[f] = input.value;
    });
    if (draft.source_type === 'personalized') {
      draft.section_type = 'personalized';
      draft.source_value = draft.section_key;
      draft.query = '';
      const pk = personalizedById(draft.section_key);
      if (pk && pk.id !== 'continue_listening') draft.title = draft.title || pk.title;
    } else if (isManualSource(draft.source_type)) {
      draft.section_type = 'home_section';
    } else {
      draft.section_type = 'home_section';
      draft.query = draft.source_value || '';
    }
    /* validate */
    let bad = false;
    const mark = (name, on) => { const e = modal.querySelector(`[data-err="${name}"]`); if (e) e.classList.toggle('show', on); if (on) bad = true; };
    mark('title', !(draft.title || '').trim());
    mark('source_value', !isPersonalizedSource(draft.source_type) && !isManualSource(draft.source_type) && draft.source_type !== 'youtube_trending' && !(draft.source_value || '').trim());
    if (isManualSource(draft.source_type)) {
      for (const it of items) {
        if (it.is_enabled === false) continue;
        const jio = inspectJioSaavnUrl(it.jiosaavn_url || '');
        const yt = inspectYoutubeInput(it.youtube_video_id || '');
        if (!jio.ok) { toast(`Invalid JioSaavn URL in “${it.title || 'item'}”: ${jio.text}`, 'error'); bad = true; }
        if (!yt.ok) { toast(`Invalid YouTube ID in “${it.title || 'item'}”: ${yt.text}`, 'error'); bad = true; }
      }
    }
    if (bad) return;
    Object.assign(sec, draft);
    state.data.items[sec.id] = items;
    state.dirty = true;
    closeModal();
    renderHomeCMS($('content'));
    toast('Section updated (draft — Publish Home to apply)');
  };
}

/* ── Preview modal ────────────────────────────────────────────────────────── */
function openPreview(sec) {
  const sections = sec ? [sec] : state.data.sections;
  const shown = sections.filter((x) => x.visible !== false && x.published !== false);
  const hasContinue = sections.some((x) => isPersonalizedSource(x.source_type) && x.section_key === 'continue_listening');
  const body = `
    <div class="phone-frame">
      <div class="phone-screen">
        ${!sec && !hasContinue ? `
        <div class="preview-shelf">
          <div class="preview-shelf-head"><span class="preview-shelf-title">Continue Listening</span><span class="badge badge-green">auto</span></div>
          <div class="preview-empty">Added automatically by the app at the top (recently played).</div>
        </div>` : ''}
        ${sections.map((x, i) => {
          const items = state.data.items[x.id] || [];
          const on = x.visible !== false && x.published !== false;
          const t = x.source_type || 'youtube_search';
          let badge = '';
          if (t === 'personalized') badge = '<span class="badge badge-purple">Personalized</span>';
          else if (isManualSource(t)) badge = '<span class="badge badge-pink">Manual</span>';
          else badge = '<span class="badge badge-blue">Catalog</span>';
          let cards = '';
          if (isManualSource(t)) {
            cards = items.length
              ? `<div class="preview-cards">${items.map((it) => {
                  const p = (it.provider || 'auto').toLowerCase();
                  const chip = p.includes('jiosaavn') ? 'JS' : p.includes('youtube') ? 'YT' : 'A';
                  return `<div class="preview-card">${esc(it.title || 'Untitled')}<br><small>${chip}</small></div>`;
                }).join('')}</div>`
              : `<div class="preview-empty">No pinned items</div>`;
          } else if (t === 'personalized') {
            cards = `<div class="preview-empty">Generated by the recommendation engine on the device.</div>`;
          } else {
            cards = `<div class="preview-empty">Query: ${esc(x.source_value || x.query || '—')}</div>`;
          }
          return `
          <div class="preview-shelf ${on ? '' : 'off'}">
            <div class="preview-shelf-head">
              <span class="preview-shelf-title">${i + 1}. ${esc(x.title)}</span>
              ${badge}
              ${on ? '' : '<span class="badge badge-yellow">hidden</span>'}
            </div>
            ${cards}
          </div>`;
        }).join('')}
      </div>
    </div>
    <p class="muted small mt12" style="text-align:center">Preview of draft state (${shown.length}/${sections.length} visible). Actual content is fetched by the app per query.</p>`;

  openModal(`<div class="modal-title">👁 ${sec ? 'Section preview' : 'Home preview'}</div>`, body, `<button class="btn btn-primary" data-close>Close</button>`);
  document.querySelector('[data-close]').onclick = closeModal;
}

/* ── Publish ──────────────────────────────────────────────────────────────── */
function validateAll() {
  const errors = [];
  const warnings = [];
  const sections = state.data.sections;
  if (!sections.length) { errors.push('No sections to publish'); return { errors, warnings }; }
  sections.forEach((sec, i) => {
    const name = `${i + 1}. ${sec.title || '(untitled)'}`;
    if (!(sec.title || '').trim()) errors.push(`${name}: title is required`);
    const t = sec.source_type || 'youtube_search';
    if (t === 'jiosaavn_playlist') {
      const v = (sec.source_value || '').trim();
      const jio = inspectJioSaavnUrl(v);
      if (!v) errors.push(`${name}: a JioSaavn playlist URL is required`);
      else if (!(jio.ok && /\/featured\/|\/s\/playlist\//.test(v))) {
        errors.push(`${name}: ${jio.ok ? 'not a playlist page (use /featured/ or /s/playlist/)' : jio.text}`);
      }
    } else if (!isPersonalizedSource(t) && !isManualSource(t) && t !== 'youtube_trending' && !(sec.source_value || sec.query || '').trim()) {
      errors.push(`${name}: query/source value is required for ${sourceById(t).label}`);
    }
    if (isManualSource(t)) {
      const items = state.data.items[sec.id] || [];
      const jioFlag = (state.data.flags.find((f) => f.key === 'enable_jiosaavn_web_playback') || {}).value === true;
      items.forEach((it, j) => {
        if (it.is_enabled === false) return;
        const itName = it.title || `item #${j + 1}`;
        const yt = inspectYoutubeInput(it.youtube_video_id || '');
        const jio = inspectJioSaavnUrl(it.jiosaavn_url || '');
        if (!yt.ok) errors.push(`${name} → ${itName}: ${yt.text}`);
        if (!jio.ok) errors.push(`${name} → ${itName}: ${jio.text}`);
        const provider = (it.provider || 'auto').toLowerCase();
        const playback = (it.playback_provider || 'auto').toLowerCase();
        const wantsJio = provider.includes('jiosaavn') || playback.includes('jiosaavn');
        if (!yt.id && !it.jiosaavn_url) {
          errors.push(`${name} → ${itName}: needs a YouTube video or a JioSaavn permalink`);
        } else if (wantsJio && !jioFlag) {
          warnings.push(`${name} → ${itName}: JioSaavn playback is OFF (enable_jiosaavn_web_playback). The app will fall back to YouTube or skip it.`);
        } else if (wantsJio && !/\/song\//.test(it.jiosaavn_url || '') && !(state.data.flags.find((f) => f.key === 'enable_jiosaavn_search_fallback') || {}).value) {
          warnings.push(`${name} → ${itName}: no exact permalink and search fallback is OFF — the app may not play this via JioSaavn.`);
        }
      });
    }
  });
  return { errors, warnings };
}

function validateAndPublish(el) {
  const { errors, warnings } = validateAll();
  if (errors.length) {
    openModal(
      `<div class="modal-title">⚠️ Cannot publish — fix these first</div>`,
      `<ul class="err-list">${errors.map((e) => `<li>${esc(e)}</li>`).join('')}</ul>`,
      `<button class="btn btn-primary" data-close>OK, I'll fix them</button>`,
    );
    document.querySelector('[data-close]').onclick = closeModal;
    return;
  }
  if (warnings.length) {
    openModal(
      `<div class="modal-title">Publish with warnings?</div>`,
      `<ul class="err-list warn-list">${warnings.map((e) => `<li>⚠️ ${esc(e)}</li>`).join('')}</ul>
       <p class="muted small mt12">You can still publish — warnings may mean some items don't play until flags change.</p>`,
      `<button class="btn" data-close>Cancel</button><button class="btn btn-success" data-confirm>Publish anyway</button>`,
    );
    document.querySelector('[data-close]').onclick = closeModal;
    document.querySelector('[data-confirm]').onclick = () => { closeModal(); doPublish(el); };
    return;
  }
  doPublish(el);
}

async function doPublish(el) {
  const btn = $('publish-home');
  const statusEl = $('pub-status');
  const setStatus = (text, color) => {
    if (!statusEl) return;
    statusEl.textContent = text;
    statusEl.style.color = color || 'var(--text)';
  };
  setStatus('Publishing…', 'var(--yellow)');
  setBusy(btn, true, 'Publishing…');
  try {
    const sections = state.data.sections;
    const { data: existing, error: existingErr } = await supabase.from('home_layout_config').select('id');
    if (existingErr) throw existingErr;
    const keep = new Set();
    const rows = sections.map((sec, i) => {
      const id = sec.id || uid();
      keep.add(id);
      const t = sec.source_type || 'youtube_search';
      const personalized = t === 'personalized';
      const sourceValue = personalized ? (sec.section_key || id) : (sec.source_value || sec.query || '');
      const provider = normalize(sec.provider, 'auto');
      const playback = normalize(sec.playback_provider, provider);
      const fallback = normalize(sec.fallback_provider, 'none');
      return {
        id,
        section_key: sec.section_key || (personalized ? id : `home_${id}`),
        title: (sec.title || 'New section').trim(),
        subtitle: (sec.subtitle || '').trim() || null,
        section_type: personalized ? 'personalized' : (sec.section_type || 'home_section'),
        source_type: t,
        source_value: sourceValue || null,
        query: personalized ? null : (sourceValue || null),
        sort_order: i,
        visible: sec.visible !== false,
        published: sec.published !== false,
        max_items: Math.max(1, Math.min(100, Number(sec.max_items) || 15)),
        region_code: (sec.region_code || '').trim() || null,
        category_id: sec.category_id || null,
        refresh_minutes: Math.max(5, Number(sec.refresh_minutes) || 60),
        provider, playback_provider: playback, fallback_provider: fallback,
      };
    });
    const stale = (existing || []).map((x) => x.id).filter((id) => !keep.has(id));
    if (stale.length) {
      const { error } = await supabase.from('home_layout_config').delete().in('id', stale);
      if (error) throw error;
    }
    if (rows.length) {
      const { error } = await supabase.from('home_layout_config').upsert(rows, { onConflict: 'id' });
      if (error) throw error;
    }

    /* items: NON-DESTRUCTIVE publish — upsert by id first, then remove only
       rows that are no longer part of the draft (never a blanket wipe). */
    const itemRows = [];
    for (const row of rows) {
      const listItems = state.data.items[row.id] || [];
      for (let idx = 0; idx < listItems.length; idx += 1) {
        const it = listItems[idx];
        if (it.is_enabled === false) continue;
        const yt = inspectYoutubeInput(it.youtube_video_id || '');
        const jio = inspectJioSaavnUrl(it.jiosaavn_url || '');
        if (!yt.ok || !jio.ok) continue; /* validated above */
        const jioUrl = (it.jiosaavn_url || '').trim();
        if (!yt.id && !jioUrl) continue;
        const provider = normalize(it.provider, 'auto');
        const playback = normalize(it.playback_provider, provider === 'auto' ? 'auto' : provider);
        const fallback = normalize(it.fallback_provider, 'none');
        itemRows.push({
          id: it.id || uid(),
          section_id: row.id,
          content_id: yt.id || it.content_id || it.id || uid(),
          title: (it.title || '').trim() || yt.id || 'Untitled',
          artist: (it.artist || '').trim() || null,
          artwork_url: (it.artwork_url || '').trim() || (yt.id ? `https://img.youtube.com/vi/${yt.id}/hqdefault.jpg` : null),
          youtube_video_id: yt.id || null,
          jiosaavn_url: jioUrl || null,
          sort_order: idx,
          is_enabled: true,
          provider, playback_provider: playback, fallback_provider: fallback,
        });
      }
    }
    if (itemRows.length) {
      const { error } = await supabase.from('home_section_items').upsert(itemRows, { onConflict: 'id' });
      if (error) throw error;
    }
    const { data: existingItems, error: existingItemsErr } = await supabase.from('home_section_items').select('id');
    if (existingItemsErr) throw existingItemsErr;
    const keepItemIds = new Set(itemRows.map((r) => r.id));
    const staleItemIds = (existingItems || []).map((x) => x.id).filter((id) => !keepItemIds.has(id));
    if (staleItemIds.length) {
      const { error } = await supabase.from('home_section_items').delete().in('id', staleItemIds);
      if (error) throw error;
    }
    await supabase.from('home_config').upsert({
      id: 'current',
      // version is an INTEGER column — epoch SECONDS (Date.now()/1000), not ms.
      version: Math.floor(Date.now() / 1000),
      status: 'published',
      published_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
    state.data.sections = rows;
    state.dirty = false;
    setStatus(`Published ✓ ${new Date().toLocaleTimeString()}`, 'var(--green)');
    toast(`✅ Published ${rows.length} section(s), ${itemRows.length} manual item(s). App picks this up within ~1 hour (pull-to-refresh forces it).`);
    await loadHome();
    renderHomeCMS(el);
  } catch (e) {
    setStatus('Publish failed', 'var(--red)');
    toast(`Publish failed: ${e.message || e}`, 'error');
    // Draft + form state are preserved: state.data.sections is untouched on
    // error, so the user's changes stay visible for retry.
  } finally {
    setBusy(btn, false);
  }
}
function normalize(raw, fallback) {
  const v = String(raw || '').toLowerCase();
  if (v.includes('jiosaavn')) return 'jiosaavn';
  if (v.includes('youtube')) return 'youtube';
  if (v.includes('auto')) return 'auto';
  return fallback;
}

/* ══ LIVE CONTENT RESOLUTION (admin preview via constrained pg_net RPCs) ════ */
const innerTubeKey = { booted: false };
const sleepMs = (ms) => new Promise((r) => setTimeout(r, ms));

async function rpcCall(fn, params) {
  const { data, error } = await supabase.rpc(fn, params || {});
  if (error) throw new Error(error.message || String(error));
  return data;
}

async function ensureInnerTubeBoot() {
  if (innerTubeKey.booted) return;
  const reqId = await rpcCall('inner_tube_boot_request');
  await sleepMs(1500);
  try { await rpcCall('inner_tube_boot_collect', { p_request_id: reqId }); } catch (_) {}
  innerTubeKey.booted = true;
}

/// Walks a raw InnerTube response for BOTH renderer generations and returns
/// normalized {id,title,artist,thumb} items in page order.
function parseInnerTubeItems(json) {
  const out = [];
  const seen = new Set();
  const walk = (n) => {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) { n.forEach(walk); return; }
    const vr = n.videoRenderer;
    if (vr && vr.videoId) {
      const title = vr.title?.runs?.[0]?.text || '';
      const artist = vr.ownerText?.runs?.[0]?.text || vr.longBylineText?.runs?.[0]?.text || vr.shortBylineText?.runs?.[0]?.text || '';
      if (!seen.has(vr.videoId)) {
        seen.add(vr.videoId);
        out.push({ id: vr.videoId, title, artist, thumb: vr.thumbnail?.thumbnails?.slice(-1)[0]?.url || `https://img.youtube.com/vi/${vr.videoId}/hqdefault.jpg` });
      }
    }
    const lv = n.lockupViewModel;
    if (lv && lv.contentId && String(lv.contentType || '').includes('VIDEO')) {
      const title = lv.metadata?.lockupMetadataViewModel?.title?.content || '';
      const rows = lv.metadata?.lockupMetadataViewModel?.metadata?.rows || [];
      const artist = rows.map((r) => (r.metadataParts || []).map((p) => p.text?.content || '').join(' ')).filter(Boolean).join(' · ');
      const srcs = lv.contentImage?.thumbnailViewModel?.image?.sources || [];
      if (!seen.has(lv.contentId)) {
        seen.add(lv.contentId);
        out.push({ id: lv.contentId, title, artist, thumb: srcs.slice(-1)[0]?.url || `https://img.youtube.com/vi/${lv.contentId}/hqdefault.jpg` });
      }
    }
    Object.values(n).forEach(walk);
  };
  walk(json);
  return out;
}

async function resolveAndPreviewContent(sourceType, value, maxItems, sectionTitle) {
  openModal(
    `<div class="modal-title">👁 Resolving…</div>`,
    `<div style="text-align:center;padding:28px"><div class="spinner"></div><div class="muted small mt8">Fetching live content from YouTube…</div></div>`,
    `<button class="btn" data-close>Cancel</button>`,
  );
  document.querySelector('[data-close]').onclick = closeModal;
  try {
    let items = [];
    let note = '';
    if (sourceType === 'jiosaavn_playlist') {
      const jio = inspectJioSaavnUrl(value);
      const isPl = /\/featured\/|\/s\/playlist\//.test(value);
      note = (jio.ok && isPl)
        ? '✓ Official JioSaavn playlist page — the app opens this exact page in its WebView and the playlist plays there (no API, no scraping, no manual songs).'
        : '⚠ Invalid playlist URL: ' + jio.text;
    } else if (sourceType === 'youtube_playlist') {
      const m = value.match(/(?:list=)([A-Za-z0-9_-]{10,})/) || value.match(/^(PL[A-Za-z0-9_-]{10,}|RDCLAK5uy_[A-Za-z0-9_-]+)$/);
      if (!m) throw new Error('Could not extract a playlist id from: ' + value);
      await ensureInnerTubeBoot();
      const reqId = await rpcCall('inner_tube_request', { p_kind: 'browse', p_value: 'VL' + m[1], p_max_items: maxItems });
      await sleepMs(1500);
      const json = await rpcCall('inner_tube_collect', { p_request_id: reqId });
      items = parseInnerTubeItems(json);
      note = items.length ? `${items.length} videos resolved (live)` : 'Playlist resolved but no playable video entries were found.';
    } else if (sourceType === 'youtube_channel') {
      const m = value.match(/(UC[A-Za-z0-9_-]{22})/) || value.match(/^(@[A-Za-z0-9_.-]{3,64})$/);
      if (!m) throw new Error('Could not extract a channel id/handle from: ' + value);
      const ref = m[1].startsWith('@') ? m[1] : m[1];
      if (ref.startsWith('@')) {
        note = '⚠ @handle resolution happens on the app via the official Data API (channels.list?forHandle) — preview shows a UC-id based channel.';
        throw new Error('Paste the channel UC… id (from the channel URL) for a live preview — @handles are resolved in the app.');
      }
      await ensureInnerTubeBoot();
      const reqId = await rpcCall('inner_tube_request', { p_kind: 'browse', p_value: ref, p_max_items: maxItems });
      await sleepMs(1500);
      const json = await rpcCall('inner_tube_collect', { p_request_id: reqId });
      items = parseInnerTubeItems(json);
      note = items.length ? `${items.length} uploads resolved (live)` : 'Channel resolved but no videos were returned.';
    } else if (sourceType === 'youtube_trending') {
      await ensureInnerTubeBoot();
      try {
        const reqId = await rpcCall('inner_tube_request', { p_kind: 'browse', p_value: 'FEtrending', p_max_items: maxItems });
        await sleepMs(1500);
        const json = await rpcCall('inner_tube_collect', { p_request_id: reqId });
        items = parseInnerTubeItems(json);
        note = items.length ? `${items.length} trending videos (live, IN region)` : 'Trending tab returned no videos — the app falls back to the official Data API mostPopular.';
      } catch (e) {
        note = 'YouTube rejects the trending tab for this context — the APP uses the official Data API videos.list?chart=mostPopular (region-honored) instead. ' + e.message;
      }
    } else if (sourceType === 'youtube_search') {
      await ensureInnerTubeBoot();
      const reqId = await rpcCall('inner_tube_request', { p_kind: 'search', p_value: value, p_max_items: maxItems });
      await sleepMs(1500);
      const json = await rpcCall('inner_tube_collect', { p_request_id: reqId });
      items = parseInnerTubeItems(json);
      note = items.length ? `${items.length} results (live search)` : 'Search returned no results.';
    } else {
      note = 'Preview is not applicable for this source type.';
    }

    openModal(
      `<div class="modal-title">👁 ${esc(sectionTitle || 'Section')} — live preview</div>`,
      `<div class="muted small" style="margin-bottom:10px">${esc(note)}</div>
       ${items.length ? `<div class="items-list" style="max-height:52vh;overflow-y:auto">${items.map((it, i) => `
         <div class="item-card" style="display:flex;gap:10px;align-items:center">
           <img src="${esc(it.thumb)}" alt="" style="width:48px;height:48px;border-radius:8px;object-fit:cover;flex:none" loading="lazy">
           <div style="min-width:0">
             <div style="font-weight:600;font-size:13px">${i + 1}. ${esc(it.title || 'Untitled')}</div>
             <div class="muted small" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${esc(it.artist || '')}</div>
           </div>
         </div>`).join('')}</div>`
       : `<div class="empty-state"><div class="icon">🔎</div><div class="title">No items to preview</div><div class="desc">${esc(note)}</div></div>`}`,
      `<button class="btn btn-primary" data-close>Done</button>`,
    );
    document.querySelector('[data-close]').onclick = closeModal;
  } catch (e) {
    openModal(
      `<div class="modal-title">⚠ Preview failed</div>`,
      `<div class="card"><p class="login-error">${esc(e.message || String(e))}</p></div>`,
      `<button class="btn btn-primary" data-close>OK</button>`,
    );
    document.querySelector('[data-close]').onclick = closeModal;
  }
}

/* ── Modal helpers ────────────────────────────────────────────────────────── */
function openModal(titleHtml, bodyHtml, footHtml) {
  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay';
  overlay.innerHTML = `
    <div class="modal" role="dialog" aria-modal="true">
      <div class="modal-head">
        <div>${titleHtml}</div>
        <button class="btn btn-icon" data-x aria-label="Close">✕</button>
      </div>
      <div class="modal-body">${bodyHtml}</div>
      <div class="modal-foot">${footHtml}</div>
    </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener('click', (e) => { if (e.target === overlay) closeModal(); });
  overlay.querySelector('[data-x]').onclick = closeModal;
}
function closeModal() {
  const overlay = document.querySelector('.modal-overlay');
  if (overlay) overlay.remove();
}

/* ══ DISCOVER ════════════════════════════════════════════════════════════════ */
async function renderDiscover(el) {
  const { data, error } = await supabase.from('discovery_categories').select('*').order('sort_order');
  if (error) { el.innerHTML = `<div class="card"><div class="card-title">Discover</div><p class="login-error mt8">${esc(error.message)}</p></div>`; return; }
  state.data.categories = data || [];
  el.innerHTML = `
    <div class="card">
      <div class="card-header">
        <div>
          <div class="card-title">Discover categories</div>
          <div class="card-subtitle">Mood list shown in the app's Discover feed (when enable_discovery_remote_categories is ON). Keep a distinct query per row.</div>
        </div>
        <div class="btn-group">
          <button class="btn" id="add-cat">+ Category</button>
          <button class="btn btn-success" id="save-cats">Save categories</button>
        </div>
      </div>
      <div id="cats-list"></div>
    </div>`;
  const list = $('cats-list');
  const renderRows = () => {
    list.innerHTML = state.data.categories.map((c, i) => `
      <div class="row-card" data-i="${i}">
        <div class="row-card-head">
          <span class="badge badge-gray">#${i + 1}</span>
          <span class="grow" style="font-weight:700;font-size:14px">${esc(c.name || 'Untitled')}</span>
          <button class="btn btn-sm" data-move="up" ${i === 0 ? 'disabled' : ''} aria-label="Move up">↑</button>
          <button class="btn btn-sm" data-move="down" ${i === state.data.categories.length - 1 ? 'disabled' : ''} aria-label="Move down">↓</button>
          <button class="btn btn-sm btn-danger" data-del>✕</button>
        </div>
        <div class="row-card-body">
          <div class="form-group"><label class="form-label">Name</label><input class="form-input" data-c="name" value="${esc(c.name)}"></div>
          <div class="form-group"><label class="form-label">Emoji</label><input class="form-input" data-c="emoji" value="${esc(c.emoji || '')}"></div>
          <div class="form-group"><label class="form-label">Kind</label>
            <select class="form-select" data-c="kind">
              <option value="source" ${(c.kind || 'source') === 'source' ? 'selected' : ''}>Source</option>
              <option value="mood" ${c.kind === 'mood' ? 'selected' : ''}>Mood</option>
              <option value="language" ${c.kind === 'language' ? 'selected' : ''}>Language</option>
              <option value="region" ${c.kind === 'region' ? 'selected' : ''}>Region</option>
            </select></div>
          <div class="form-group"><label class="form-label">Query / token</label><input class="form-input" data-c="query" value="${esc(c.query || '')}"></div>
          <div class="form-group" style="display:flex;align-items:center;min-height:44px">
            <label class="form-check"><span class="switch"><input type="checkbox" data-c="active" ${c.active !== false ? 'checked' : ''}><span class="slider"></span></span> Active</label>
          </div>
        </div>
      </div>`).join('') || '<div class="empty-state"><div class="icon">🔍</div><div class="title">No categories</div></div>';
    list.querySelectorAll('.row-card').forEach((card) => {
      const i = Number(card.dataset.i);
      card.querySelectorAll('[data-c]').forEach((input) => {
        input.onchange = () => {
          state.data.categories[i][input.dataset.c] = input.dataset.c === 'active' ? input.checked : input.value;
        };
      });
      card.querySelector('[data-del]').onclick = () => { state.data.categories.splice(i, 1); renderRows(); };
      card.querySelector('[data-move="up"]').onclick = () => {
        if (i > 0) { [state.data.categories[i], state.data.categories[i - 1]] = [state.data.categories[i - 1], state.data.categories[i]]; renderRows(); }
      };
      card.querySelector('[data-move="down"]').onclick = () => {
        if (i < state.data.categories.length - 1) { [state.data.categories[i], state.data.categories[i + 1]] = [state.data.categories[i + 1], state.data.categories[i]]; renderRows(); }
      };
    });
  };
  renderRows();
  $('add-cat').onclick = () => {
    state.data.categories.push({
      id: `cat_${Date.now()}`, name: 'New category', emoji: '🎵', query: 'official audio',
      kind: 'source', fallback_category: 'global', sort_order: state.data.categories.length, active: true,
    });
    renderRows();
  };
  $('save-cats').onclick = async () => {
    const btn = $('save-cats');
    setBusy(btn, true, 'Saving…');
    try {
      const payload = state.data.categories.map((c, i) => ({
        id: c.id || `cat_${i}`, name: (c.name || 'Untitled').trim(), emoji: c.emoji || '🎵',
        query: (c.query || '').trim(), kind: c.kind || 'source', token: c.token || c.query || '',
        ranking_order: c.ranking_order || 'relevance', visible: c.visible !== false,
        fallback_category: c.fallback_category || 'global', sort_order: i, active: c.active !== false,
        updated_at: new Date().toISOString(),
      }));
      const { error: upsertErr } = await supabase.from('discovery_categories').upsert(payload, { onConflict: 'id' });
      if (upsertErr) throw upsertErr;
      toast(`✅ Saved ${payload.length} categories`);
    } catch (e) {
      toast(`Save failed: ${e.message || e}`, 'error');
    } finally {
      setBusy(btn, false);
    }
  };
}

/* ══ PROVIDERS ═══════════════════════════════════════════════════════════════ */
async function renderProviders(el) {
  let jioOn = false;
  try {
    const { data } = await supabase.from('feature_flags').select('key,value');
    jioOn = (data || []).some((f) => f.key === 'enable_jiosaavn_web_playback' && f.value === true);
  } catch (_) {}
  el.innerHTML = `
    <div class="stats-grid">
      <div class="stat-card"><div class="stat-label">YouTube</div><div class="stat-value" style="color:var(--green)">Active</div><div class="stat-change up">Official webpage / watch URLs only</div></div>
      <div class="stat-card"><div class="stat-label">JioSaavn</div><div class="stat-value" style="color:${jioOn ? 'var(--green)' : 'var(--yellow)'}">${jioOn ? 'Active' : 'Disabled'}</div><div class="stat-change ${jioOn ? 'up' : ''}">Webpage playback only · enable_jiosaavn_web_playback</div></div>
    </div>
    <div class="card">
      <div class="card-title">🔌 Playback routing (what the app does)</div>
      <p class="muted mt8" style="font-size:14px;line-height:1.7">
        <b style="color:var(--text)">Auto:</b> exact JioSaavn permalink (if flag ON) → YouTube video → JioSaavn search page (if fallback ON).<br>
        <b style="color:var(--text)">YouTube:</b> official watch URL in the WebView.<br>
        <b style="color:var(--text)">JioSaavn:</b> official jiosaavn.com song page in the WebView (permalink, or search page as fallback).<br>
        No unofficial JioSaavn API, no audio/stream extraction, no media URLs, no ad blocking on JioSaavn.
      </p>
    </div>
    <div class="card">
      <div class="card-title">🔌 How to get a JioSaavn URL</div>
      <div class="muted mt8" style="font-size:14px;line-height:1.9">
        1. Open <a href="https://www.jiosaavn.com" target="_blank" rel="noopener">jiosaavn.com</a> in a browser<br>
        2. Search for the song<br>
        3. Open the exact song page<br>
        4. Copy the URL from the address bar<br>
        5. Paste it into an item's <b>JioSaavn URL</b> field<br><br>
        <strong>Example:</strong> <code>https://www.jiosaavn.com/song/kesariya/BT8sWBlRelQ</code>
      </div>
    </div>`;
}

/* ══ FEATURE FLAGS ═══════════════════════════════════════════════════════════ */
async function renderFlags(el) {
  const { data, error } = await supabase.from('feature_flags').select('*').order('key');
  if (error) { el.innerHTML = `<div class="card"><p class="login-error">${esc(error.message)}</p></div>`; return; }
  // Only flags the app actually reads are displayed — unknown/ops-only rows
  // (e.g. enable_home_cms) stay in the DB but are not toggled here, so no
  // control in this panel is a cosmetic no-op.
  const byKey = {};
  (data || []).forEach((f) => { byKey[f.key] = f; });
  KNOWN_FLAGS.forEach((known) => { if (!byKey[known.key]) byKey[known.key] = { key: known.key, value: false, description: known.description }; });
  state.data.flags = KNOWN_FLAGS.map((known) => byKey[known.key]).sort((a, b) => a.key.localeCompare(b.key));
  el.innerHTML = `
    <div class="card">
      <div class="card-header">
        <div>
          <div class="card-title">Feature flags</div>
          <div class="card-subtitle">Toggles are read by the app from Supabase on launch (1-hour cache). Changes apply app-side within ~1 hour.</div>
        </div>
        <button class="btn btn-success" id="save-flags">Save flags</button>
      </div>
      <div id="flags-list">${state.data.flags.map((f, i) => {
        const known = KNOWN_FLAGS.find((k) => k.key === f.key);
        return `
        <div class="row-card" data-i="${i}">
          <div class="row-card-head">
            <code>${esc(f.key)}</code>
            ${known?.appReads ? '<span class="badge badge-green">read by app</span>' : '<span class="badge badge-gray">ops only</span>'}
            <span class="grow"></span>
            <label class="form-check"><span class="switch"><input type="checkbox" data-flag ${f.value ? 'checked' : ''}><span class="slider"></span></span> ${f.value ? 'ON' : 'OFF'}</label>
          </div>
          <p class="muted small mt8">${esc(f.description || known?.description || '')}</p>
        </div>`;
      }).join('')}</div>
    </div>`;
  $('flags-list').querySelectorAll('.row-card').forEach((row) => {
    const i = Number(row.dataset.i);
    const chk = row.querySelector('[data-flag]');
    chk.onchange = () => {
      state.data.flags[i].value = chk.checked;
      row.querySelector('.form-check').innerHTML = chk.checked
        ? `<span class="switch"><input type="checkbox" data-flag checked><span class="slider"></span></span> ON`
        : `<span class="switch"><input type="checkbox" data-flag><span class="slider"></span></span> OFF`;
      const nchk = row.querySelector('[data-flag]');
      nchk.onchange = chk.onchange;
    };
  });
  $('save-flags').onclick = async () => {
    const btn = $('save-flags');
    setBusy(btn, true, 'Saving…');
    try {
      const payload = state.data.flags.map((f) => ({
        key: f.key, value: !!f.value, description: f.description || (KNOWN_FLAGS.find((k) => k.key === f.key) || {}).description,
        updated_at: new Date().toISOString(),
      }));
      const { error: upsertErr } = await supabase.from('feature_flags').upsert(payload, { onConflict: 'key' });
      if (upsertErr) throw upsertErr;
      toast(`✅ Flags saved (${payload.filter((f) => f.value).length} ON / ${payload.filter((f) => !f.value).length} OFF)`);
    } catch (e) {
      toast(`Save failed: ${e.message || e}`, 'error');
    } finally {
      setBusy(btn, false);
    }
  };
}

/* ══ USERS / SETTINGS ════════════════════════════════════════════════════════ */
function renderUsers(el) {
  el.innerHTML = `
    <div class="card">
      <div class="card-title">Access mode</div>
      <p class="muted small mt8" style="line-height:1.6">
        <b style="color:var(--text)">Public mode is ON</b> — the panel does not require login
        (owner decision, 2026-08-21). Anyone with this URL can view and publish Home content.
        Only content tables are writable (Home layout, section items, flags, config version,
        Discover categories) — <b>no user data</b> is exposed. To restore login-only access,
        re-apply the <code>is_home_admin()</code> RLS policies (see migration
        <code>20260821000007_public_admin_mode.sql</code>).
      </p>
    </div>`;
}

function renderSettings(el) {
  el.innerHTML = `
    <div class="card">
      <div class="card-title">Settings</div>
      <div class="form-group mt12"><label class="form-label">App</label><input class="form-input" value="V Shots (com.vshots.live) — 5.8.0+42" disabled></div>
      <div class="form-group"><label class="form-label">Supabase</label><input class="form-input" value="${SUPABASE_URL}" disabled></div>
      <div class="form-group"><label class="form-label">Admin URL</label><input class="form-input" value="${PRODUCTION_REDIRECT_URL}" disabled></div>
    </div>
    <div class="card">
      <div class="card-title">Security & legal boundary</div>
      <p class="muted small mt8" style="line-height:1.6">
        This page uses the publishable anon key only. Database password, service-role key, GitHub tokens and
        BrowserStack keys must never be placed here. <b>Access mode:</b> public (no login) — content-only
        tables are writable; no user data is exposed. JioSaavn integration opens <b>public JioSaavn webpages</b> only
        (permalink or search page) in the app's WebView — no unofficial API, no audio extraction, no media URLs,
        no ad blocking on JioSaavn. YouTube playback uses the official webpage/player — no stream extraction,
        no ad circumvention.
      </p>
    </div>`;
}

/* ══ BOOT ═══════════════════════════════════════════════════════════════════ */
async function init() {
  if (state.demo) {
    state.admin = true;
    state.user = { email: 'demo@vshots.local' };
    state.data = demoData();
    renderAdmin();
    return;
  }
  // ── PUBLIC MODE (owner decision 2026-08-21) ─────────────────────────────
  // No login gate. Anyone with this URL can view, edit and publish CMS
  // content (content-only tables — no user data). Writes go through the
  // anon key; Supabase RLS was relaxed for these tables via migration
  // 20260821000007_public_admin_mode.sql.
  // To restore login: revert to the checkAuth() flow and re-apply the
  // is_home_admin() RLS policies (revert SQL is in that migration).
  state.admin = true;
  state.user = { email: 'public-access', id: 'public' };
  render();
}

function render() {
  if (!state.admin) { renderLogin(); return; }
  renderAdmin();
}

supabase.auth.onAuthStateChange(async (event) => {
  if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') {
    const ok = await checkAuth();
    if (ok) renderAdmin();
  }
  if (event === 'SIGNED_OUT') {
    state.admin = false;
    state.user = null;
    renderLogin();
  }
});

init();
