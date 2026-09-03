(() => {
  'use strict';
  if(window.__OCC_RESIDENT_AFFAIRS_BUNDLE_V7__)return;
  window.__OCC_RESIDENT_AFFAIRS_BUNDLE_V7__=true;
  const TITLE='شؤون المقيمين';
  const TARGET_KEY='page-balance-2026';
  function addButtons(){
    document.querySelectorAll('.access-bundles[data-bundle-holder], [data-bundle-holder]').forEach(holder=>{
      if(holder.querySelector('[data-resident-affairs-bundle]'))return;
      const b=document.createElement('button');
      b.type='button';b.className='access-bundle';b.dataset.residentAffairsBundle='true';
      b.innerHTML='<b>شؤون المقيمين</b><small>عرض وإضافة وتعديل رصيد 2026 فقط</small>';
      b.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();apply(holder.dataset.bundleHolder)});
      holder.appendChild(b);
    });
  }
  function apply(target){
    const root=target?document.getElementById(target):null;
    if(!root)return;
    root.querySelectorAll('[data-perm-page]').forEach(row=>{
      const isTarget=row.dataset.permPage===TARGET_KEY;
      ['view','edit','create','delete','assign'].forEach(action=>{
        const cb=row.querySelector(`[data-perm="${action}"]`);if(!cb)return;
        cb.checked=isTarget&&['view','edit','create'].includes(action);
      });
    });
    const msg=document.getElementById('access-message');
    if(msg)msg.textContent='تم تطبيق حزمة «شؤون المقيمين»: عرض وإضافة وتعديل رصيد 2026 فقط. يمكنك تخصيص الصلاحيات يدويًا قبل الحفظ.';
  }
  const obs=new MutationObserver(()=>addButtons());
  const start=()=>{addButtons();obs.observe(document.body,{childList:true,subtree:true})};
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
})();
