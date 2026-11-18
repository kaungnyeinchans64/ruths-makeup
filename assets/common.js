const cfg=window.RUTH_CONFIG;
const ready=cfg && cfg.supabaseUrl.startsWith('https://') && !cfg.supabaseUrl.includes('YOUR_') && cfg.supabaseAnonKey && !cfg.supabaseAnonKey.includes('YOUR_');
const db=ready?window.supabase.createClient(cfg.supabaseUrl,cfg.supabaseAnonKey):null;
const $=id=>document.getElementById(id);
const money=n=>'฿'+Number(n||0).toLocaleString('en-US');
const escapeHtml=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function notice(message){const el=$('notice');if(el){el.textContent=message;el.classList.remove('hidden')}}
async function currentUser(){if(!db)return null;const {data}=await db.auth.getUser();return data.user}
async function signIn(email,password){const {error}=await db.auth.signInWithPassword({email,password});if(error)throw error}
async function signUp(email,password,name){const {error}=await db.auth.signUp({email,password,options:{data:{full_name:name}}});if(error)throw error}
async function logout(){if(db)await db.auth.signOut();location.reload()}
