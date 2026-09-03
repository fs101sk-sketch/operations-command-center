(() => {
  'use strict';
  if (window.__OCC_SAFE_BOOTSTRAP_V5__) return;
  window.__OCC_SAFE_BOOTSTRAP_V5__ = true;
  const modules = [
    'enhancements/calendar-views-v4.js?v=20260903-5',
    'enhancements/balance-2026-v4.js?v=20260903-5',
    'enhancements/library-add-fix.js?v=20260903-5'
  ];
  let attempts = 0;
  const ready = () => Boolean(
    document.querySelector('.deck') &&
    window.PlanEditorAPI &&
    window.PlanCalendarV6 &&
    window.PlanCloudAuth
  );
  const load = src => new Promise((resolve, reject) => {
    if (document.querySelector(`script[data-occ-module="${src.split('?')[0]}"]`)) return resolve();
    const script = document.createElement('script');
    script.src = src;
    script.dataset.occModule = src.split('?')[0];
    script.onload = resolve;
    script.onerror = () => reject(new Error(`module_load_failed:${src}`));
    document.head.appendChild(script);
  });
  const start = async () => {
    attempts += 1;
    if (!ready()) {
      if (attempts < 120) return setTimeout(start, 50);
      console.error('[operations-command-center] safe modules could not start because core APIs were not ready');
      return;
    }
    try {
      for (const src of modules) await load(src);
      console.info('[operations-command-center] stable enhancements v5 ready');
    } catch (error) {
      console.error('[operations-command-center] safe module load failed', error);
    }
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once:true});
  else start();
})();
