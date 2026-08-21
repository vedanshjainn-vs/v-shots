import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = 'https://jzxtxqjheggyoqwohqjg.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp6eHR4cWpoZWdneW9xd29ocWpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxODM4OTcsImV4cCI6MjEwMTc1OTg5N30.fD6pKQ4VRG-AoF-nLdpU9iMK1qWz4N-diqMUOJESVw8';
const PRODUCTION_REDIRECT_URL = 'https://vedanshjainn-vs.github.io/v-shots/';
const AUTHORIZED_EMAILS = [
  'lovesongs1106@gmail.com',
  'vedanshjainn@gmail.com',
  'mrvedansh11@gmail.com',
];

const SOURCE_TYPES = [
  { id: 'youtube_search', label: 'YouTube Search' },
  { id: 'youtube_playlist', label: 'YouTube Playlist' },
  { id: 'youtube_channel', label: 'YouTube Channel' },
  { id: 'youtube_trending', label: 'YouTube Trending' },
  { id: 'youtube_manual', label: 'Manual video IDs' },
  { id: 'personalized', label: 'Personalized (app engine)' },
];

const PERSONALIZED_KEYS = [
  { id: 'made_for_you', title: 'Made For You' },
  { id: 'because_listened', title: 'Because You Listened To' },
  { id: 'trending_for_you', title: 'Trending For You' },
  { id: 'discover_something_new', title: 'Discover Something New' },
  { id: 'artists_for_you', title: 'Artists For You' },
  { id: 'official_music', title: 'Official Music' },
  { id: 'continue_listening', title: 'Continue Listening' },
];

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,
  },
});

const state = {
  user: null,
  admin: false,
  page: 'home-cms',
  data: { sections: [], items: {}, categories: [], flags: [] },
};

const $ = (id) => document.getElementById(id);
const esc = (x) => String(x ?? '')
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;');
const uid = () => crypto.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2)}`;

function redirectUrl() {
  if (location.hostname.includes('github.io')) return PRODUCTION_REDIRECT_URL;
  return `${location.origin}${location.pathname}`;
}

function toast(msg, type = 'success') {
  const t = document.createElement('div');
  t.className = `toast ${type}`;
  t.textContent = msg;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 3500);
}

function isAuthorizedEmail(email) {
  return AUTHORIZED_EMAILS.includes((email || '').toLowerCase().trim());
}

async function checkAuth() {
  const { data: { session } } = await supabase.auth.getSession();
  const user = session?.user || null;
  state.user = user;
  if (!user) {
    state.admin = false;
    return false;
  }
  if (!isAuthorizedEmail(user.email)) {
    await supabase.auth.signOut();
    state.user = null;
    state.admin = false;
    return false;
  }
  try {
    await supabase.rpc('claim_home_admin');
  } catch (e) {
    console.warn('[AUTH] claim_home_admin:', e);
  }
  state.admin = true;
  return true;
}

async function signIn() {
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: redirectUrl() },
  });
  if (error) toast(`Sign-in failed: ${error.message}`, 'error');
}

async function signOut() {
  await supabase.auth.signOut();
  state.user = null;
  state.admin = false;
  render();
}

const NAV_ITEMS = [
  { id: 'dashboard', label: 'Dashboard', icon: '📊', section: 'main' },
  { id: 'home-cms', label: 'Home CMS', icon: '🏠', section: 'content' },
  { id: 'discover', label: 'Discover categories', icon: '🔍', section: 'content' },
  { id: 'feature-flags', label: 'Feature flags', icon: '🚩', section: 'system' },
  { id: 'users', label: 'Admins', icon: '👥', section: 'system' },
  { id: 'settings', label: 'Settings', icon: '⚙️', section: 'system' },
];

function renderLogin(errorMsg) {
  $('app').innerHTML = `
    <div class="login-screen">
      <div class="login-card">
        <div class="login-logo">V</div>
        <div class="login-title">V Shots Admin</div>
        <div class="login-subtitle">Sign in with an authorized Google account to publish Home without an app update.</div>
        <button class="login-btn" id="login-btn">
          <svg width="18" height="18" viewBox="0 0 24 24"><path fill="currentColor" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"/><path fill="currentColor" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/><path fill="currentColor" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/><path fill="currentColor" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/></svg>
          Sign in with Google
        </button>
        ${errorMsg ? `<div class="login-error">${esc(errorMsg)}</div>` : ''}
      </div>
    </div>`;
  $('login-btn').onclick = signIn;
}

function renderAdmin() {
  $('app').innerHTML = `
    <div class="admin-layout">
      <aside class="sidebar" id="sidebar">
        <div class="sidebar-header">
          <div class="sidebar-logo">V</div>
          <div>
            <div class="sidebar-title">V Shots Admin</div>
            <div class="sidebar-subtitle">Remote Home CMS</div>
          </div>
        </div>
        <nav class="sidebar-nav" id="sidebar-nav"></nav>
      </aside>
      <div class="main">
        <header class="topbar">
          <div style="display:flex;align-items:center;gap:12px">
            <button class="btn menu-btn" id="menu-btn">☰</button>
            <div class="topbar-title" id="page-title">Home CMS</div>
          </div>
          <div class="topbar-actions">
            <div class="topbar-status"></div>
            <span class="topbar-email">${esc(state.user?.email || '')}</span>
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
  $('logout-btn').onclick = signOut;
  $('menu-btn').onclick = () => $('sidebar').classList.toggle('open');
  nav.querySelectorAll('.nav-item').forEach((el) => {
    el.onclick = () => {
      state.page = el.dataset.page;
      $('sidebar').classList.remove('open');
      renderAdmin();
    };
  });
  loadPage();
}

async function loadPage() {
  const content = $('content');
  const item = NAV_ITEMS.find((n) => n.id === state.page);
  $('page-title').textContent = item?.label || 'Dashboard';
  switch (state.page) {
    case 'dashboard': await renderDashboard(content); break;
    case 'home-cms': await renderHomeCMS(content); break;
    case 'discover': await renderDiscover(content); break;
    case 'feature-flags': await renderFlags(content); break;
    case 'users': renderUsers(content); break;
    default: renderSettings(content); break;
  }
}

async function loadHome() {
  const { data: sections, error } = await supabase
    .from('home_layout_config')
    .select('*')
    .order('sort_order');
  if (error) throw error;
  state.data.sections = sections || [];
  const { data: items } = await supabase
    .from('home_section_items')
    .select('*')
    .order('sort_order');
  const grouped = {};
  (items || []).forEach((row) => {
    (grouped[row.section_id] ||= []).push(row);
  });
  state.data.items = grouped;
}

async function renderDashboard(el) {
  try { await loadHome(); } catch (_) {}
  const live = state.data.sections.filter((s) => s.visible !== false && s.published !== false).length;
  el.innerHTML = `
    <div class="stats-grid">
      <div class="stat-card"><div class="stat-label">Home sections</div><div class="stat-value">${state.data.sections.length}</div></div>
      <div class="stat-card"><div class="stat-label">Published & visible</div><div class="stat-value" style="color:var(--green)">${live}</div></div>
      <div class="stat-card"><div class="stat-label">App reads</div><div class="stat-value" style="font-size:16px">Supabase anon + RLS</div></div>
      <div class="stat-card"><div class="stat-label">Signed in</div><div class="stat-value" style="font-size:16px">${esc(state.user?.email || '')}</div></div>
    </div>
    <div class="card">
      <div class="card-title">How Home CMS works</div>
      <p style="color:var(--text2);margin-top:8px;font-size:14px;line-height:1.5">
        Publish Home shelves here. The V Shots app fetches <code>home_layout_config</code> on launch
        (1 hour cache) and rebuilds Home without a Play Store update. Personalized rows keep using
        the on-device recommendation engine. Catalog rows use YouTube search / playlist / channel /
        trending / pinned video IDs. If Supabase is unreachable, the app falls back to compiled defaults.
      </p>
      <div class="btn-group" style="margin-top:16px">
        <button class="btn btn-primary" id="go-cms">Open Home CMS</button>
      </div>
    </div>`;
  $('go-cms').onclick = () => { state.page = 'home-cms'; renderAdmin(); };
}

function sourceHint(type) {
  switch (type) {
    case 'youtube_search': return 'Search query, e.g. trending punjabi songs official audio';
    case 'youtube_playlist': return 'Playlist URL or PL… id';
    case 'youtube_channel': return 'Channel URL, UC… id, or @handle';
    case 'youtube_trending': return 'Optional region code (IN, US) — leave blank for global';
    case 'youtube_manual': return 'Pin exact YouTube video IDs below';
    case 'jiosaavn_manual': return 'Paste exact https://www.jiosaavn.com/song/... permalinks. Do not invent IDs.';
    case 'personalized': return 'App engine — no YouTube query needed';
    default: return 'Source value';
  }
}

async function renderHomeCMS(el) {
  try {
    await loadHome();
  } catch (e) {
    el.innerHTML = `<div class="card"><div class="card-title">Could not load Home</div><p class="login-error">${esc(e.message)}</p></div>`;
    return;
  }
  const sections = state.data.sections;
  el.innerHTML = `
    <div class="card">
      <div class="card-header">
        <div>
          <div class="card-title">Home page builder</div>
          <div class="card-subtitle">Order is top-to-bottom on the phone. Continue Listening is added automatically if you do not include it.</div>
        </div>
        <div class="btn-group">
          <button class="btn" id="add-personalized">+ Personalized</button>
          <button class="btn" id="add-jiosaavn-test">+ JioSaavn test</button>
          <button class="btn btn-primary" id="add-section">+ Catalog section</button>
          <button class="btn" id="reload-sections">Reload</button>
          <button class="btn btn-success" id="publish-sections">Publish Home</button>
        </div>
      </div>
      <div id="sections-list"></div>
    </div>`;

  const list = $('sections-list');
  if (!sections.length) {
    list.innerHTML = `<div class="empty-state"><div class="icon">🏠</div><div class="title">No sections yet</div><div class="desc">Add a catalog or personalized shelf, then Publish.</div></div>`;
  } else {
    sections.forEach((s, i) => {
      const d = document.createElement('div');
      d.className = 'card';
      d.style.marginBottom = '12px';
      const sourceType = s.source_type || 'youtube_search';
      const options = SOURCE_TYPES.map((t) => `<option value="${t.id}" ${sourceType === t.id ? 'selected' : ''}>${t.label}</option>`).join('');
      const items = state.data.items[s.id] || [];
      const isManual = sourceType === 'youtube_manual' || sourceType === 'jiosaavn_manual';
      const itemRows = items.map((it, idx) => {
        const provider = (it.provider || 'auto').toLowerCase();
        const playback = (it.playback_provider || it.provider || 'auto').toLowerCase();
        const fallback = (it.fallback_provider || 'none').toLowerCase();
        const jio = inspectJioSaavnUrl(it.jiosaavn_url || '');
        return `
        <div class="item-card" data-item="${idx}">
          <div class="form-row" style="grid-template-columns:1fr 1fr 1fr auto;gap:8px;align-items:end">
            <div class="form-group" style="margin:0">
              <label class="form-label">Title</label>
              <input class="form-input" data-ifield="title" value="${esc(it.title || '')}" placeholder="Title">
            </div>
            <div class="form-group" style="margin:0">
              <label class="form-label">Artist</label>
              <input class="form-input" data-ifield="artist" value="${esc(it.artist || '')}" placeholder="Artist">
            </div>
            <div class="form-group" style="margin:0">
              <label class="form-label">Artwork URL</label>
              <input class="form-input" data-ifield="artwork_url" value="${esc(it.artwork_url || '')}" placeholder="https://…">
            </div>
            <button class="btn btn-sm btn-danger" data-idel>✕</button>
          </div>
          <div class="form-row" style="margin-top:8px;grid-template-columns:1fr 1fr 1fr">
            <div class="form-group" style="margin:0">
              <label class="form-label">Provider</label>
              <select class="form-select" data-ifield="provider">
                <option value="auto" ${provider === 'auto' ? 'selected' : ''}>Auto</option>
                <option value="youtube" ${provider.includes('youtube') ? 'selected' : ''}>YouTube</option>
                <option value="jiosaavn" ${provider.includes('jiosaavn') ? 'selected' : ''}>JioSaavn</option>
              </select>
            </div>
            <div class="form-group" style="margin:0">
              <label class="form-label">Playback</label>
              <select class="form-select" data-ifield="playback_provider">
                <option value="youtube" ${playback.includes('jiosaavn') ? '' : 'selected'}>YouTube</option>
                <option value="jiosaavn" ${playback.includes('jiosaavn') ? 'selected' : ''}>JioSaavn</option>
              </select>
            </div>
            <div class="form-group" style="margin:0">
              <label class="form-label">Fallback</label>
              <select class="form-select" data-ifield="fallback_provider">
                <option value="none" ${fallback === 'none' || !fallback ? 'selected' : ''}>None</option>
                <option value="youtube" ${fallback.includes('youtube') ? 'selected' : ''}>YouTube</option>
                <option value="jiosaavn" ${fallback.includes('jiosaavn') ? 'selected' : ''}>JioSaavn</option>
              </select>
            </div>
          </div>
          <div class="form-row" style="margin-top:8px;grid-template-columns:1fr 1fr">
            <div class="form-group" style="margin:0">
              <label class="form-label">YouTube URL / ID</label>
              <input class="form-input" data-ifield="youtube_video_id" value="${esc(it.youtube_video_id || '')}" placeholder="ID or https://www.youtube.com/watch?v=…">
            </div>
            <div class="form-group" style="margin:0">
              <label class="form-label">JioSaavn URL</label>
              <input class="form-input" data-ifield="jiosaavn_url" value="${esc(it.jiosaavn_url || '')}" placeholder="https://www.jiosaavn.com/song/slug/id">
            </div>
          </div>
          <div class="source-hint jio-status">${esc(jio.text)}</div>
        </div>`;
      }).join('');
      d.innerHTML = `
        <div class="form-row" style="grid-template-columns:2fr 2fr 1fr auto;gap:10px;align-items:end">
          <div class="form-group" style="margin:0">
            <label class="form-label">Title</label>
            <input class="form-input" value="${esc(s.title)}" data-field="title">
          </div>
          <div class="form-group" style="margin:0">
            <label class="form-label">Subtitle</label>
            <input class="form-input" value="${esc(s.subtitle || '')}" data-field="subtitle">
          </div>
          <div class="form-group" style="margin:0">
            <label class="form-label">Max items</label>
            <input class="form-input" type="number" min="1" max="100" value="${s.max_items || 15}" data-field="max_items">
          </div>
          <div class="btn-group">
            <button class="btn btn-sm" data-action="up" ${i === 0 ? 'disabled' : ''}>↑</button>
            <button class="btn btn-sm" data-action="down" ${i === sections.length - 1 ? 'disabled' : ''}>↓</button>
            <button class="btn btn-sm btn-danger" data-action="delete">Delete</button>
          </div>
        </div>
        <div class="form-row" style="margin-top:12px;grid-template-columns:220px 1fr 120px 90px">
          <select class="form-select" data-field="source_type">${options}</select>
          <input class="form-input" value="${esc(s.source_value || s.query || '')}" data-field="source_value" placeholder="${esc(sourceHint(sourceType))}">
          <input class="form-input" value="${esc(s.region_code || '')}" data-field="region_code" placeholder="Region">
          <label class="form-check"><input type="checkbox" ${s.visible !== false ? 'checked' : ''} data-field="visible"> Show</label>
        </div>
        <div class="source-hint">${esc(sourceHint(sourceType))}</div>
        <div class="manual-box" style="display:${sourceType === 'youtube_manual' ? 'block' : 'none'}">
          <div class="card-subtitle" style="margin:12px 0 8px">Pinned videos</div>
          <div class="items-list">${itemRows || '<div class="card-subtitle">No pinned videos yet.</div>'}</div>
          <button class="btn btn-sm" data-add-item style="margin-top:8px">+ Video</button>
        </div>`;

      d.querySelectorAll('[data-field]').forEach((input) => {
        const field = input.dataset.field;
        input.onchange = () => {
          if (field === 'visible') s[field] = input.checked;
          else if (field === 'max_items') s[field] = parseInt(input.value, 10) || 15;
          else s[field] = input.value;
          if (field === 'source_type') {
            if (input.value === 'personalized' && !PERSONALIZED_KEYS.some((k) => k.id === s.section_key)) {
              s.section_key = 'made_for_you';
              s.section_type = 'personalized';
            }
            renderHomeCMS(el);
          }
        };
      });
      d.querySelector('[data-action="up"]').onclick = () => {
        if (i > 0) { [sections[i], sections[i - 1]] = [sections[i - 1], sections[i]]; renderHomeCMS(el); }
      };
      d.querySelector('[data-action="down"]').onclick = () => {
        if (i < sections.length - 1) { [sections[i], sections[i + 1]] = [sections[i + 1], sections[i]]; renderHomeCMS(el); }
      };
      d.querySelector('[data-action="delete"]').onclick = () => {
        sections.splice(i, 1);
        delete state.data.items[s.id];
        renderHomeCMS(el);
      };
      const addBtn = d.querySelector('[data-add-item]');
      if (addBtn) {
        addBtn.onclick = () => {
          (state.data.items[s.id] ||= []).push({
            id: uid(),
            section_id: s.id,
            youtube_video_id: '',
            content_id: '',
            title: '',
            artist: '',
            artwork_url: '',
            jiosaavn_url: '',
            provider: sourceType === 'jiosaavn_manual' ? 'jiosaavn' : 'auto',
            playback_provider: sourceType === 'jiosaavn_manual' ? 'jiosaavn' : 'youtube',
            fallback_provider: sourceType === 'jiosaavn_manual' ? 'youtube' : 'none',
            sort_order: 0,
            is_enabled: true,
          });
          renderHomeCMS(el);
        };
      }
      d.querySelectorAll('.item-card').forEach((row) => {
        const idx = Number(row.dataset.item);
        row.querySelectorAll('[data-ifield]').forEach((input) => {
          input.onchange = () => {
            const listItems = state.data.items[s.id] || [];
            if (!listItems[idx]) return;
            listItems[idx][input.dataset.ifield] = input.value;
            if (input.dataset.ifield === 'youtube_video_id') {
              listItems[idx].content_id = extractYoutubeId(input.value) || input.value;
            }
            if (input.dataset.ifield === 'jiosaavn_url') {
              const status = row.querySelector('.jio-status');
              if (status) status.textContent = inspectJioSaavnUrl(input.value).text;
            }
          };
        });
        row.querySelector('[data-idel]').onclick = () => {
          (state.data.items[s.id] || []).splice(idx, 1);
          renderHomeCMS(el);
        };
      });
      list.appendChild(d);
    });
  }

  $('add-section').onclick = () => {
    const id = uid();
    sections.push({
      id,
      section_key: `home_${Date.now()}`,
      title: 'New section',
      subtitle: '',
      section_type: 'home_section',
      source_type: 'youtube_search',
      source_value: '',
      query: '',
      max_items: 15,
      visible: true,
      published: true,
      sort_order: sections.length,
      region_code: '',
    });
    renderHomeCMS(el);
  };
  $('add-personalized').onclick = () => {
    const used = new Set(sections.map((s) => s.section_key));
    const next = PERSONALIZED_KEYS.find((k) => !used.has(k.id)) || PERSONALIZED_KEYS[0];
    sections.push({
      id: next.id,
      section_key: next.id,
      title: next.title,
      subtitle: '',
      section_type: 'personalized',
      source_type: 'personalized',
      source_value: next.id,
      query: '',
      max_items: 12,
      visible: true,
      published: true,
      sort_order: sections.length,
    });
    renderHomeCMS(el);
  };
  $('reload-sections').onclick = () => renderHomeCMS(el);
  $('publish-sections').onclick = () => publishHome(el);
}

async function publishHome(el) {
  const btn = $('publish-sections');
  btn.disabled = true;
  try {
    const sections = state.data.sections;
    const { data: existing, error: existingErr } = await supabase.from('home_layout_config').select('id');
    if (existingErr) throw existingErr;
    const keep = new Set();
    const rows = sections.map((s, i) => {
      const id = s.id || uid();
      keep.add(id);
      const sourceType = s.source_type || 'youtube_search';
      const sourceValue = s.source_value || s.query || '';
      const personalized = sourceType === 'personalized';
      return {
        id,
        section_key: s.section_key || (personalized ? id : `home_${id}`),
        title: s.title || 'New section',
        subtitle: s.subtitle || null,
        section_type: personalized ? 'personalized' : (s.section_type || 'home_section'),
        source_type: sourceType,
        source_value: sourceValue || null,
        query: sourceValue || null,
        sort_order: i,
        visible: s.visible !== false,
        max_items: Math.max(1, Math.min(100, Number(s.max_items) || 15)),
        region_code: s.region_code || null,
        category_id: s.category_id || null,
        refresh_minutes: Math.max(1, Number(s.refresh_minutes) || 60),
        published: true,
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

    await supabase.from('home_section_items').delete().neq('id', '__none__');
    const itemRows = [];
    for (const row of rows) {
      const listItems = state.data.items[row.id] || [];
      for (let idx = 0; idx < listItems.length; idx += 1) {
        const it = listItems[idx];
        const videoId = extractYoutubeId(it.youtube_video_id || it.content_id || '');
        const jioUrl = String(it.jiosaavn_url || '').trim();
        const jio = inspectJioSaavnUrl(jioUrl);
        if (jioUrl && !jio.ok) {
          throw new Error(`Invalid JioSaavn URL on "${it.title || 'untitled'}": ${jio.text}`);
        }
        const provider = (it.provider || 'auto').toLowerCase();
        const playback = (it.playback_provider || provider || 'youtube').toLowerCase();
        const fallback = (it.fallback_provider || 'none').toLowerCase();
        const wantsJio = provider.includes('jiosaavn') || playback.includes('jiosaavn');
        if (!videoId && !jioUrl && !wantsJio) continue;
        const contentId = videoId || it.content_id || it.id || uid();
        itemRows.push({
          id: it.id || uid(),
          section_id: row.id,
          content_id: contentId,
          title: it.title || contentId,
          artist: it.artist || null,
          artwork_url: it.artwork_url || (videoId ? `https://img.youtube.com/vi/${videoId}/hqdefault.jpg` : null),
          youtube_video_id: videoId || null,
          jiosaavn_url: jioUrl || null,
          sort_order: idx,
          is_enabled: it.is_enabled !== false,
          provider: provider.includes('jiosaavn') ? 'jiosaavn' : (provider.includes('youtube') ? 'youtube' : 'auto'),
          playback_provider: playback.includes('jiosaavn') ? 'jiosaavn' : 'youtube',
          fallback_provider: fallback.includes('jiosaavn') ? 'jiosaavn' : (fallback.includes('youtube') ? 'youtube' : 'none'),
        });
      }
    }
    if (itemRows.length) {
      const { error } = await supabase.from('home_section_items').insert(itemRows);
      if (error) throw error;
    }
    await supabase.from('home_config').upsert({
      id: 'current',
      version: Date.now(),
      status: 'published',
      published_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
    state.data.sections = rows;
    toast(`Published ${rows.length} Home section(s). App picks this up within ~1 hour, or on pull-to-refresh.`);
  } catch (e) {
    toast(`Publish failed: ${e.message || e}`, 'error');
  } finally {
    btn.disabled = false;
  }
}

async function renderDiscover(el) {
  const { data, error } = await supabase.from('discovery_categories').select('*').order('sort_order');
  if (error) {
    el.innerHTML = `<div class="card"><div class="card-title">Discover</div><p class="login-error">${esc(error.message)}</p></div>`;
    return;
  }
  state.data.categories = data || [];
  const rows = state.data.categories.map((c, i) => `
    <tr data-i="${i}">
      <td><input class="form-input" data-c="name" value="${esc(c.name)}"></td>
      <td><input class="form-input" data-c="emoji" value="${esc(c.emoji || '')}"></td>
      <td>
        <select class="form-select" data-c="kind">
          <option value="source" ${(c.kind || 'source') === 'source' ? 'selected' : ''}>Source</option>
          <option value="mood" ${c.kind === 'mood' ? 'selected' : ''}>Mood</option>
          <option value="language" ${c.kind === 'language' ? 'selected' : ''}>Language</option>
          <option value="region" ${c.kind === 'region' ? 'selected' : ''}>Region</option>
        </select>
      </td>
      <td><input class="form-input" data-c="query" value="${esc(c.query || '')}"></td>
      <td><label class="form-check"><input type="checkbox" data-c="active" ${c.active !== false ? 'checked' : ''}> On</label></td>
    </tr>`).join('');
  el.innerHTML = `
    <div class="card">
      <div class="card-header">
        <div>
          <div class="card-title">Discover categories</div>
          <div class="card-subtitle">These override the in-app mood list when remote config loads. Keep a distinct query per row.</div>
        </div>
        <div class="btn-group">
          <button class="btn" id="add-cat">+ Category</button>
          <button class="btn btn-success" id="save-cats">Save categories</button>
        </div>
      </div>
      <div class="table-container">
        <table>
          <thead><tr><th>Name</th><th>Emoji</th><th>Kind</th><th>Query / token</th><th>Active</th></tr></thead>
          <tbody>${rows}</tbody>
        </table>
      </div>
    </div>`;
  el.querySelectorAll('tbody tr').forEach((tr) => {
    const i = Number(tr.dataset.i);
    tr.querySelectorAll('[data-c]').forEach((input) => {
      input.onchange = () => {
        const field = input.dataset.c;
        state.data.categories[i][field] = field === 'active' ? input.checked : input.value;
      };
    });
  });
  $('add-cat').onclick = () => {
    const id = `cat_${Date.now()}`;
    state.data.categories.push({
      id, name: 'New category', emoji: '🎵', query: 'official audio', kind: 'source', fallback_category: 'global', sort_order: state.data.categories.length, active: true,
    });
    renderDiscover(el);
  };
  $('save-cats').onclick = async () => {
    try {
      const payload = state.data.categories.map((c, i) => ({
        id: c.id || `cat_${i}`,
        name: c.name || 'Untitled',
        emoji: c.emoji || '🎵',
        query: c.query || '',
        kind: c.kind || 'source',
        token: c.token || c.query || '',
        ranking_order: c.ranking_order || 'relevance',
        visible: c.visible !== false,
        fallback_category: c.fallback_category || 'global',
        sort_order: i,
        active: c.active !== false,
        updated_at: new Date().toISOString(),
      }));
      const { error: upsertErr } = await supabase.from('discovery_categories').upsert(payload, { onConflict: 'id' });
      if (upsertErr) throw upsertErr;
      toast(`Saved ${payload.length} categories`);
    } catch (e) {
      toast(`Save failed: ${e.message}`, 'error');
    }
  };
}

async function renderFlags(el) {
  const { data, error } = await supabase.from('feature_flags').select('*').order('key');
  if (error) {
    el.innerHTML = `<div class="card"><p class="login-error">${esc(error.message)}</p></div>`;
    return;
  }
  const byKey = {};
  (data || []).forEach((f) => { byKey[f.key] = f; });
  KNOWN_FLAGS.forEach((known) => {
    if (!byKey[known.key]) byKey[known.key] = { ...known };
  });
  state.data.flags = Object.values(byKey).sort((a, b) => a.key.localeCompare(b.key));
  el.innerHTML = `<div class="card"><div class="card-header"><div class="card-title">Feature flags</div><button class="btn btn-success" id="save-flags">Save flags</button></div>
    <div class="table-container"><table><thead><tr><th>Flag</th><th>Description</th><th>Enabled</th></tr></thead>
    <tbody>${state.data.flags.map((f, i) => `<tr data-i="${i}"><td><code>${esc(f.key)}</code></td><td>${esc(f.description || '')}</td>
      <td><label class="form-check"><input type="checkbox" data-flag ${f.value ? 'checked' : ''}></label></td></tr>`).join('')}</tbody></table></div></div>`;
  el.querySelectorAll('tbody tr').forEach((tr) => {
    const i = Number(tr.dataset.i);
    tr.querySelector('[data-flag]').onchange = (ev) => { state.data.flags[i].value = ev.target.checked; };
  });
  $('save-flags').onclick = async () => {
    try {
      const payload = state.data.flags.map((f) => ({
        key: f.key, value: !!f.value, description: f.description, updated_at: new Date().toISOString(),
      }));
      const { error: upsertErr } = await supabase.from('feature_flags').upsert(payload, { onConflict: 'key' });
      if (upsertErr) throw upsertErr;
      toast('Flags saved');
    } catch (e) {
      toast(`Save failed: ${e.message}`, 'error');
    }
  };
}

function renderUsers(el) {
  el.innerHTML = `<div class="card"><div class="card-title">Authorized admins</div>
    <div class="table-container" style="margin-top:12px"><table><thead><tr><th>Email</th><th>Status</th></tr></thead>
    <tbody>${AUTHORIZED_EMAILS.map((e) => `<tr><td>${esc(e)}</td><td><span class="badge badge-green">Allowlisted</span></td></tr>`).join('')}</tbody></table></div>
    <p style="color:var(--text2);margin-top:12px;font-size:13px">Writes are restricted by Supabase RLS to these Google accounts after <code>claim_home_admin()</code>.</p></div>`;
}

function renderSettings(el) {
  el.innerHTML = `
    <div class="card">
      <div class="card-title">Settings</div>
      <div class="form-group" style="margin-top:16px"><label class="form-label">App</label><input class="form-input" value="V Shots (com.vshots.live)" disabled></div>
      <div class="form-group"><label class="form-label">Supabase</label><input class="form-input" value="${SUPABASE_URL}" disabled></div>
      <div class="form-group"><label class="form-label">Admin URL</label><input class="form-input" value="${PRODUCTION_REDIRECT_URL}" disabled></div>
    </div>
    <div class="card">
      <div class="card-title">Security</div>
      <p style="color:var(--text2);margin-top:8px;font-size:14px">This page uses the publishable anon key only. Database password, service-role key, GitHub tokens, and BrowserStack keys must never be placed here.</p>
    </div>`;
}

function render() {
  if (!state.admin) {
    renderLogin();
    return;
  }
  renderAdmin();
}

async function init() {
  const ok = await checkAuth();
  if (!ok && new URLSearchParams(location.search).has('error')) {
    renderLogin('Google sign-in was cancelled or failed.');
    return;
  }
  render();
}

supabase.auth.onAuthStateChange(async (event) => {
  if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') {
    const ok = await checkAuth();
    if (ok) renderAdmin();
  }
  if (event === 'SIGNED_OUT') {
    state.admin = false;
    renderLogin();
  }
});

init();
kbox" data-flag ${f.value ? 'checked' : ''}></label></td></tr>`).join('')}</tbody></table></div></div>`;
  el.querySelectorAll('tbody tr').forEach((tr) => {
    const i = Number(tr.dataset.i);
    tr.querySelector('[data-flag]').onchange = (ev) => { state.data.flags[i].value = ev.target.checked; };
  });
  $('save-flags').onclick = async () => {
    try {
      const payload = state.data.flags.map((f) => ({
        key: f.key, value: !!f.value, description: f.description, updated_at: new Date().toISOString(),
      }));
      const { error: upsertErr } = await supabase.from('feature_flags').upsert(payload, { onConflict: 'key' });
      if (upsertErr) throw upsertErr;
      toast('Flags saved');
    } catch (e) {
      toast(`Save failed: ${e.message}`, 'error');
    }
  };
}

function renderUsers(el) {
  el.innerHTML = `<div class="card"><div class="card-title">Authorized admins</div>
    <div class="table-container" style="margin-top:12px"><table><thead><tr><th>Email</th><th>Status</th></tr></thead>
    <tbody>${AUTHORIZED_EMAILS.map((e) => `<tr><td>${esc(e)}</td><td><span class="badge badge-green">Allowlisted</span></td></tr>`).join('')}</tbody></table></div>
    <p style="color:var(--text2);margin-top:12px;font-size:13px">Writes are restricted by Supabase RLS to these Google accounts after <code>claim_home_admin()</code>.</p></div>`;
}

function renderSettings(el) {
  el.innerHTML = `
    <div class="card">
      <div class="card-title">Settings</div>
      <div class="form-group" style="margin-top:16px"><label class="form-label">App</label><input class="form-input" value="V Shots (com.vshots.live)" disabled></div>
      <div class="form-group"><label class="form-label">Supabase</label><input class="form-input" value="${SUPABASE_URL}" disabled></div>
      <div class="form-group"><label class="form-label">Admin URL</label><input class="form-input" value="${PRODUCTION_REDIRECT_URL}" disabled></div>
    </div>
    <div class="card">
      <div class="card-title">Security</div>
      <p style="color:var(--text2);margin-top:8px;font-size:14px">This page uses the publishable anon key only. Database password, service-role key, GitHub tokens, and BrowserStack keys must never be placed here.</p>
    </div>`;
}

function render() {
  if (!state.admin) {
    renderLogin();
    return;
  }
  renderAdmin();
}

async function init() {
  const ok = await checkAuth();
  if (!ok && new URLSearchParams(location.search).has('error')) {
    renderLogin('Google sign-in was cancelled or failed.');
    return;
  }
  render();
}

supabase.auth.onAuthStateChange(async (event) => {
  if (event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') {
    const ok = await checkAuth();
    if (ok) renderAdmin();
  }
  if (event === 'SIGNED_OUT') {
    state.admin = false;
    renderLogin();
  }
});

init();
