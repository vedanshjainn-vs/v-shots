import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ═══════════════════════════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════════════════════════
const SUPABASE_URL = 'https://jzxtxqjheggyoqwohqjg.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp6eHR4cWpoZWdneW9xd29ocWpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxODM4OTcsImV4cCI6MjEwMTc1OTg5N30.fD6pKQ4VRG-AoF-nLdpU9iMK1qWz4N-diqMUOJESVw8';
const AUTHORIZED_EMAILS = ['lovesongs1106@gmail.com','vedanshjainn@gmail.com','mrvedansh11@gmail.com'];

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { autoRefreshToken: true, persistSession: true, detectSessionInUrl: true }
});

// ═══════════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════════
const state = {
  user: null, admin: false, page: 'home-cms',
  sections: [], items: {}, flags: {},
  expandedSection: null, editingItem: null,
  saving: false, loading: true,
};

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
// SOURCE TYPE → DISPLAY MAPPING
// ═══════════════════════════════════════════════════════════════
const SOURCE_TYPES = {
  youtube_search:     { label: 'YouTube Search',  icon: '🔍', kind: 'catalog' },
  youtube_trending:   { label: 'YouTube Trending', icon: '📈', kind: 'catalog' },
  youtube_playlist:   { label: 'YouTube Playlist', icon: '📋', kind: 'catalog' },
  youtube_channel:    { label: 'YouTube Channel',  icon: '📺', kind: 'catalog' },
  personalized:       { label: 'Personalized',     icon: '✨', kind: 'personalized' },
  manual:             { label: 'Manual Items',     icon: '📌', kind: 'manual' },
  youtube_manual:     { label: 'Manual Items',     icon: '📌', kind: 'manual' },
  jiosaavn_manual:    { label: 'Manual Items',     icon: '📌', kind: 'manual' },
};

function sourceInfo(type) {
  return SOURCE_TYPES[type] || { label: type || 'Unknown', icon: '❓', kind: 'catalog' };
}

function isPersonalized(type) {
  return sourceInfo(type).kind === 'personalized';
}

function isManual(type) {
  return sourceInfo(type).kind === 'manual';
}

// ═══════════════════════════════════════════════════════════════
// DATA LOADING
// ═══════════════════════════════════════════════════════════════
async function loadAll() {
  state.loading = true;
  try {
    const [secRes, itemRes, flagRes] = await Promise.all([
      supabase.from('home_layout_config').select('*').order('sort_order'),
      supabase.from('home_section_items').select('*').order('sort_order'),
      supabase.from('feature_flags').select('*'),
    ]);
    state.sections = secRes.data || [];
    // Group items by section_id
    state.items = {};
    for (const item of (itemRes.data || [])) {
      const sid = item.section_id;
      if (!state.items[sid]) state.items[sid] = [];
      state.items[sid].push(item);
    }
    state.flags = {};
    for (const f of (flagRes.data || [])) {
      state.flags[f.key] = f.value;
    }
  } catch (e) {
    console.error('Load error:', e);
    toast('Failed to load data', 'error');
  }
  state.loading = false;
}

// ═══════════════════════════════════════════════════════════════
// NAV
// ═══════════════════════════════════════════════════════════════
const NAV = [
  { id: 'home-cms', label: 'Home Builder', icon: '🏠', section: 'Content' },
  { id: 'feature-flags', label: 'Feature Flags', icon: '🚩', section: 'System' },
  { id: 'providers', label: 'Providers', icon: '🔌', section: 'System' },
  { id: 'settings', label: 'Settings', icon: '⚙️', section: 'System' },
];

// ═══════════════════════════════════════════════════════════════
// RENDER — MAIN LAYOUT
// ═══════════════════════════════════════════════════════════════
function renderLayout() {
  const app = $('app');
  app.innerHTML = `
    <div class="admin-layout">
      <div class="overlay" id="overlay"></div>
      <aside class="sidebar" id="sidebar">
        <div class="sidebar-header">
          <div class="sidebar-logo">V</div>
          <div><div class="sidebar-title">V Shots Admin</div><div class="sidebar-subtitle">Home CMS</div></div>
        </div>
        <nav class="sidebar-nav" id="sidebar-nav"></nav>
      </aside>
      <div class="main">
        <header class="topbar">
          <div style="display:flex;align-items:center;gap:10px;min-width:0">
            <button class="btn btn-icon menu-btn" id="menu-btn">☰</button>
            <div class="topbar-title" id="page-title">Home Builder</div>
          </div>
          <div class="topbar-actions">
            <div class="topbar-status"></div>
            <span class="topbar-email">${esc(state.user?.email || '')}</span>
          </div>
        </header>
        <div class="content" id="content">
          <div style="text-align:center;padding:60px"><div class="spinner"></div></div>
        </div>
      </div>
    </div>
  `;

  // Sidebar nav
  const nav = $('sidebar-nav');
  let curSection = '';
  for (const item of NAV) {
    if (item.section !== curSection) {
      curSection = item.section;
      nav.innerHTML += `<div class="nav-section">${item.section}</div>`;
    }
    nav.innerHTML += `<div class="nav-item${state.page===item.id?' active':''}" data-page="${item.id}"><span class="icon">${item.icon}</span>${item.label}</div>`;
  }

  // Events
  $('menu-btn').onclick = () => {
    $('sidebar').classList.toggle('open');
    $('overlay').classList.toggle('open');
  };
  $('overlay').onclick = () => {
    $('sidebar').classList.remove('open');
    $('overlay').classList.remove('open');
  };
  nav.querySelectorAll('.nav-item').forEach(el => {
    el.onclick = () => {
      state.page = el.dataset.page;
      $('sidebar').classList.remove('open');
      $('overlay').classList.remove('open');
      renderLayout();
    };
  });

  loadPage();
}

async function loadPage() {
  const content = $('content');
  const title = $('page-title');
  const item = NAV.find(n => n.id === state.page);
  title.textContent = item?.label || 'Dashboard';

  switch(state.page) {
    case 'home-cms': await renderHomeCMS(content); break;
    case 'feature-flags': renderFeatureFlags(content); break;
    case 'providers': renderProviders(content); break;
    case 'settings': renderSettings(content); break;
    default: await renderHomeCMS(content);
  }
}

// ═══════════════════════════════════════════════════════════════
// HOME CMS — MAIN SCREEN
// ═══════════════════════════════════════════════════════════════
async function renderHomeCMS(el) {
  await loadAll();
  const sections = state.sections;

  el.innerHTML = `
    <div class="card" style="padding:12px 14px">
      <div class="card-header" style="margin-bottom:8px">
        <div>
          <div class="card-title">🏠 Home Page Builder</div>
          <div class="card-subtitle">${sections.length} sections • Changes live after publish</div>
        </div>
        <div class="btn-group">
          <button class="btn btn-primary btn-sm" id="add-section">+ Add</button>
          <button class="btn btn-success btn-sm" id="publish-all">🚀 Publish</button>
        </div>
      </div>
    </div>
    <div id="sections-list"></div>
  `;

  const list = $('sections-list');

  if (sections.length === 0) {
    list.innerHTML = `<div class="empty-state"><div class="icon">🏠</div><div class="title">No sections</div><div class="desc">Tap "+ Add" to create your first Home section.</div></div>`;
  } else {
    sections.forEach((s, i) => {
      const src = sourceInfo(s.source_type);
      const items = state.items[s.id] || [];
      const expanded = state.expandedSection === s.id;
      const provClass = s.provider === 'jiosaavn' ? 'provider-jiosaavn' : s.provider === 'youtube' ? 'provider-youtube' : 'provider-auto';
      const provLabel = s.provider === 'jiosaavn' ? 'JioSaavn' : s.provider === 'youtube' ? 'YouTube' : 'Auto';

      const d = document.createElement('div');
      d.className = 'section-card';
      d.innerHTML = `
        <div class="section-card-header" data-toggle="${s.id}">
          <span class="section-drag">☰</span>
          <div class="section-info">
            <div class="section-title">${src.icon} ${esc(s.title)}</div>
            <div class="section-meta">
              <span class="provider-badge ${provClass}">${provLabel}</span>
              <span>${src.label}</span>
              ${s.visible === false ? '<span class="badge badge-red">Hidden</span>' : ''}
              ${s.published === false ? '<span class="badge badge-yellow">Draft</span>' : ''}
              ${isManual(s.source_type) ? `<span>${items.length} items</span>` : ''}
            </div>
          </div>
          <div class="section-actions">
            <button class="btn btn-sm btn-icon" data-up="${i}" ${i===0?'disabled':''}>↑</button>
            <button class="btn btn-sm btn-icon" data-down="${i}" ${i===sections.length-1?'disabled':''}>↓</button>
          </div>
        </div>
        <div class="section-body${expanded?' open':''}" id="body-${s.id}">
          ${renderSectionForm(s, items)}
        </div>
      `;

      // Toggle expand
      d.querySelector(`[data-toggle="${s.id}"]`).onclick = (e) => {
        if (e.target.closest('[data-up]') || e.target.closest('[data-down]')) return;
        state.expandedSection = state.expandedSection === s.id ? null : s.id;
        renderHomeCMS(el);
      };

      // Reorder
      d.querySelector(`[data-up="${i}"]`)?.onclick = () => {
        if (i > 0) { [sections[i], sections[i-1]] = [sections[i-1], sections[i]]; renderHomeCMS(el); }
      };
      d.querySelector(`[data-down="${i}"]`)?.onclick = () => {
        if (i < sections.length-1) { [sections[i], sections[i+1]] = [sections[i+1], sections[i]]; renderHomeCMS(el); }
      };

      list.appendChild(d);
    });
  }

  // Add section
  $('add-section').onclick = () => {
    sections.push({
      id: uid(), section_key: `home_${Date.now()}`, title: 'New Section',
      subtitle: '', section_type: 'home_section', source_type: 'youtube_search',
      source_value: '', query: '', max_items: 15, visible: true, published: false,
      sort_order: sections.length, provider: 'youtube', playback_provider: 'youtube_web',
      fallback_provider: 'youtube_web', refresh_minutes: 60,
    });
    state.expandedSection = sections[sections.length-1].id;
    renderHomeCMS(el);
  };

  // Publish
  $('publish-all').onclick = () => publishAll(el);

  // Bind form changes
  bindSectionForms(el);
}

// ═══════════════════════════════════════════════════════════════
// SECTION FORM (expanded view)
// ═══════════════════════════════════════════════════════════════
function renderSectionForm(s, items) {
  const src = sourceInfo(s.source_type);
  const personalized = isPersonalized(s.source_type);
  const manual = isManual(s.source_type);

  let html = `
    <div class="form-row">
      <div class="form-group">
        <label class="form-label">Title</label>
        <input class="form-input" value="${esc(s.title)}" data-field="title" data-id="${s.id}">
      </div>
      <div class="form-group">
        <label class="form-label">Subtitle</label>
        <input class="form-input" value="${esc(s.subtitle || '')}" placeholder="Auto-generated" data-field="subtitle" data-id="${s.id}">
      </div>
    </div>
    <div class="form-row">
      <div class="form-group">
        <label class="form-label">Source Type</label>
        <select class="form-select" data-field="source_type" data-id="${s.id}">
          ${Object.entries(SOURCE_TYPES).map(([k,v]) => `<option value="${k}" ${s.source_type===k?'selected':''}>${v.icon} ${v.label}</option>`).join('')}
        </select>
      </div>
      <div class="form-group">
        <label class="form-label">Max Items</label>
        <input class="form-input" type="number" min="1" max="100" value="${s.max_items || 15}" data-field="max_items" data-id="${s.id}">
      </div>
    </div>
  `;

  if (!personalized) {
    html += `
      <div class="form-group">
        <label class="form-label">Search Query / Source Value</label>
        <input class="form-input" value="${esc(s.source_value || s.query || '')}" placeholder="e.g. trending songs 2026" data-field="source_value" data-id="${s.id}">
      </div>
    `;
  } else {
    html += `<div class="source-hint">${src.icon} <strong>${src.label}</strong> — Content is generated by the recommendation engine based on user listening history. No search query needed.</div>`;
  }

  html += `
    <div class="form-row">
      <div class="form-group">
        <label class="form-label">Playback Provider</label>
        <select class="form-select" data-field="provider" data-id="${s.id}">
          <option value="youtube" ${s.provider==='youtube'?'selected':''}>▶️ YouTube</option>
          <option value="jiosaavn" ${s.provider==='jiosaavn'?'selected':''}>🎵 JioSaavn</option>
          <option value="auto" ${s.provider==='auto'?'selected':''}>🔄 Auto</option>
        </select>
      </div>
      <div class="form-group">
        <label class="form-label">Fallback Provider</label>
        <select class="form-select" data-field="fallback_provider" data-id="${s.id}">
          <option value="youtube_web" ${s.fallback_provider==='youtube_web'?'selected':''}>YouTube</option>
          <option value="none" ${s.fallback_provider==='none'?'selected':''}>None</option>
        </select>
      </div>
    </div>
    <div class="form-row">
      <div class="form-group">
        <label class="form-check">
          <input type="checkbox" ${s.visible !== false ? 'checked' : ''} data-field="visible" data-id="${s.id}">
          <span>Visible on Home</span>
        </label>
      </div>
      <div class="form-group">
        <label class="form-check">
          <input type="checkbox" ${s.published !== false ? 'checked' : ''} data-field="published" data-id="${s.id}">
          <span>Published</span>
        </label>
      </div>
    </div>
    <div class="btn-group" style="margin-top:8px">
      <button class="btn btn-danger btn-sm" data-delete="${s.id}">🗑 Delete</button>
    </div>
  `;

  // Manual items section
  if (manual) {
    html += `<div style="margin-top:14px;padding-top:12px;border-top:1px solid var(--border)">
      <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px">
        <span style="font-size:13px;font-weight:700">📌 Manual Items (${items.length})</span>
        <button class="btn btn-sm btn-primary" data-add-item="${s.id}">+ Add Item</button>
      </div>
      <div id="items-${s.id}">
        ${items.map((item, idx) => renderItemCard(s.id, item, idx)).join('')}
        ${items.length === 0 ? '<div class="source-hint">No items yet. Tap "+ Add Item" to add songs.</div>' : ''}
      </div>
    </div>`;
  }

  return html;
}

function renderItemCard(sectionId, item, idx) {
  const provClass = item.provider === 'jiosaavn' ? 'provider-jiosaavn' : item.provider === 'youtube' ? 'provider-youtube' : 'provider-auto';
  const provLabel = item.provider === 'jiosaavn' ? 'JioSaavn' : item.provider === 'youtube' ? 'YouTube' : 'Auto';
  return `
    <div class="item-card">
      <div style="display:flex;align-items:center;justify-content:space-between">
        <div style="min-width:0;flex:1">
          <div class="item-card-title">${esc(item.title)}</div>
          <div class="item-card-meta">${esc(item.artist || '')} <span class="provider-badge ${provClass}">${provLabel}</span></div>
        </div>
        <div class="btn-group">
          <button class="btn btn-sm" data-edit-item="${sectionId}:${idx}">✏️</button>
          <button class="btn btn-sm btn-danger" data-del-item="${sectionId}:${idx}">✕</button>
        </div>
      </div>
    </div>
  `;
}

// ═══════════════════════════════════════════════════════════════
// ITEM EDITOR (bottom sheet)
// ═══════════════════════════════════════════════════════════════
function showItemEditor(sectionId, itemIdx) {
  const items = state.items[sectionId] || [];
  const isNew = itemIdx === -1;
  const item = isNew ? {
    title: '', artist: '', artwork_url: '', youtube_video_id: '',
    jiosaavn_url: '', provider: 'auto', content_id: uid(),
  } : { ...items[itemIdx] };

  // Remove existing sheet
  document.querySelector('.sheet')?.remove();
  document.querySelector('.overlay')?.classList.remove('open');

  const overlay = document.createElement('div');
  overlay.className = 'overlay open';
  document.body.appendChild(overlay);

  const sheet = document.createElement('div');
  sheet.className = 'sheet open';
  sheet.innerHTML = `
    <div class="sheet-handle"></div>
    <div class="card-title" style="margin-bottom:14px">${isNew ? '➕ Add Item' : '✏️ Edit Item'}</div>
    <div class="form-group">
      <label class="form-label">Title *</label>
      <input class="form-input" id="ie-title" value="${esc(item.title)}" placeholder="Song name">
    </div>
    <div class="form-group">
      <label class="form-label">Artist</label>
      <input class="form-input" id="ie-artist" value="${esc(item.artist || '')}" placeholder="Artist name">
    </div>
    <div class="form-group">
      <label class="form-label">Artwork URL</label>
      <input class="form-input" id="ie-artwork" value="${esc(item.artwork_url || '')}" placeholder="https://...">
    </div>
    <div class="form-group">
      <label class="form-label">YouTube Video ID</label>
      <input class="form-input" id="ie-youtube" value="${esc(item.youtube_video_id || '')}" placeholder="dQw4w9WgXcQ">
    </div>
    <div class="form-group">
      <label class="form-label">JioSaavn URL <span class="badge badge-green">Optional</span></label>
      <input class="form-input" id="ie-jiosaavn" value="${esc(item.jiosaavn_url || '')}" placeholder="https://www.jiosaavn.com/song/...">
      <div class="form-hint">Paste exact JioSaavn song page URL. Must be HTTPS on jiosaavn.com.</div>
      <div class="form-error" id="ie-jiosaavn-error" style="display:none"></div>
    </div>
    <div class="form-group">
      <label class="form-label">Playback Provider</label>
      <select class="form-select" id="ie-provider">
        <option value="auto" ${item.provider==='auto'?'selected':''}>🔄 Auto (YouTube first, JioSaavn if URL set)</option>
        <option value="youtube" ${item.provider==='youtube'?'selected':''}>▶️ YouTube</option>
        <option value="jiosaavn" ${item.provider==='jiosaavn'?'selected':''}>🎵 JioSaavn</option>
      </select>
    </div>
    <div class="btn-group" style="margin-top:16px">
      <button class="btn btn-success" id="ie-save" style="flex:1">💾 Save</button>
      <button class="btn" id="ie-cancel">Cancel</button>
    </div>
  `;
  document.body.appendChild(sheet);

  // Validate JioSaavn URL on input
  $('ie-jiosaavn').oninput = () => {
    const url = $('ie-jiosaavn').value.trim();
    const err = $('ie-jiosaavn-error');
    if (url && !isValidJioSaavnUrl(url)) {
      err.textContent = 'Must be HTTPS on jiosaavn.com or saavn.com. No media/stream URLs.';
      err.style.display = 'block';
    } else {
      err.style.display = 'none';
    }
  };

  const close = () => {
    sheet.classList.remove('open');
    overlay.classList.remove('open');
    setTimeout(() => { sheet.remove(); overlay.remove(); }, 300);
  };

  overlay.onclick = close;
  $('ie-cancel').onclick = close;

  $('ie-save').onclick = () => {
    const title = $('ie-title').value.trim();
    if (!title) { toast('Title is required', 'error'); return; }

    const jUrl = $('ie-jiosaavn').value.trim();
    if (jUrl && !isValidJioSaavnUrl(jUrl)) {
      toast('Invalid JioSaavn URL', 'error');
      return;
    }

    const updated = {
      id: item.id || uid(),
      section_id: sectionId,
      content_id: item.content_id || uid(),
      title,
      artist: $('ie-artist').value.trim(),
      artwork_url: $('ie-artwork').value.trim(),
      youtube_video_id: $('ie-youtube').value.trim(),
      jiosaavn_url: jUrl,
      provider: $('ie-provider').value,
      playback_provider: $('ie-provider').value === 'jiosaavn' ? 'jiosaavn_web' : 'youtube_web',
      fallback_provider: 'youtube_web',
      sort_order: isNew ? items.length : item.sort_order ?? itemIdx,
      is_enabled: true,
    };

    if (isNew) {
      items.push(updated);
    } else {
      items[itemIdx] = { ...items[itemIdx], ...updated };
    }
    state.items[sectionId] = items;
    close();
    renderHomeCMS($('content'));
  };
}

function isValidJioSaavnUrl(url) {
  try {
    const u = new URL(url);
    if (u.protocol !== 'https:') return false;
    const host = u.hostname.toLowerCase();
    const ok = ['jiosaavn.com','www.jiosaavn.com','saavn.com','www.saavn.com'];
    if (!ok.some(h => host === h || host.endsWith('.'+h))) return false;
    const bad = ['.mp3','.m4a','.m3u8','.mp4','.mpd','.aac'];
    if (bad.some(e => url.toLowerCase().includes(e))) return false;
    if (/cdn|stream|download|media/.test(host)) return false;
    return true;
  } catch { return false; }
}

// ═══════════════════════════════════════════════════════════════
// BIND FORM EVENTS
// ═══════════════════════════════════════════════════════════════
function bindSectionForms(el) {
  // Field changes
  el.querySelectorAll('[data-field]').forEach(input => {
    const field = input.dataset.field;
    const id = input.dataset.id;
    input.onchange = () => {
      const s = state.sections.find(x => x.id === id);
      if (!s) return;
      if (field === 'visible' || field === 'published') s[field] = input.checked;
      else if (field === 'max_items') s[field] = parseInt(input.value) || 15;
      else s[field] = input.value;
      // Re-render if source_type changed
      if (field === 'source_type') renderHomeCMS(el);
    };
  });

  // Delete section
  el.querySelectorAll('[data-delete]').forEach(btn => {
    btn.onclick = () => {
      const id = btn.dataset.delete;
      if (!confirm('Delete this section?')) return;
      state.sections = state.sections.filter(s => s.id !== id);
      delete state.items[id];
      renderHomeCMS(el);
    };
  });

  // Add item
  el.querySelectorAll('[data-add-item]').forEach(btn => {
    btn.onclick = () => showItemEditor(btn.dataset.addItem, -1);
  });

  // Edit item
  el.querySelectorAll('[data-edit-item]').forEach(btn => {
    const [sid, idx] = btn.dataset.editItem.split(':');
    btn.onclick = () => showItemEditor(sid, parseInt(idx));
  });

  // Delete item
  el.querySelectorAll('[data-del-item]').forEach(btn => {
    const [sid, idx] = btn.dataset.delItem.split(':');
    btn.onclick = () => {
      const items = state.items[sid] || [];
      items.splice(parseInt(idx), 1);
      renderHomeCMS(el);
    };
  });
}

// ═══════════════════════════════════════════════════════════════
// PUBLISH
// ═══════════════════════════════════════════════════════════════
async function publishAll(el) {
  const btn = $('publish-all');
  btn.disabled = true;
  btn.textContent = '⏳ Publishing...';
  state.saving = true;

  try {
    // 1. Upsert sections
    const rows = state.sections.map((s, i) => ({
      id: s.id,
      section_key: s.section_key || `home_${s.id}`,
      title: s.title || 'Untitled',
      subtitle: s.subtitle || null,
      section_type: s.section_type || 'home_section',
      source_type: s.source_type || 'youtube_search',
      source_value: s.source_value || s.query || null,
      query: s.query || s.source_value || null,
      sort_order: i,
      visible: s.visible !== false,
      published: s.published !== false,
      max_items: Math.max(1, Math.min(100, Number(s.max_items) || 15)),
      provider: s.provider || 'youtube',
      playback_provider: s.playback_provider || 'youtube_web',
      fallback_provider: s.fallback_provider || 'youtube_web',
      refresh_minutes: s.refresh_minutes || 60,
      region_code: s.region_code || null,
      category_id: s.category_id || null,
    }));

    // Delete stale sections
    const { data: existing } = await supabase.from('home_layout_config').select('id');
    const keep = new Set(rows.map(r => r.id));
    const stale = (existing || []).map(r => r.id).filter(id => !keep.has(id));
    if (stale.length) await supabase.from('home_layout_config').delete().in('id', stale);

    // Upsert sections
    if (rows.length) await supabase.from('home_layout_config').upsert(rows, { onConflict: 'id' });

    // 2. Upsert items
    const allItems = [];
    for (const [sid, items] of Object.entries(state.items)) {
      for (let i = 0; i < items.length; i++) {
        const item = items[i];
        allItems.push({
          id: item.id || uid(),
          section_id: sid,
          content_id: item.content_id || uid(),
          title: item.title || 'Untitled',
          artist: item.artist || null,
          artwork_url: item.artwork_url || null,
          provider: item.provider || 'youtube',
          playback_provider: item.playback_provider || 'youtube_web',
          fallback_provider: item.fallback_provider || 'youtube_web',
          jiosaavn_url: item.jiosaavn_url || null,
          jiosaavn_enabled: !!item.jiosaavn_url,
          youtube_video_id: item.youtube_video_id || null,
          sort_order: i,
          is_enabled: item.is_enabled !== false,
          metadata: item.metadata || {},
        });
      }
    }

    // Delete stale items for our sections
    const sectionIds = rows.map(r => r.id);
    if (sectionIds.length) {
      await supabase.from('home_section_items').delete().in('section_id', sectionIds);
    }
    if (allItems.length) {
      await supabase.from('home_section_items').upsert(allItems, { onConflict: 'id' });
    }

    // 3. Bump config version
    await supabase.from('home_config').upsert({
      id: 'current',
      version: Date.now(),
      status: 'published',
      published_at: new Date().toISOString(),
    }, { onConflict: 'id' });

    toast(`Published ${rows.length} sections, ${allItems.length} items!`);
  } catch (e) {
    console.error('Publish error:', e);
    toast(`Publish failed: ${e.message}`, 'error');
  }

  state.saving = false;
  btn.disabled = false;
  btn.textContent = '🚀 Publish';
}

// ═══════════════════════════════════════════════════════════════
// FEATURE FLAGS
// ═══════════════════════════════════════════════════════════════
function renderFeatureFlags(el) {
  const flags = [
    { key: 'enable_remote_home', label: 'Remote Home CMS', desc: 'Fetch Home config from Supabase' },
    { key: 'enable_jiosaavn_web_playback', label: 'JioSaavn Web Playback', desc: 'Enable JioSaavn WebView playback' },
    { key: 'enable_jiosaavn_search_fallback', label: 'JioSaavn Search Fallback', desc: 'Allow search page when no exact URL' },
    { key: 'enable_jiosaavn_exact_urls', label: 'JioSaavn Exact URLs', desc: 'Allow exact JioSaavn song page URLs' },
    { key: 'enable_youtube_web_playback', label: 'YouTube Web Playback', desc: 'Enable YouTube WebView playback' },
    { key: 'enable_home_cms', label: 'Home CMS', desc: 'Enable Home page CMS' },
  ];

  el.innerHTML = `
    <div class="card">
      <div class="card-title" style="margin-bottom:14px">🚩 Feature Flags</div>
      ${flags.map(f => `
        <div style="display:flex;align-items:center;justify-content:space-between;padding:10px 0;border-bottom:1px solid var(--border)">
          <div style="min-width:0;flex:1">
            <div style="font-size:14px;font-weight:600">${f.label}</div>
            <div style="font-size:11px;color:var(--text2)">${f.desc}</div>
          </div>
          <label class="form-check" style="margin:0">
            <input type="checkbox" ${state.flags[f.key] ? 'checked' : ''} data-flag="${f.key}">
          </label>
        </div>
      `).join('')}
      <div class="btn-group" style="margin-top:16px">
        <button class="btn btn-success" id="save-flags">💾 Save Flags</button>
      </div>
    </div>
  `;

  $('save-flags').onclick = async () => {
    const btn = $('save-flags');
    btn.disabled = true;
    try {
      for (const f of flags) {
        const checked = el.querySelector(`[data-flag="${f.key}"]`).checked;
        await supabase.from('feature_flags').upsert({
          key: f.key, value: checked, description: f.desc,
        }, { onConflict: 'key' });
      }
      toast('Flags saved!');
    } catch (e) {
      toast(`Failed: ${e.message}`, 'error');
    }
    btn.disabled = false;
  };
}

// ═══════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════
function renderProviders(el) {
  el.innerHTML = `
    <div class="stats-grid">
      <div class="stat-card"><div class="stat-label">YouTube</div><div class="stat-value" style="color:var(--green)">Active</div><div class="stat-change">Data API v3 + InnerTube</div></div>
      <div class="stat-card"><div class="stat-label">JioSaavn</div><div class="stat-value" style="color:${state.flags.enable_jiosaavn_web_playback ? 'var(--green)' : 'var(--yellow)'}">${state.flags.enable_jiosaavn_web_playback ? 'Active' : 'Disabled'}</div><div class="stat-change">Webpage playback only</div></div>
    </div>
    <div class="card">
      <div class="card-title">🔌 How to get a JioSaavn URL</div>
      <div class="source-hint" style="margin-top:10px">
        1. Open <a href="https://www.jiosaavn.com" target="_blank">jiosaavn.com</a><br>
        2. Search for the song<br>
        3. Open the exact song page<br>
        4. Copy the URL from the address bar<br>
        5. Paste it in the item's JioSaavn URL field<br><br>
        <strong>Example:</strong> <code>https://www.jiosaavn.com/song/kesariya/BT8sWBlRelQ</code>
      </div>
    </div>
  `;
}

// ═══════════════════════════════════════════════════════════════
// SETTINGS
// ═══════════════════════════════════════════════════════════════
function renderSettings(el) {
  el.innerHTML = `
    <div class="card">
      <div class="card-title">⚙️ App Info</div>
      <div class="form-group" style="margin-top:12px">
        <label class="form-label">Package</label>
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
      <div class="source-hint" style="margin-top:8px">
        Admin write access is controlled by Supabase RLS (authenticated users only).
        The anon key is public — write permissions require authentication.
        No service-role keys are exposed in the client.
      </div>
    </div>
  `;
}

// ═══════════════════════════════════════════════════════════════
// INIT
// ═══════════════════════════════════════════════════════════════
async function init() {
  state.admin = true;
  state.user = { email: 'admin@vshots.live' };
  renderLayout();
}

init();
