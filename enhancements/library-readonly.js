(() => {
  'use strict';
  const lock=()=>{
    const slide=document.querySelector('.resource-library-slide');
    if(!slide)return;
    slide.dataset.accessEdit='false';
    slide.dataset.accessCreate='false';
    slide.dataset.accessDelete='false';
    slide.querySelectorAll('[draggable="true"]').forEach(el=>el.removeAttribute('draggable'));
    const stats=slide.querySelector('.resource-library-stats');
    if(stats&&!stats.querySelector('[data-library-readonly-note]')){
      const note=document.createElement('span');
      note.dataset.libraryReadonlyNote='true';
      note.textContent='المكتبة للعرض فقط · الإضافة والتعديل معطّلان';
      note.style.cssText='padding:4px 8px;border-radius:999px;background:#eef3f1;color:#61736d;font-size:8px;font-weight:900';
      stats.appendChild(note);
    }
  };
  const blocked='[data-resource-add],[data-resource-action="edit"],[data-resource-action="delete"],[data-resource-action="pin"],[data-resource-action="up"],[data-resource-action="down"]';
  document.addEventListener('click',e=>{if(e.target.closest(`.resource-library-slide ${blocked}`)){e.preventDefault();e.stopImmediatePropagation();}},true);
  document.addEventListener('dragstart',e=>{if(e.target.closest('.resource-library-slide .resource-card')){e.preventDefault();e.stopImmediatePropagation();}},true);
  document.addEventListener('submit',e=>{if(e.target.closest('.resource-library-slide .resource-form')){e.preventDefault();e.stopImmediatePropagation();}},true);
  const init=()=>{lock();const deck=document.querySelector('.deck');if(deck)new MutationObserver(()=>setTimeout(lock,40)).observe(deck,{childList:true,subtree:true});};
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();
