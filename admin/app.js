const SUPABASE_URL = 'https://jzxtxqjheggyoqwohqjg.supabase.co';
// Public anon/publishable key belongs here only after RLS policies are in place.
// Never put the database password or service-role key in this static site.
const SUPABASE_ANON_KEY = '';

const state = { sections: [] };
const $ = id => document.getElementById(id);
function status(t){ $('status').textContent=t; }
function render(){
  const root=$('sections'); root.innerHTML='';
  state.sections.forEach((s,i)=>{
    const d=document.createElement('div'); d.className='card section';
    d.innerHTML=`<input value="${esc(s.title||'')}" placeholder="Section title"><select><option value="youtube_search">YouTube Search</option><option value="youtube_playlist">YouTube Playlist</option><option value="youtube_channel">YouTube Channel</option><option value="youtube_manual">Manual Videos</option><option value="youtube_trending">YouTube Trending</option></select><input type="number" min="1" value="${s.max_items||20}"><button>Delete</button>`;
    const [title,type,count,del]=d.children; type.value=s.source_type||'youtube_search';
    title.oninput=e=>s.title=e.target.value; type.onchange=e=>s.source_type=e.target.value; count.oninput=e=>s.max_items=Number(e.target.value)||20; del.onclick=()=>{state.sections.splice(i,1);render()}; root.appendChild(d);
  });
}
function esc(x){return String(x).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;')}
$('add').onclick=()=>{state.sections.push({title:'New Section',source_type:'youtube_search',source_value:'',max_items:20,enabled:true,sort_order:state.sections.length});render()};
$('reload').onclick=async()=>{status('Remote config connection is ready once Supabase schema/RLS is deployed.');};
$('publish').onclick=async()=>{status('Publishing will be enabled after the Supabase RLS-backed CMS tables are deployed. No credentials are stored in this frontend.');};
render();
