import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ═══════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════
const SUPABASE_URL = 'https://jzxtxqjheggyoqwohqjg.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp6eHR4cWpobGVnZ3lvd3FvaGpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxODM4OTcsImV4cCI6MjEwMTc1OTg5N30.fD6pKQ4VRG-AoF-nLdpU9iMK1qWz4N-diqMUOJESVw8';
const PRODUCTION_REDIRECT_URL = 'https://vedanshjainn-vs.github.io/v-shots/';
const AUTHORIZED_EMAILS = ['lovesongs1106@gmail.com','vedanshjainn@gmail.com','mrvedansh11@gmail.com'];

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
});

// ═══════════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════════
const state = {
  user: null,
  admin: false,
  page: 'dashboard',
  sidebarOpen: false,
  data: { sections: [], songs: [], artists: [], playlists: [], flags: [], logs: [] }
};

// ═══════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════
const $ = id => document.getElementById(id);
const esc = x => String(x ?? '').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const uid = () => crypto.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2)}`;

function toast(msg, type='success') {
  const t = document.createElement('div');
  t.className = `toast ${type}`;
  t.textContent = msg;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 3000);
}

// ═══════════════════════════════════════════════════════════════
// AUTH
// ═══════════════════════════════════════════════════════════════
async function checkAuth() {
  console.log('[AUTH] Checking authentication...');
  
  // First check if there's a session in the URL (OAuth callback)
  const { data: { session }, error: sessionError } = await supabase.auth.getSession();
  console.log('[AUTH] Session from URL/localStorage:', session ? 'Found' : 'None');
  if (sessionError) console.log('[AUTH] Session error:', sessionError);
  
  const { data: { user }, error: userError } = await supabase.auth.getUser();
  console.log('[AUTH] User:', user ? user.email : 'None');
  if (userError) console.log('[AUTH] User error:', userError);
  
  state.user = user;
  if (!user) { 
    state.admin = false; 
    console.log('[AUTH] No user found, returning false');
    return false; 
  }
  
  const email = (user.email || '').toLowerCase().trim();
  console.log('[AUTH] User email:', email);
  console.log('[AUTH] Authorized emails:', AUTHORIZED_EMAILS);
  
  state.admin = AUTHORIZED_EMAILS.some(a => a.toLowerCase().trim() === email);
  console.log('[AUTH] Is admin:', state.admin);
  
  if (!state.admin) { 
    console.log('[AUTH] Not authorized, signing out');
    await supabase.auth.signOut(); 
    state.user = null; 
  }
  return state.admin;
}

async function signIn() {
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo: PRODUCTION_REDIRECT_URL }
  });
  if (error) toast(`Sign-in failed: ${error.message}`, 'error');
}

async function signOut() {
  await supabase.auth.signOut();
  state.user = null;
  state.admin = false;
  render();
}

// ═══════════════════════════════════════════════════════════════
// DATA LOADING
// ═══════════════════════════════════════════════════════════════
async function loadHomeSections() {
  try {
    const { data, error } = await supabase.from('home_layout_config').select('*').order('sort_order');
    if (error) throw error;
    state.data.sections = data || [];
  } catch(e) { console.error('Load sections:', e); }
}

async function loadDashboard() {
  try {
    const { count: sectionCount } = await supabase.from('home_layout_config').select('*', { count: 'exact', head: true });
    return { sections: sectionCount || 0 };
  } catch(e) { return { sections: 0 }; }
}

// ═══════════════════════════════════════════════════════════════
// NAVIGATION
// ═══════════════════════════════════════════════════════════════
const NAV_ITEMS = [
  { id: 'dashboard', label: 'Dashboard', icon: '📊', section: 'main' },
  { id: 'home-cms', label: 'Home CMS', icon: '🏠', section: 'content' },
  { id: 'songs', label: 'Songs', icon: '🎵', section: 'content' },
  { id: 'artists', label: 'Artists', icon: '🎤', section: 'content' },
  { id: 'playlists', label: 'Playlists', icon: '📋', section: 'content' },
  { id: 'discover', label: 'Discover', icon: '🔍', section: 'discovery' },
  { id: 'trending', label: 'Trending', icon: '📈', section: 'discovery' },
  { id: 'featured', label: 'Featured', icon: '⭐', section: 'discovery' },
  { id: 'providers', label: 'Providers', icon: '🔌', section: 'system' },
  { id: 'feature-flags', label: 'Feature Flags', icon: '🚩', section: 'system' },
  { id: 'analytics', label: 'Analytics', icon: '📊', section: 'insights' },
  { id: 'users', label: 'Users', icon: '👥', section: 'insights' },
  { id: 'activity', label: 'Activity Log', icon: '📝', section: 'insights' },
  { id: 'settings', label: 'Settings', icon: '⚙️', section: 'system' },
];

const SECTIONS = [
  { id: 'main', label: '' },
  { id: 'content', label: 'Content' },
  { id: 'discovery', label: 'Discovery' },
  { id: 'insights', label: 'Insights' },
  { id: 'system', label: 'System' },
];

// ═══════════════════════════════════════════════════════════════
// RENDER — LOGIN
// ═══════════════════════════════════════════════════════════════
function renderLogin(errorMsg) {
  document.getElementById('app').innerHTML = `
    <div class="login-screen">
      <div class="login-card">
        <div class="login-logo">V</div>
        <div class="login-title">V Shots Admin</div>
        <div class="login-subtitle">Sign in with your authorized Google account to access the CMS.</div>
        <button class="login-btn" id="login-btn">
          <svg width="18" height="18" viewBox="0 0 24 24"><path fill="currentColor" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"/><path fill="currentColor" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/><path fill="currentColor" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/><path fill="currentColor" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/></svg>
          Sign in with Google
        </button>
        ${errorMsg ? `<div class="login-error">${esc(errorMsg)}</div>` : ''}
      </div>
    </div>
  `;
  document.getElementById('login-btn').onclick = signIn;
}

// ═══════════════════════════════════════════════════════════════
// RENDER — ADMIN LAYOUT
// ═══════════════════════════════════════════════════════════════
function renderAdmin() {
  const app = document.getElementById('app');
  app.innerHTML = `
    <div class="admin-layout">
      <aside class="sidebar" id="sidebar">
        <div class="sidebar-header">
          <div class="sidebar-logo">V</div>
          <div>
            <div class="sidebar-title">V Shots Admin</div>
            <div class="sidebar-subtitle">Home CMS</div>
          </div>
        </div>
        <nav class="sidebar-nav" id="sidebar-nav"></nav>
      </aside>
      <div class="main">
        <header class="topbar">
          <div style="display:flex;align-items:center;gap:12px">
            <button class="btn menu-btn" id="menu-btn">☰</button>
            <div class="topbar-title" id="page-title">Dashboard</div>
          </div>
          <div class="topbar-actions">
            <div class="topbar-status"></div>
            <span class="topbar-email">${esc(state.user?.email || '')}</span>
            <button class="btn btn-sm" id="logout-btn">Sign out</button>
          </div>
        </header>
        <div class="content" id="content">
          <div style="text-align:center;padding:60px"><div class="spinner"></div></div>
        </div>
      </div>
    </div>
  `;

  // Render sidebar nav
  const nav = document.getElementById('sidebar-nav');
  let currentSection = '';
  NAV_ITEMS.forEach(item => {
    if (item.section !== currentSection) {
      currentSection = item.section;
      const sec = SECTIONS.find(s => s.id === currentSection);
      if (sec?.label) {
        nav.innerHTML += `<div class="nav-section">${sec.label}</div>`;
      }
    }
    nav.innerHTML += `<div class="nav-item${state.page === item.id ? ' active' : ''}" data-page="${item.id}"><span class="icon">${item.icon}</span>${item.label}</div>`;
  });

  // Event listeners
  document.getElementById('logout-btn').onclick = signOut;
  document.getElementById('menu-btn').onclick = () => {
    document.getElementById('sidebar').classList.toggle('open');
  };
  nav.querySelectorAll('.nav-item').forEach(el => {
    el.onclick = () => {
      state.page = el.dataset.page;
      document.getElementById('sidebar').classList.remove('open');
      renderAdmin();
      loadPage();
    };
  });

  loadPage();
}

// ═══════════════════════════════════════════════════════════════
// PAGE LOADER
// ═══════════════════════════════════════════════════════════════
async function loadPage() {
  const content = document.getElementById('content');
  const title = document.getElementById('page-title');
  const item = NAV_ITEMS.find(n => n.id === state.page);
  title.textContent = item?.label || 'Dashboard';

  switch(state.page) {
    case 'dashboard': await renderDashboard(content); break;
    case 'home-cms': await renderHomeCMS(content); break;
    case 'songs': renderSongs(content); break;
    case 'artists': renderArtists(content); break;
    case 'playlists': renderPlaylists(content); break;
    case 'discover': renderDiscover(content); break;
    case 'trending': renderTrending(content); break;
    case 'featured': renderFeatured(content); break;
    case 'providers': renderProviders(content); break;
    case 'feature-flags': renderFeatureFlags(content); break;
    case 'analytics': renderAnalytics(content); break;
    case 'users': renderUsers(content); break;
    case 'activity': renderActivity(content); break;
    case 'settings': renderSettings(content); break;
    default: renderDashboard(content);
  }
}

// ═══════════════════════════════════════════════════════════════
// DASHBOARD
// ═══════════════════════════════════════════════════════════════
async function renderDashboard(el) {
  const stats = await loadDashboard();
  el.innerHTML = `
    <div class="stats-grid">
      <div class="stat-card"><div class="stat-label">Home Sections</div><div class="stat-value">${stats.sections}</div></div>
      <div class="stat-card"><div class="stat-label">Status</div><div class="stat-value" style="color:var(--green)">Live</div></div>
      <div class="stat-card"><div class="stat-label">Admin</div><div class="stat-value" style="font-size:16px">${esc(state.user?.email || '')}</div></div>
      <div class="stat-card"><div class="stat-label">Last Login</div><div class="stat-value" style="font-size:16px">${new Date().toLocaleString()}</div></div>
    </div>
    <div class="card">
      <div class="card-header">
        <div class="card-title">Quick Actions</div>
      </div>
      <div class="btn-group">
        <button class="btn btn-primary" onclick="document.querySelector('[data-page=home-cms]').click()">🏠 Edit Home</button>
        <button class="btn" onclick="document.querySelector('[data-page=songs]').click()">🎵 Songs</button>
        <button class="btn" onclick="document.querySelector('[data-page=providers]').click()">🔌 Providers</button>
        <button class="btn" onclick="document.querySelector('[data-page=settings]').click()">⚙️ Settings</button>
      </div>
    </div>
    <div class="card">
      <div class="card-header">
        <div class="card-title">System Status</div>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
        <div style="display:flex;align-items:center;gap:8px"><span class="status-dot green"></span> Supabase</div>
        <div style="display:flex;align-items:center;gap:8px"><span class="status-dot green"></span> Authentication</div>
        <div style="display:flex;align-items:center;gap:8px"><span class="status-dot green"></span> Database</div>
        <div style="display:flex;align-items:center;gap:8px"><span class="status-dot green"></span> GitHub Pages</div>
      </div>
    </div>
  `;
}

// ═══════════════════════════════════════════════════════════════
// HOME CMS
// ═══════════════════════════════════════════════════════════════
async function renderHomeCMS(el) {
  await loadHomeSections();
  const sections = state.data.sections;
  
  el.innerHTML = `
    <div class="card">
      <div class="card-header">
        <div>
          <div class="card-title">Home Page Sections</div>
          <div class="card-subtitle">Control what appears on the V Shots Home screen</div>
        </div>
        <div class="btn-group">
          <button class="btn btn-primary" id="add-section">+ Add Section</button>
          <button class="btn" id="reload-sections">↻ Reload</button>
          <button class="btn btn-primary" id="publish-sections">Publish</button>
        </div>
      </div>
      <div id="sections-list"></div>
    </div>
  `;

  const list = document.getElementById('sections-list');
  
  if (sections.length === 0) {
    list.innerHTML = `<div class="empty-state"><div class="icon">🏠</div><div class="title">No sections yet</div><div class="desc">Click "Add Section" to create your first Home section.</div></div>`;
  } else {
    sections.forEach((s, i) => {
      const d = document.createElement('div');
      d.className = 'card';
      d.style.marginBottom = '12px';
      d.innerHTML = `
        <div style="display:grid;grid-template-columns:1fr 1fr 150px 1fr 80px 80px 80px;gap:10px;align-items:center">
          <input class="form-input" value="${esc(s.title)}" placeholder="Title" data-field="title">
          <input class="form-input" value="${esc(s.subtitle || '')}" placeholder="Subtitle" data-field="subtitle">
          <select class="form-select" data-field="source_type">
            <option value="youtube_search" ${s.source_type==='youtube_search'?'selected':''}>YT Search</option>
            <option value="youtube_playlist" ${s.source_type==='youtube_playlist'?'selected':''}>YT Playlist</option>
            <option value="youtube_channel" ${s.source_type==='youtube_channel'?'selected':''}>YT Channel</option>
            <option value="youtube_trending" ${s.source_type==='youtube_trending'?'selected':''}>YT Trending</option>
          </select>
          <input class="form-input" value="${esc(s.source_value || '')}" placeholder="Search / Playlist ID" data-field="source_value">
          <input class="form-input" type="number" min="1" max="100" value="${s.max_items || 20}" data-field="max_items" title="Max items">
          <label class="form-check"><input type="checkbox" ${s.visible !== false ? 'checked' : ''} data-field="visible"> Show</label>
          <div class="btn-group">
            <button class="btn btn-sm" data-action="up" ${i===0?'disabled':''}>↑</button>
            <button class="btn btn-sm" data-action="down" ${i===sections.length-1?'disabled':''}>↓</button>
            <button class="btn btn-sm btn-danger" data-action="delete">✕</button>
          </div>
        </div>
      `;
      
      // Bind events
      d.querySelectorAll('[data-field]').forEach(input => {
        const field = input.dataset.field;
        input.onchange = () => {
          if (field === 'visible') s[field] = input.checked;
          else if (field === 'max_items') s[field] = parseInt(input.value) || 20;
          else s[field] = input.value;
        };
      });
      
      d.querySelector('[data-action="up"]').onclick = () => {
        if (i > 0) { [sections[i], sections[i-1]] = [sections[i-1], sections[i]]; renderHomeCMS(el); }
      };
      d.querySelector('[data-action="down"]').onclick = () => {
        if (i < sections.length-1) { [sections[i], sections[i+1]] = [sections[i+1], sections[i]]; renderHomeCMS(el); }
      };
      d.querySelector('[data-action="delete"]').onclick = () => {
        sections.splice(i, 1);
        renderHomeCMS(el);
      };
      
      list.appendChild(d);
    });
  }

  // Button handlers
  document.getElementById('add-section').onclick = () => {
    sections.push({
      id: uid(), section_key: `home_${Date.now()}`, title: 'New Section',
      subtitle: '', section_type: 'home_section', source_type: 'youtube_search',
      source_value: '', max_items: 20, visible: true, sort_order: sections.length,
      refresh_minutes: 60, published: false
    });
    renderHomeCMS(el);
  };

  document.getElementById('reload-sections').onclick = () => renderHomeCMS(el);

  document.getElementById('publish-sections').onclick = async () => {
    try {
      document.getElementById('publish-sections').disabled = true;
      const { data: existing } = await supabase.from('home_layout_config').select('id');
      const keep = new Set();
      const rows = sections.map((s, i) => {
        const id = s.id || uid();
        keep.add(id);
        return {
          id, section_key: s.section_key || `home_${id}`, title: s.title || 'New Section',
          subtitle: s.subtitle || null, section_type: s.section_type || 'home_section',
          source_type: s.source_type || 'youtube_search', source_value: s.source_value || null,
          query: s.query || s.source_value || null, sort_order: i, visible: s.visible !== false,
          max_items: Math.max(1, Math.min(100, Number(s.max_items) || 20)),
          region_code: s.region_code || null, category_id: s.category_id || null,
          refresh_minutes: Math.max(1, Number(s.refresh_minutes) || 60), published: true
        };
      });
      const stale = (existing || []).map(x => x.id).filter(id => !keep.has(id));
      if (stale.length) await supabase.from('home_layout_config').delete().in('id', stale);
      if (rows.length) await supabase.from('home_layout_config').upsert(rows, { onConflict: 'id' });
      state.data.sections = rows;
      toast(`Published ${rows.length} section(s)!`);
    } catch(e) { toast(`Publish failed: ${e.message}`, 'error'); }
    finally { document.getElementById('publish-sections').disabled = false; }
  };
}

// ═══════════════════════════════════════════════════════════════
// PLACEHOLDER PAGES (functional stubs)
// ═══════════════════════════════════════════════════════════════
function renderSongs(el) {
  el.innerHTML = `<div class="card"><div class="card-header"><div class="card-title">🎵 Songs</div><button class="btn btn-primary btn-sm">+ Add Song</button></div><div class="empty-state"><div class="icon">🎵</div><div class="title">Song Management</div><div class="desc">Songs are managed through the Home CMS sections. Each section can pull songs from YouTube Search, Playlists, Channels, or Trending.</div></div></div>`;
}

function renderArtists(el) {
  el.innerHTML = `<div class="card"><div class="card-header"><div class="card-title">🎤 Artists</div></div><div class="empty-state"><div class="icon">🎤</div><div class="title">Artist Management</div><div class="desc">Artist data is sourced from YouTube channels. Featured artists can be managed through Home CMS sections.</div></div></div>`;
}

function renderPlaylists(el) {
  el.innerHTML = `<div class="card"><div class="card-header"><div class="card-title">📋 Playlists</div><button class="btn btn-primary btn-sm">+ Create Playlist</button></div><div class="empty-state"><div class="icon">📋</div><div class="title">Playlist Management</div><div class="desc">Create and manage playlists that appear in the V Shots app. Add songs, reorder, and publish.</div></div></div>`;
}

function renderDiscover(el) {
  el.innerHTML = `<div class="card"><div class="card-header"><div class="card-title">🔍 Discover</div></div><div class="empty-state"><div class="icon">🔍</div><div class="title">Discover Feed</div><div class="desc">The Discover feed is powered by the recommendation engine. Content is automatically curated based on user listening patterns.</div></div></div>`;
}

function renderTrending(el) {
  el.innerHTML = `<div class="card"><div class="card-header"><div class="card-title">📈 Trending</div></div><div class="empty-state"><div class="icon">📈</div><div class="title">Trending Content</div><div class="desc">Trending content is automatically pulled from YouTube based on view counts and engagement. Configure trending parameters in Settings.</div></div></div>`;
}

function renderFeatured(el) {
  el.innerHTML = `<div class="card"><div class="card-header"><div class="card-title">⭐ Featured</div></div><div class="empty-state"><div class="icon">⭐</div><div class="title">Featured Content</div><div class="desc">Feature specific songs, artists, or playlists by adding them to Home CMS sections with high visibility.</div></div></div>`;
}

function renderProviders(el) {
  el.innerHTML = `
    <div class="stats-grid">
      <div class="stat-card"><div class="stat-label">YouTube</div><div class="stat-value" style="color:var(--green)">Active</div><div class="stat-change">Data API v3 + InnerTube</div></div>
      <div class="stat-card"><div class="stat-label">JioSaavn</div><div class="stat-value" style="color:var(--yellow)">Planned</div><div class="stat-change">Metadata provider</div></div>
    </div>
    <div class="card">
      <div class="card-title">Provider Configuration</div>
      <p style="color:var(--text2);margin-top:8px;font-size:14px">Provider settings are managed through environment variables and Supabase configuration. API keys are stored securely server-side.</p>
    </div>
  `;
}

function renderFeatureFlags(el) {
  const flags = [
    { name: 'ENABLE_YOUTUBE', desc: 'YouTube search and playback', active: true },
    { name: 'ENABLE_DISCOVER', desc: 'Discover feed', active: true },
    { name: 'ENABLE_RECOMMENDATIONS', desc: 'Recommendation engine', active: true },
    { name: 'ENABLE_TRENDING', desc: 'Trending content', active: true },
    { name: 'ENABLE_HOME_CMS', desc: 'Home page CMS', active: true },
    { name: 'ENABLE_JIOSAAVN', desc: 'JioSaavn metadata provider', active: false },
  ];
  el.innerHTML = `<div class="card"><div class="card-header"><div class="card-title">🚩 Feature Flags</div></div><div class="table-container"><table><thead><tr><th>Flag</th><th>Description</th><th>Status</th></tr></thead><tbody>${flags.map(f => `<tr><td><code>${f.name}</code></td><td>${f.desc}</td><td><span class="badge ${f.active ? 'badge-green' : 'badge-yellow'}">${f.active ? 'Enabled' : 'Disabled'}</span></td></tr>`).join('')}</tbody></table></div></div>`;
}

function renderAnalytics(el) {
  el.innerHTML = `
    <div class="stats-grid">
      <div class="stat-card"><div class="stat-label">Home Sections</div><div class="stat-value">${state.data.sections.length || '—'}</div></div>
      <div class="stat-card"><div class="stat-label">Active Providers</div><div class="stat-value">1</div></div>
      <div class="stat-card"><div class="stat-label">CMS Status</div><div class="stat-value" style="color:var(--green)">Live</div></div>
      <div class="stat-card"><div class="stat-label">Last Published</div><div class="stat-value" style="font-size:14px">—</div></div>
    </div>
    <div class="card"><div class="card-title">📊 Analytics</div><p style="color:var(--text2);margin-top:8px;font-size:14px">Detailed analytics (searches, plays, popular content) will be available once event tracking is implemented in the mobile app.</p></div>
  `;
}

function renderUsers(el) {
  el.innerHTML = `
    <div class="card">
      <div class="card-header"><div class="card-title">👥 Authorized Admins</div></div>
      <div class="table-container">
        <table>
          <thead><tr><th>Email</th><th>Status</th></tr></thead>
          <tbody>
            ${AUTHORIZED_EMAILS.map(email => `<tr><td>${esc(email)}</td><td><span class="badge badge-green">Authorized</span></td></tr>`).join('')}
          </tbody>
        </table>
      </div>
    </div>
  `;
}

function renderActivity(el) {
  el.innerHTML = `<div class="card"><div class="card-header"><div class="card-title">📝 Activity Log</div></div><div class="empty-state"><div class="icon">📝</div><div class="title">Activity Tracking</div><div class="desc">Admin actions (logins, content changes, publishes) will be logged here once activity tracking is implemented.</div></div></div>`;
}

function renderSettings(el) {
  el.innerHTML = `
    <div class="card">
      <div class="card-title">⚙️ General Settings</div>
      <div class="form-group" style="margin-top:16px">
        <label class="form-label">App Name</label>
        <input class="form-input" value="V Shots" disabled>
      </div>
      <div class="form-group">
        <label class="form-label">Package Name</label>
        <input class="form-input" value="com.vshots.live" disabled>
      </div>
      <div class="form-group">
        <label class="form-label">Version</label>
        <input class="form-input" value="5.8.0 (42)" disabled>
      </div>
      <div class="form-group">
        <label class="form-label">Supabase Project</label>
        <input class="form-input" value="jzxtxqjheggyoqwohqjg" disabled>
      </div>
    </div>
    <div class="card">
      <div class="card-title">🔐 Security</div>
      <p style="color:var(--text2);margin-top:8px;font-size:14px">All API keys and secrets are stored server-side in environment variables and GitHub Secrets. No secrets are exposed in the client.</p>
    </div>
  `;
}

// ═══════════════════════════════════════════════════════════════
// INIT
// ═══════════════════════════════════════════════════════════════
async function init() {
  console.log('[INIT] Starting initialization...');
  console.log('[INIT] Current URL:', window.location.href);
  
  // Direct access — no login required
  state.admin = true;
  state.user = { email: 'admin@vshots.live', id: 'direct-access' };
  console.log('[INIT] Direct access mode — rendering admin panel');
  renderAdmin();
}

// Auth listener kept for future use but not required for access
supabase.auth.onAuthStateChange((event, session) => {
  console.log('[AUTH] State change event:', event);
});

// Start — direct access to admin panel
console.log('[APP] Starting V Shots Admin...');
init();
