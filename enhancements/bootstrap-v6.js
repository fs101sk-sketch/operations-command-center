(() => {
  'use strict';
  if (window.__OCC_SAFE_BOOTSTRAP_V6__) return;
  window.__OCC_SAFE_BOOTSTRAP_V6__ = true;

  const styleHref = 'enhancements/calendar-views-v6.css?v=20260903-6';
  const modules = [
    'enhancements/calendar-views-v6.js?v=20260903-6',
    'enhancements/balance-2026-v6.js?v=20260903-6',
    'enhancements/balance-editor-v7.js?v=20260903-7',
    'enhancements/resident-affairs-bundle-v7.js?v=20260903-7',
    'enhancements/library-add-fix.js?v=20260903-6'
  ];
  let attempts = 0;

  const ready = () => Boolean(
    document.querySelector('.deck') &&
    window.PlanEditorAPI &&
    window.PlanCalendarV6 &&
    window.PlanCloudAuth
  );

  const loadStyle = href => {
    if (document.querySelector('link[data-occ-calendar-v6]')) return;
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = href;
    link.dataset.occCalendarV6 = 'true';
    document.head.appendChild(link);
  };

  const load = src => new Promise((resolve, reject) => {
    const key = src.split('?')[0];
    if (document.querySelector(`script[data-occ-module="${key}"]`)) return resolve();
    const script = document.createElement('script');
    script.src = src;
    script.dataset.occModule = key;
    script.onload = resolve;
    script.onerror = () => reject(new Error(`module_load_failed:${src}`));
    document.head.appendChild(script);
  });

  const start = async () => {
    attempts += 1;
    if (!ready()) {
      if (attempts < 120) return setTimeout(start, 50);
      console.error('[operations-command-center] stable modules could not start because core APIs were not ready');
      return;
    }
    try {
      loadStyle(styleHref);
      for (const src of modules) await load(src);
      console.info('[operations-command-center] stable enhancements v7 ready');
    } catch (error) {
      console.error('[operations-command-center] safe module load failed', error);
    }
  };

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once: true });
  else start();
})();
