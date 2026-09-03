(() => {
  'use strict';
  if(window.__OCC_USER_MGMT_V8__)return;window.__OCC_USER_MGMT_V8__=true;
  const session=()=>window.PlanCloudAuth?.getSession?.()||null;
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const rpc=(name,args)=>window.PlanCloudAuth.rpc(name,args);
  let selectedId=null;
  function ui(){
    const list=document.getElementById('access-users-list');if(!list)return false;
    if(!document.getElementById('access-user-admin-tools')){
      const box=document.createElement('div');box.id='access-user-admin-tools';box.style.cssText='display:none;margin:10px 0;padding:12px;border:1px solid #d7e1dc;border-radius:12px;background:#fff';
      box.innerHTML=`<h3 style="margin:0 0 8px">إدارة الحساب</h3><div style="display:grid;grid-template-columns:1.2fr 1.2fr 1fr auto;gap:7px"><input id="aum-username" placeholder="اسم المستخدم"><input id="aum-name" placeholder="الاسم الظاهر"><select id="aum-role"><option value="viewer">مشاهد</option><option value="contributor">منفذ مهام</option><option value="editor">محرر</option><option value="admin">مدير</option></select><label style="display:flex;align-items:center;gap:5px"><input id="aum-active" type="checkbox"> نشط</label></div><div style="display:flex;gap:7px;flex-wrap:wrap;margin-top:8px"><button class="access-action" id="aum-save">حفظ بيانات الحساب</button><input id="aum-password" type="password" placeholder="كلمة مرور جديدة (8 أحرف+)" style="min-width:240px"><button class="access-action access-secondary" id="aum-reset">تغيير كلمة المرور</button><button class="access-action access-secondary" id="aum-delete" style="border-color:#d88;color:#a33">حذف المستخدم</button><button class="access-action access-secondary" id="aum-close">إغلاق</button></div><div id="aum-msg" style="margin-top:6px;font-size:10px"></div>`;
      list.parentNode.insertBefore(box,list);
      document.getElementById('aum-close').onclick=()=>{box.style.display='none';selectedId=null};
      document.getElementById('aum-save').onclick=saveUser;
      document.getElementById('aum-reset').onclick=resetPassword;
      document.getElementById('aum-delete').onclick=deleteUser;
    }
    return true;
  }
  async function loadUsers(){
    if(!ui()||session()?.user?.role!=='admin')return;
    try{
      const users=await rpc('app_admin_list_users',{p_token:session().local_token})||[];
      const list=document.getElementById('access-users-list');
      list.innerHTML=users.map(u=>`<div class="access-user-card"><div><b>${esc(u.username)}</b><small>${esc(u.display_name||'')} · ${esc(u.role)} · ${u.active?'نشط':'معطل'}</small></div><div style="display:flex;gap:5px"><button class="access-action access-secondary" data-user-manage="${u.id}">إدارة الحساب</button><button class="access-action access-secondary" data-edit-user="${u.id}">الصلاحيات</button></div></div>`).join('');
      list.querySelectorAll('[data-user-manage]').forEach(b=>b.onclick=()=>openUser(users.find(u=>u.id===b.dataset.userManage)));
      list.querySelectorAll('[data-edit-user]').forEach(b=>{b.onclick=()=>window.__occOriginalEditUser?.(b.dataset.editUser)});
    }catch(e){const m=document.getElementById('access-message');if(m)m.textContent=e.message}
  }
  function openUser(u){if(!u)return;selectedId=u.id;ui();const box=document.getElementById('access-user-admin-tools');box.style.display='block';document.getElementById('aum-username').value=u.username||'';document.getElementById('aum-name').value=u.display_name||'';document.getElementById('aum-role').value=u.role||'viewer';document.getElementById('aum-active').checked=!!u.active;document.getElementById('aum-password').value='';document.getElementById('aum-msg').textContent='';box.scrollIntoView({behavior:'smooth',block:'nearest'})}
  async function saveUser(){if(!selectedId)return;const msg=document.getElementById('aum-msg');msg.textContent='جارٍ الحفظ…';try{await rpc('app_admin_update_user',{p_token:session().local_token,p_user_id:selectedId,p_username:document.getElementById('aum-username').value.trim(),p_display_name:document.getElementById('aum-name').value.trim(),p_role:document.getElementById('aum-role').value,p_active:document.getElementById('aum-active').checked});msg.textContent='تم تحديث الحساب';await loadUsers()}catch(e){msg.textContent=e.message}}
  async function resetPassword(){if(!selectedId)return;const p=document.getElementById('aum-password').value,msg=document.getElementById('aum-msg');if(p.length<8){msg.textContent='كلمة المرور يجب أن تكون 8 أحرف على الأقل';return}try{await rpc('app_admin_reset_password',{p_token:session().local_token,p_user_id:selectedId,p_new_password:p,p_force_change:true});document.getElementById('aum-password').value='';msg.textContent='تم تغيير كلمة المرور وإغلاق الجلسات السابقة للمستخدم'}catch(e){msg.textContent=e.message}}
  async function deleteUser(){if(!selectedId)return;const msg=document.getElementById('aum-msg');if(!confirm('هل تريد حذف هذا المستخدم نهائيًا؟'))return;try{await rpc('app_admin_delete_user',{p_token:session().local_token,p_user_id:selectedId});selectedId=null;document.getElementById('access-user-admin-tools').style.display='none';msg.textContent='';await loadUsers()}catch(e){msg.textContent=e.message}}
  function hook(){
    if(typeof window.editUser==='function'&&!window.__occOriginalEditUser)window.__occOriginalEditUser=window.editUser;
    const usersTab=document.querySelector('[data-access-tab="users"]');if(usersTab&&!usersTab.dataset.um8){usersTab.dataset.um8='1';usersTab.addEventListener('click',()=>setTimeout(loadUsers,80))}
    ui();
  }
  const obs=new MutationObserver(()=>hook());
  const start=()=>{hook();obs.observe(document.body,{childList:true,subtree:true});window.addEventListener('plan:session-changed',()=>setTimeout(hook,80))};
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
