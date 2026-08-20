import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = 'https://jzxtxqjheggyoqwohqjg.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp6eHR4cWpobGVnZ3lvd3FvaGpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxODM4OTcsImV4cCI6MjEwMTc1OTg5N30.fD6pKQ4VRG-AoF-nLdpU9iMK1qWz4N-diqMUOJESVw8';
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Production GitHub Pages URL. Keep this explicit so OAuth never falls back
// to a local development URL when the dashboard is opened from production.
const PRODUCTION_REDIRECT_URL = 'https://vedanshjainn-vs.github.io/v-shots/admin/';

// Authorized Google accounts for CMS access
const AUTHORIZED_EMAILS = [
  'lovesongs1106@gmail.com',
  'vedanshjainn@gmail.com',
  'mrvedansh11@gmail.com',
];

const state = { sections: [], authenticated: false, admin: false };
const $ = id => document.getElementById(id);
function status(t, error = false){ $('status').textContent = t; $('status').dataset.error = error ? 'true' : 'false'; }
function uid(){ return globalThis.crypto?.randomUUID?.() || `section-${Date.now()}-${Math.random().toString(36).slice(2)}`; }
function esc(x){ return String(x ?? '').replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;'); }

async function ensureAdmin(){
  const { data: { user } } = await supabase.auth.getUser();
  state.authenticated = !!user;
  if (!user) return false;
  
  // Check if the user's email is in the authorized list
  const email = (user.email || '').toLowerCase().trim();
  const isAuthorized = AUTHORIZED_EMAILS.some(
    authorized => authorized.toLowerCase().trim() === email
  );
  
  if (!isAuthorized) {
    // Sign out unauthorized users immediately
    await supabase.auth.signOut();
    state.authenticated = false;
    state.admin = false;
    return false;
  }
  
  const { data, error } = await supabase.rpc('claim_home_admin');
  if (error) throw error;
  state.admin = data === true;
  return state.admin;
}

async function signIn(){
  const redirectTo = PRODUCTION_REDIRECT_URL;
  const { error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: { redirectTo },
  });
  if (error) status(`Google sign-in failed: ${error.message}`, true);
}
async function signOut(){ await supabase.auth.signOut(); state.sections=[]; state.authenticated=false; state.admin=false; render(); status('Signed out.'); }

async function load(){
  try {
    const ok = await ensureAdmin();
    if (!state.authenticated) { render(); status('Sign in with Google to manage Home.'); return; }
    if (!ok) { render(); status('This Google account is not authorized. Only approved accounts can access the CMS.', true); return; }
    const { data, error } = await supabase.from('home_layout_config').select('*').order('sort_order', { ascending: true });
    if (error) throw error;
    state.sections = data || [];
    render();
    status(`Connected. ${state.sections.length} Home section${state.sections.length === 1 ? '' : 's'} loaded.`);
  } catch (e) { render(); status(`CMS connection failed: ${e.message || e}`, true); }
}

function render(){
  $('sections').innerHTML='';
  $('auth').innerHTML = state.admin ? '<span class="auth-user">Admin connected</span><button id="signout">Sign out</button>' : '<button id="signin">Sign in with Google</button>';
  $('signin')?.addEventListener('click', signIn); $('signout')?.addEventListener('click', signOut);
  $('controls').style.display = state.admin ? 'flex' : 'none';
  if (!state.admin) return;
  state.sections.forEach((s,i)=>{
    const d=document.createElement('div'); d.className='card section';
    d.innerHTML=`<input class="title" value="${esc(s.title)}" placeholder="Section title"><input class="subtitle" value="${esc(s.subtitle || '')}" placeholder="Subtitle (optional)"><select class="source"><option value="youtube_search">YouTube Search</option><option value="youtube_playlist">YouTube Playlist</option><option value="youtube_channel">YouTube Channel</option><option value="youtube_manual">Manual Videos</option><option value="youtube_trending">YouTube Trending</option></select><input class="value" value="${esc(s.source_value || '')}" placeholder="Search / playlist / channel / video IDs"><input class="count" type="number" min="1" max="100" value="${s.max_items || 20}" title="Max items"><input class="region" value="${esc(s.region_code || '')}" placeholder="Region (e.g. IN)"><label class="visible"><input type="checkbox" class="enabled" ${s.visible !== false ? 'checked' : ''}> Visible</label><button class="up" ${i===0?'disabled':''}>↑</button><button class="down" ${i===state.sections.length-1?'disabled':''}>↓</button><button class="delete">Delete</button>`;
    const title=d.querySelector('.title'), subtitle=d.querySelector('.subtitle'), source=d.querySelector('.source'), value=d.querySelector('.value'), count=d.querySelector('.count'), region=d.querySelector('.region'), enabled=d.querySelector('.enabled');
    source.value=s.source_type || 'youtube_search';
    title.oninput=e=>s.title=e.target.value; subtitle.oninput=e=>s.subtitle=e.target.value; source.onchange=e=>s.source_type=e.target.value; value.oninput=e=>s.source_value=e.target.value; count.oninput=e=>s.max_items=Math.max(1, Math.min(100, Number(e.target.value)||20)); region.oninput=e=>s.region_code=e.target.value.toUpperCase(); enabled.onchange=e=>s.visible=e.target.checked;
    d.querySelector('.up').onclick=()=>move(i,-1); d.querySelector('.down').onclick=()=>move(i,1); d.querySelector('.delete').onclick=()=>{ state.sections.splice(i,1); render(); };
    $('sections').appendChild(d);
  });
}
function move(i,delta){ const j=i+delta; if(j<0 || j>=state.sections.length) return; [state.sections[i],state.sections[j]]=[state.sections[j],state.sections[i]]; render(); }

async function publish(){
  if (!state.admin) return;
  try {
    $('publish').disabled=true; status('Publishing Home configuration…');
    const { data: existing, error: readError } = await supabase.from('home_layout_config').select('id');
    if(readError) throw readError;
    const keep = new Set();
    const rows = state.sections.map((s,i)=>{ const id=s.id || uid(); keep.add(id); return { id, section_key:s.section_key || `home_${id}`, title:s.title || 'New Section', subtitle:s.subtitle || null, section_type:s.section_type || 'home_section', source_type:s.source_type || 'youtube_search', source_value:s.source_value || null, query:s.query || s.source_value || null, sort_order:i, visible:s.visible !== false, max_items:Math.max(1, Math.min(100, Number(s.max_items)||20)), region_code:s.region_code || null, category_id:s.category_id || null, refresh_minutes:Math.max(1, Number(s.refresh_minutes)||60), published:true }; });
    const stale=(existing||[]).map(x=>x.id).filter(id=>!keep.has(id));
    if(stale.length){ const {error}=await supabase.from('home_layout_config').delete().in('id',stale); if(error) throw error; }
    if(rows.length){ const {error}=await supabase.from('home_layout_config').upsert(rows,{onConflict:'id'}); if(error) throw error; }
    state.sections=rows; render(); status(`Published successfully. ${rows.length} section${rows.length===1?'':'s'} are now live.`);
  } catch(e){ status(`Publish failed: ${e.message || e}`, true); } finally { $('publish').disabled=false; }
}

$('add').onclick=()=>{state.sections.push({id:uid(),section_key:`home_${Date.now()}`,title:'New Section',subtitle:'',section_type:'home_section',source_type:'youtube_search',source_value:'',max_items:20,visible:true,sort_order:state.sections.length,refresh_minutes:60,published:false});render();};
$('reload').onclick=load; $('publish').onclick=publish;
supabase.auth.onAuthStateChange(()=>setTimeout(load,0));
load();
