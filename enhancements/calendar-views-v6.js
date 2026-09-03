(() => {
  'use strict';

  const deck = document.querySelector('.deck');
  const editor = window.PlanEditorAPI;
  const calendar = window.PlanCalendarV6;
  if (!deck || !editor || !calendar) return;

  const storageBase = document.documentElement.dataset.planStorageKey || 'hajj-1447-plan-editor-v2';
  const STORAGE_KEY = `${storageBase}-calendar-primary-view-v1`;
  const VALID_VIEWS = new Set(['month', 'day', 'year']);
  const CATEGORY_LABELS = {
    task: 'مهمة', meeting: 'اجتماع', deadline: 'موعد نهائي', visit: 'زيارة',
    report: 'تقرير', training: 'تدريب', leave: 'إجازة', other: 'أخرى'
  };
  const STATUS_LABELS = {
    planned: 'مخطط', in_progress: 'جاري', completed: 'مكتمل', cancelled: 'ملغي',
    closed: 'مغلقة', sent: 'تم الإرسال', review: 'قيد المراجعة', blocked: 'متعثر',
    open: 'مفتوح', overdue: 'متأخر', postponed: 'مؤجل'
  };

  const esc = (value = '') => String(value).replace(/[&<>"']/g, char => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;'
  })[char]);
  const parse = (value, fallback) => { try { return JSON.parse(value); } catch (_) { return fallback; } };
  const dateKey = date => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  const fromKey = key => {
    const date = new Date(`${key || ''}T12:00:00`);
    return Number.isNaN(date.getTime()) ? new Date() : date;
  };
  const eventEnd = event => event?.endDate && event.endDate >= event.date ? event.endDate : event?.date || '';
  const occurs = (event, key) => Boolean(event?.date && event.date <= key && eventEnd(event) >= key);
  const visible = event => calendar.eventVisible?.(event) ?? true;
  const people = () => window.PlanOperatingUI?.getData?.()?.people || [];
  const personName = id => people().find(person => person.id === id)?.name || '';
  const eventNames = event => [...new Set([...(event?.ownerIds || []), ...(event?.participantIds || [])])].map(personName).filter(Boolean);
  const formatDate = (key, full = false) => new Intl.DateTimeFormat('ar-SA-u-ca-gregory', full
    ? { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }
    : { day: 'numeric', month: 'long', year: 'numeric' }
  ).format(fromKey(key));

  const saved = parse(localStorage.getItem(STORAGE_KEY) || '', {});
  let viewMode = VALID_VIEWS.has(saved.viewMode) ? saved.viewMode : 'month';
  let patching = false;
  let deckRefreshQueued = false;

  function calendarSlide() { return deck.querySelector('.calendarSlide'); }
  function focusKey() {
    const selected = calendar.getSelectedDate?.();
    const stored = editor.getState()?.calendarDate;
    return viewMode === 'month' ? (selected || stored || dateKey(new Date())) : (stored || selected || dateKey(new Date()));
  }
  function focusDate() { return fromKey(focusKey()); }
  function savePreference() {
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify({ viewMode })); } catch (_) {}
  }

  function navigationLabel(action) {
    if (viewMode === 'day') return action === 'next' ? 'اليوم التالي ‹' : '› اليوم السابق';
    if (viewMode === 'year') return action === 'next' ? 'السنة التالية ‹' : '› السنة السابقة';
    return action === 'next' ? 'الشهر التالي ‹' : '› الشهر السابق';
  }

  function handleNavigation(action) {
    if (action === 'today') setFocus(dateKey(new Date()));
    else shift(action === 'next' ? 1 : -1);
  }

  function bindNavigation(slide) {
    ['prev', 'next', 'today'].forEach(action => {
      const button = slide.querySelector(`[data-cal-action="${action}"]`);
      if (!button) return;
      if (action !== 'today') button.textContent = navigationLabel(action);
      if (button.__primaryCalendarNavBound) return;
      button.__primaryCalendarNavBound = true;
      button.addEventListener('click', event => {
        if (viewMode === 'month') return;
        event.preventDefault();
        event.stopImmediatePropagation();
        handleNavigation(action);
      }, true);
    });
  }

  function ensurePrimaryViews() {
    const slide = calendarSlide();
    const header = slide?.querySelector('.calendar-header');
    const controls = slide?.querySelector('.calendar-controls');
    const main = slide?.querySelector('.calendar-main');
    if (!slide || !header || !controls || !main) return null;

    let switcher = controls.querySelector(':scope > .calendar-view-switch');
    if (!switcher) {
      switcher = document.createElement('div');
      switcher.className = 'calendar-view-switch';
      switcher.dataset.editorUi = 'true';
      switcher.setAttribute('aria-label', 'طريقة عرض التقويم');
      switcher.innerHTML = '<button type="button" data-calendar-view="day">يومي</button><button type="button" data-calendar-view="month">شهري</button><button type="button" data-calendar-view="year">سنوي</button>';
      controls.prepend(switcher);
    }

    let monthView = main.querySelector(':scope > .calendar-month-view');
    if (!monthView) {
      const weekdays = main.querySelector(':scope > .calendar-weekdays');
      const grid = main.querySelector(':scope > .calendar-grid');
      monthView = document.createElement('div');
      monthView.className = 'calendar-primary-view calendar-month-view';
      if (weekdays) monthView.appendChild(weekdays);
      if (grid) monthView.appendChild(grid);
      main.prepend(monthView);
    }

    let dayView = main.querySelector(':scope > .calendar-day-view');
    if (!dayView) {
      dayView = document.createElement('div');
      dayView.className = 'calendar-primary-view calendar-day-view';
      main.appendChild(dayView);
    }

    let yearView = main.querySelector(':scope > .calendar-year-view');
    if (!yearView) {
      yearView = document.createElement('div');
      yearView.className = 'calendar-primary-view calendar-year-view';
      main.appendChild(yearView);
    }

    bindNavigation(slide);
    return { slide, switcher, monthView, dayView, yearView };
  }

  function eventsOn(key) {
    return (editor.getState()?.events || [])
      .filter(event => occurs(event, key) && visible(event))
      .sort((a, b) => `${a.time || '99:99'}${a.title || ''}`.localeCompare(`${b.time || '99:99'}${b.title || ''}`, 'ar'));
  }

  function topicsOn(key) {
    return (calendar.getData?.()?.topics || []).filter(topic => topic.date === key);
  }

  function eventCard(event) {
    const names = eventNames(event);
    const range = eventEnd(event) > event.date ? ` · حتى ${formatDate(eventEnd(event))}` : '';
    return `<button type="button" class="calendar-day-agenda-item" data-calendar-event-open="${esc(event.id)}" style="--agenda-color:${esc(event.color || '#2f6b5c')}"><strong>${esc(event.title || 'موعد')}</strong><span>${event.time ? `${esc(event.time)} · ` : ''}${esc(CATEGORY_LABELS[event.category] || CATEGORY_LABELS.other)} · ${esc(STATUS_LABELS[event.status] || event.status || 'مخطط')}${range}${names.length ? ` · ${esc(names.join('، '))}` : ''}</span></button>`;
  }

  function renderDayView(view) {
    const key = focusKey();
    const events = eventsOn(key);
    const topics = topicsOn(key);
    const floating = events.filter(event => !/^\d{2}:\d{2}$/.test(event.time || ''));
    const timed = new Map();
    events.filter(event => /^\d{2}:\d{2}$/.test(event.time || '')).forEach(event => {
      const hour = Number(event.time.slice(0, 2));
      if (!timed.has(hour)) timed.set(hour, []);
      timed.get(hour).push(event);
    });
    const hours = Array.from({ length: 24 }, (_, hour) => hour);
    view.innerHTML = `
      <div class="calendar-day-view-head">
        <div><strong>${esc(formatDate(key, true))}</strong><span>${events.length} موعد · ${topics.length} موضوع يومي</span></div>
        <button type="button" data-calendar-day-add="${esc(key)}">＋ إضافة موعد</button>
      </div>
      ${topics.length ? `<div class="calendar-day-topics"><strong>موضوعات اليوم</strong>${topics.map(topic => `<span class="${topic.done ? 'done' : ''}">${topic.done ? '✓ ' : ''}${esc(topic.text)}${topic.ownerLabel || topic.ownerId ? ` · ${esc(topic.ownerLabel || personName(topic.ownerId))}` : ''}</span>`).join('')}</div>` : ''}
      <div class="calendar-day-timeline">
        ${floating.length ? `<div class="calendar-day-floating">${floating.map(eventCard).join('')}</div>` : ''}
        ${hours.map(hour => `<div class="calendar-hour-row"><time>${String(hour).padStart(2, '0')}:00</time><div>${(timed.get(hour) || []).map(eventCard).join('')}</div></div>`).join('')}
      </div>`;
  }

  function countEventsInMonth(year, monthIndex) {
    const start = dateKey(new Date(year, monthIndex, 1, 12));
    const end = dateKey(new Date(year, monthIndex + 1, 0, 12));
    return (editor.getState()?.events || []).filter(event => visible(event) && event.date <= end && eventEnd(event) >= start).length;
  }

  function renderYearView(view) {
    const focus = focusDate();
    const year = focus.getFullYear();
    const today = dateKey(new Date());
    const weekdays = ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'];
    view.innerHTML = Array.from({ length: 12 }, (_, monthIndex) => {
      const first = new Date(year, monthIndex, 1, 12);
      const days = new Date(year, monthIndex + 1, 0, 12).getDate();
      const blanks = first.getDay();
      const monthName = new Intl.DateTimeFormat('ar-SA-u-ca-gregory', { month: 'long' }).format(first);
      const cells = [
        ...Array.from({ length: blanks }, () => '<i></i>'),
        ...Array.from({ length: days }, (_, index) => {
          const key = dateKey(new Date(year, monthIndex, index + 1, 12));
          const count = eventsOn(key).length;
          return `<button type="button" class="calendar-mini-day${count ? ' has-events' : ''}${key === today ? ' today' : ''}" data-calendar-date="${key}" title="${esc(formatDate(key))}${count ? ` · ${count} موعد` : ''}"><span>${index + 1}</span>${count ? `<b>${count > 9 ? '9+' : count}</b>` : ''}</button>`;
        })
      ].join('');
      return `<article class="calendar-mini-month"><button type="button" class="calendar-mini-month-title" data-calendar-month="${year}-${String(monthIndex + 1).padStart(2, '0')}-01"><strong>${esc(monthName)}</strong><span>${countEventsInMonth(year, monthIndex)} موعد</span></button><div class="calendar-mini-weekdays">${weekdays.map(day => `<i>${day}</i>`).join('')}</div><div class="calendar-mini-grid">${cells}</div></article>`;
    }).join('');
  }

  function renderPrimaryView() {
    if (patching) return;
    patching = true;
    try {
      const ui = ensurePrimaryViews();
      if (!ui) return;
      const date = focusDate();
      ui.slide.dataset.calendarView = viewMode;
      ui.slide.querySelectorAll('.calendar-primary-view').forEach(view => view.classList.toggle('active', view.classList.contains(`calendar-${viewMode}-view`)));
      ui.slide.querySelectorAll('[data-calendar-view]').forEach(button => button.classList.toggle('active', button.dataset.calendarView === viewMode));
      const label = ui.slide.querySelector('.calendar-month-label');
      if (label) {
        label.textContent = viewMode === 'day'
          ? formatDate(focusKey(), true)
          : viewMode === 'year'
            ? new Intl.DateTimeFormat('ar-SA-u-ca-gregory', { year: 'numeric' }).format(date)
            : new Intl.DateTimeFormat('ar-SA-u-ca-gregory', { month: 'long', year: 'numeric' }).format(date);
      }
      if (viewMode === 'day') renderDayView(ui.dayView);
      if (viewMode === 'year') renderYearView(ui.yearView);
    } finally {
      patching = false;
    }
  }

  function setFocus(key, renderCore = true) {
    const state = editor.getState();
    state.calendarDate = key;
    calendar.selectDay?.(key);
    editor.saveDataOnly?.();
    if (renderCore) editor.renderCalendar?.();
    else renderPrimaryView();
  }

  function setView(mode) {
    if (!VALID_VIEWS.has(mode)) return;
    viewMode = mode;
    savePreference();
    if (mode === 'day' && !calendar.getSelectedDate?.()) calendar.selectDay?.(editor.getState()?.calendarDate || dateKey(new Date()));
    editor.renderCalendar?.();
  }

  function shift(amount) {
    const date = focusDate();
    if (viewMode === 'day') date.setDate(date.getDate() + amount);
    else if (viewMode === 'year') date.setFullYear(date.getFullYear() + amount);
    else return;
    setFocus(dateKey(date));
  }

  const originalAfterRender = calendar.afterRender?.bind(calendar);
  if (!calendar.__primaryViewsWrapped) {
    calendar.afterRender = (...args) => {
      originalAfterRender?.(...args);
      renderPrimaryView();
    };
    calendar.__primaryViewsWrapped = true;
  }

  const originalGetData = calendar.getData?.bind(calendar);
  const originalSetData = calendar.setData?.bind(calendar);
  if (originalGetData && originalSetData && !calendar.__primaryViewStateWrapped) {
    calendar.getData = () => ({ ...originalGetData(), viewMode });
    calendar.setData = value => {
      if (VALID_VIEWS.has(value?.viewMode)) viewMode = value.viewMode;
      savePreference();
      return originalSetData(value);
    };
    calendar.__primaryViewStateWrapped = true;
  }

  document.addEventListener('click', event => {
    const viewButton = event.target.closest('button[data-calendar-view]');
    if (viewButton && calendarSlide()?.contains(viewButton)) {
      event.preventDefault();
      event.stopPropagation();
      setView(viewButton.dataset.calendarView);
      return;
    }

    const dateButton = event.target.closest('[data-calendar-date]');
    if (dateButton && calendarSlide()?.contains(dateButton)) {
      event.preventDefault();
      event.stopPropagation();
      viewMode = 'day';
      savePreference();
      setFocus(dateButton.dataset.calendarDate);
      return;
    }

    const monthButton = event.target.closest('[data-calendar-month]');
    if (monthButton && calendarSlide()?.contains(monthButton)) {
      event.preventDefault();
      event.stopPropagation();
      viewMode = 'month';
      savePreference();
      setFocus(monthButton.dataset.calendarMonth);
      return;
    }

    const eventButton = event.target.closest('[data-calendar-event-open]');
    if (eventButton && calendarSlide()?.contains(eventButton)) {
      event.preventDefault();
      event.stopPropagation();
      editor.openEvent?.({ eventId: eventButton.dataset.calendarEventOpen });
      return;
    }

    const dayAdd = event.target.closest('[data-calendar-day-add]');
    if (dayAdd && calendarSlide()?.contains(dayAdd)) {
      event.preventDefault();
      event.stopPropagation();
      editor.openEvent?.({ date: dayAdd.dataset.calendarDayAdd });
    }
  }, true);

  window.addEventListener('plan:event-saved', renderPrimaryView);
  window.addEventListener('plan:event-deleted', renderPrimaryView);
  window.addEventListener('plan:day-selected', event => {
    if (event.detail?.date && viewMode === 'day') requestAnimationFrame(renderPrimaryView);
  });

  const observer = new MutationObserver(() => {
    if (deckRefreshQueued) return;
    deckRefreshQueued = true;
    requestAnimationFrame(() => {
      deckRefreshQueued = false;
      ensurePrimaryViews();
      renderPrimaryView();
    });
  });
  observer.observe(deck, { childList: true });

  window.PlanCalendarViews = {
    getView: () => viewMode,
    setView,
    render: renderPrimaryView
  };

  ensurePrimaryViews();
  renderPrimaryView();
})();
