(() => {
  'use strict';
  /* Compatibility repair for the existing resource-library module.
     It never rewrites cards or saved library content. */
  const session=()=>window.PlanCloudAuth?.getSession?.();
  function repair(){
    const slide=document.querySelector('.resource-library-slide');
    if(!slide)return;
    document.querySelectorAll('[data-library-readonly-note]').forEach(n=>n.remove());
    const user=session()?.user;
    const signedIn=Boolean(session()?.local_token);
    const admin=user?.role==='admin';
    /* Access manager remains the authority. We only clear the accidental
       client-side lock that was introduced by the previous enhancement. */
    if(admin){
      slide.dataset.accessEdit='true';
      slide.dataset.accessCreate='true';
      slide.dataset.accessDelete='true';
      slide.dataset.accessAssign='true';
      document.body.classList.add('cloud-editor');
    }
    const add=slide.querySelector('[data-resource-add]');
    if(add){
      const allowed=signedIn && (admin || (slide.dataset.accessCreate!=='false' && slide.dataset.accessEdit!=='false'));
      add.disabled=!allowed;
      add.title=allowed?'إضافة مورد إلى مكتبة القادة':'لا توجد صلاحية إضافة في هذه الصفحة';
    }
    slide.querySelectorAll('.resource-card').forEach(card=>{
      if(signedIn && slide.dataset.accessEdit!=='false')card.setAttribute('draggable','true');
    });
    window.PlanResourceLibrary?.rehydrate?.();
  }
  function init(){
    repair();
    const deck=document.querySelector('.deck');
    if(deck)new MutationObserver(m=>{
      if(m.some(x=>[...x.addedNodes].some(n=>n.nodeType===1 && (n.matches?.('.resource-library-slide')||n.querySelector?.('.resource-library-slide')))))setTimeout(repair,50);
    }).observe(deck,{childList:true});
    window.addEventListener('plan:auth-changed',()=>setTimeout(repair,80));
    window.addEventListener('plan:sections-saved',()=>setTimeout(repair,80));
    setTimeout(repair,500);
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();
