// A faithful, interactive stand-in for Blenny's Organize window
// (Sources/BlennyApp/OrganizationBoardView.swift and friends): the same
// sections, wording, controls and states, populated with invented apps.

import { glyphs, glyphSVG, appIcon } from './glyphs.js';
import { sound } from './audio.js';

// Area wording as the app currently shows it (BoardViewComponents.swift).
// Update here when the app's labels change.
const AREAS = {
  visible: { title: 'Visible', subtitle: 'Not concealed by Blenny', dot: '#1f7ae0' },
  revealable: { title: 'Revealable', subtitle: 'Shown when you expand', dot: '#1fb3c8' },
  hidden: { title: 'Hidden', subtitle: 'Stays hidden when you expand', dot: '#8e8e93' },
};
// The same apps, in the same order, as the menu bar at the top of the page
// (glyphs.js), so the counts agree: Surface is Visible, Reef is Revealable and
// Deep is Hidden.
const fromArea = (area) => glyphs.filter((g) => g.area === area).map((g) => g.id);
const START = {
  visible: ['blenny', ...fromArea('surface')],
  revealable: fromArea('reef'),
  hidden: fromArea('deep'),
};
const byId = Object.fromEntries(glyphs.map((g) => [g.id, g]));
const nameOf = (id) => (id === 'blenny' ? 'Blenny' : byId[id].name);
const clone = (s) => JSON.parse(JSON.stringify(s));
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

const ICON = {
  organize: '<svg viewBox="0 0 20 20" width="17" height="17" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="2.5" y="4.5" width="6" height="4" rx="1"/><rect x="2.5" y="11.5" width="6" height="4" rx="1"/><rect x="11.5" y="4.5" width="6" height="11" rx="1.2"/></svg>',
  settings: '<svg viewBox="0 0 20 20" width="17" height="17" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="10" cy="10" r="2.6"/><path d="M10 2.5v2M10 15.5v2M2.5 10h2M15.5 10h2M4.7 4.7l1.4 1.4M13.9 13.9l1.4 1.4M4.7 15.3l1.4-1.4M13.9 6.1l1.4-1.4"/></svg>',
  support: '<svg viewBox="0 0 20 20" width="17" height="17" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M10 16.5s-6.5-3.9-6.5-8.4A3.4 3.4 0 0 1 10 6a3.4 3.4 0 0 1 6.5 2.1c0 4.5-6.5 8.4-6.5 8.4z"/></svg>',
  on: '<svg viewBox="0 0 20 20" width="15" height="15"><circle cx="10" cy="10" r="8" fill="#28c840"/><path d="M6.3 10.2l2.4 2.4 5-5" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  sliders: '<svg viewBox="0 0 20 20" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><path d="M3 5h14M3 10h14M3 15h14"/><circle cx="7" cy="5" r="1.6" fill="#fff"/><circle cx="12.5" cy="10" r="1.6" fill="#fff"/><circle cx="8.5" cy="15" r="1.6" fill="#fff"/></svg>',
  check: '<svg viewBox="0 0 20 20" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.3"><circle cx="10" cy="10" r="7.5"/><path d="M6.8 10.2l2.2 2.2 4.3-4.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  info: '<svg viewBox="0 0 20 20" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.3"><circle cx="10" cy="10" r="7.5"/><path d="M10 6v5" stroke-linecap="round"/><circle cx="10" cy="13.6" r="0.9" fill="currentColor" stroke="none"/></svg>',
  refresh: '<svg viewBox="0 0 20 20" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><path d="M15.5 10a5.5 5.5 0 1 1-1.6-3.9M15.5 4v3h-3"/></svg>',
  down: '<svg viewBox="0 0 20 20" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M10 3.5v11M5.5 10l4.5 4.5 4.5-4.5M4 17h12"/></svg>',
  lock: '<svg viewBox="0 0 12 12" width="11" height="11"><rect x="2" y="5.2" width="8" height="5.6" rx="1.2" fill="#ff3b30"/><path d="M3.9 5.2V3.9a2.1 2.1 0 0 1 4.2 0v1.3" fill="none" stroke="#ff3b30" stroke-width="1.3"/></svg>',
  left: '<svg viewBox="0 0 20 20" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M16 10H4M8.5 5.5L4 10l4.5 4.5"/></svg>',
  right: '<svg viewBox="0 0 20 20" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M4 10h12M11.5 5.5L16 10l-4.5 4.5"/></svg>',
  moveTo: '<svg viewBox="0 0 20 20" width="15" height="15" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><circle cx="10" cy="10" r="7.5"/><path d="M6.5 10h7M10.5 7l3 3-3 3"/></svg>',
  chevron: '<svg viewBox="0 0 20 20" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 8l4 4 4-4"/></svg>',
  hand: '<svg viewBox="0 0 48 48" width="40" height="40" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M17 26V12.5a2.5 2.5 0 0 1 5 0V24M22 23v-3.5a2.5 2.5 0 0 1 5 0V24M27 22a2.5 2.5 0 0 1 5 0v3M32 24a2.5 2.5 0 0 1 5 0v6c0 7-4.5 12-11 12h-2c-4 0-6.5-2-8.5-5L9 29.5a2.6 2.6 0 0 1 4-3.3L17 30"/></svg>',
};

// Apps show their app icon, as in the app; system items show their glyph.
function itemIcon(id) {
  if (id === 'blenny') return '<img src="assets/img/blenny-icon-512.png" alt="" width="30" height="30" draggable="false">';
  const g = byId[id];
  if (g.img) return `<img class="mac-appicon" src="${g.img}" alt="" width="30" height="30" draggable="false">`;
  return g.icon ? appIcon(g, 30, 'mac-appicon') : glyphSVG(g, 22);
}

export function createBoard(root, { toast, burst }) {
  root.classList.add('mac-window');
  root.innerHTML = `
    <div class="mac-titlebar"><span class="mac-lights"><i></i><i></i><i></i></span><span class="mac-title">Blenny 1.0.0</span></div>
    <nav class="mac-nav" aria-label="Blenny section">
      <span class="mac-segment is-selected">${ICON.organize}Organize</span>
      <span class="mac-segment">${ICON.settings}Settings</span>
      <span class="mac-segment">${ICON.support}Support</span>
    </nav>
    <div class="mac-body">
      <div class="mac-strip">
        ${ICON.on}<b>Management on</b><span class="mac-secondary">Expand to show Revealable items. Hidden items stay hidden.</span>
        <span class="mac-spacer"></span>
        <button class="mac-button" type="button" data-stop>Stop</button>
        <button class="mac-button" type="button" disabled>Restore Visibility</button>
      </div>
      <div class="mac-boardhead">
        <span class="mac-secondary">Drag &amp; Drop icons</span>
        <button class="mac-button mac-itemcontrols" type="button" data-controls>${ICON.sliders}Item controls</button>
      </div>
      <div class="mac-board">
        ${Object.entries(AREAS).map(([key, a]) => `
          <section class="mac-row" data-area="${key}" aria-label="${a.title}">
            <div class="mac-rowlabel">
              <div><i class="mac-dot" style="background:${a.dot}"></i><span class="mac-rowtitle">${a.title}</span><span class="mac-count" data-count></span></div>
              <div class="mac-rowsub" data-sub>${a.subtitle}</div>
            </div>
            <div class="mac-items" data-items></div>
          </section>`).join('')}
        <div class="mac-watermark" aria-hidden="true">${ICON.hand}<span>Drag &amp; Drop</span></div>
      </div>
      <div class="mac-order">
        <div class="mac-orderhead">${ICON.check}<b>Menu bar order</b><span class="mac-spacer"></span><button class="mac-button" type="button" data-undo>Undo Changes</button></div>
        <div class="mac-ordermsg" data-ordermsg>Changes applied.</div>
      </div>
    </div>
    <div class="mac-footer">
      ${ICON.info}<span class="mac-secondary" data-footer></span>
      <span class="mac-spacer"></span>
      <button class="mac-button" type="button" data-discard>Discard Changes</button>
      <button class="mac-button mac-default" type="button" data-apply>Apply</button>
      <button class="mac-button" type="button" data-refresh>${ICON.refresh}Refresh</button>
    </div>`;

  const q = (s) => root.querySelector(s);
  const rows = Object.fromEntries([...root.querySelectorAll('.mac-row')].map((r) => [r.dataset.area, r]));
  const itemsOf = (area) => rows[area].querySelector('[data-items]');
  let accepted = clone(START);
  let previous = null;
  let orderMessage = 'Changes applied.';
  let selected = null;
  let managing = true;

  const items = {};
  for (const [area, ids] of Object.entries(START)) {
    ids.forEach((id) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'mac-item';
      b.dataset.id = id;
      b.setAttribute('aria-label', nameOf(id));
      b.innerHTML = `${itemIcon(id)}${id === 'blenny' ? `<span class="mac-badge">${ICON.lock}</span>` : ''}<span class="mac-name">${nameOf(id)}</span>`;
      itemsOf(area).append(b);
      items[id] = b;
    });
  }

  const readDraft = () => Object.fromEntries(Object.keys(AREAS).map((a) => [a, [...itemsOf(a).children].map((c) => c.dataset.id)]));
  const areaOf = (state, id) => Object.keys(state).find((a) => state[a].includes(id));

  function flip(mutate) {
    const all = Object.values(items);
    const first = new Map(all.map((c) => [c, c.getBoundingClientRect()]));
    mutate();
    all.forEach((c) => {
      const a = first.get(c), b = c.getBoundingClientRect();
      const dx = a.left - b.left, dy = a.top - b.top;
      if (dx || dy) c.animate([{ transform: `translate(${dx}px, ${dy}px)` }, { transform: 'none' }], { duration: 360, easing: 'cubic-bezier(.16,1,.3,1)' });
    });
  }
  const arrange = (state) => flip(() => { for (const [a, ids] of Object.entries(state)) ids.forEach((id) => itemsOf(a).append(items[id])); });

  // Mirrors ProductInterfaceControls: draft edits disable management buttons until applied or discarded.
  function update() {
    const draft = readDraft();
    const dirty = !same(draft, accepted);
    for (const a of Object.keys(AREAS)) {
      const n = draft[a].length;
      rows[a].querySelector('[data-count]').textContent = `${n} app${n === 1 ? '' : 's'}`;
    }
    const total = Object.values(draft).flat().length;
    q('[data-footer]').textContent = dirty ? 'Changes not applied' : `${total} apps`;
    q('[data-ordermsg]').textContent = dirty ? 'Changes not applied.' : orderMessage;
    q('[data-apply]').hidden = !dirty;
    q('[data-discard]').hidden = !dirty;
    q('[data-refresh]').disabled = dirty;
    q('[data-undo]').disabled = dirty || !previous;
    q('[data-stop]').disabled = dirty;
    q('[data-stop]').textContent = managing ? 'Stop' : 'Resume';
    q('[data-controls]').disabled = !selected;
    Object.values(items).forEach((c) => c.classList.toggle('is-selected', c.dataset.id === selected));
  }

  function select(id) {
    selected = id;
    update();
  }

  q('[data-apply]').addEventListener('click', (e) => {
    previous = accepted;
    accepted = readDraft();
    orderMessage = 'Changes applied.';
    update();
    const r = e.currentTarget.getBoundingClientRect();
    burst(r.left + r.width / 2, r.top, 10, 40);
    toast('Applied. Undo Changes can reverse it in one step.');
  });
  q('[data-discard]').addEventListener('click', () => { arrange(accepted); update(); });
  q('[data-undo]').addEventListener('click', () => {
    if (!previous) return;
    accepted = previous;
    previous = null;
    orderMessage = 'Changes undone.';
    arrange(accepted);
    update();
    toast('Undone. Your menu bar is back to how it was.');
  });
  q('[data-stop]').addEventListener('click', () => {
    managing = !managing;
    const strip = q('.mac-strip');
    strip.querySelector('b').textContent = managing ? 'Management on' : 'Management stopped';
    strip.querySelector('.mac-secondary').textContent = managing
      ? 'Expand to show Revealable items. Hidden items stay hidden.'
      : 'Resume to use your saved visibility settings. Applied order is unchanged.';
    strip.querySelector('svg').outerHTML = managing ? ICON.on : ICON.check.replace('currentColor', '#8e8e93');
    update();
  });

  // ------------------------------------------------------------------
  // Item controls popover (SelectionDetailView): move left/right or to another area.
  // An icon dropped into a row lands with a small splash: rings and droplets.
  function splash(el) {
    if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const r = el.getBoundingClientRect(), box = root.getBoundingClientRect();
    const s = document.createElement('span');
    s.className = 'mac-splash';
    s.style.left = `${r.left - box.left + r.width / 2}px`;
    s.style.top = `${r.top - box.top + r.height / 2}px`;
    s.innerHTML = '<i></i><i></i><i></i>' + Array.from({ length: 8 }, (_, k) =>
      `<b style="--a:${Math.round(k * 45 + Math.random() * 25)}deg;--d:${Math.round(22 + Math.random() * 18)}px"></b>`).join('');
    root.append(s);
    sound.play('drip');
    setTimeout(() => s.remove(), 1000);
  }

  let popover = null, menu = null;
  function closeMenu() { menu?.remove(); menu = null; }
  function closePopover() { closeMenu(); popover?.remove(); popover = null; }
  function moveWithin(id, step) {
    const el = items[id], list = el.parentElement, kids = [...list.children], i = kids.indexOf(el), j = i + step;
    if (j < 0 || j >= kids.length) return;
    flip(() => list.insertBefore(el, step < 0 ? kids[j] : kids[j].nextSibling));
    update();
    openPopover();
  }
  function moveTo(id, area) {
    flip(() => itemsOf(area).append(items[id]));
    setTimeout(() => splash(items[id]), 260);
    update();
    openPopover();
  }
  function openPopover() {
    closePopover();
    if (!selected) return;
    const id = selected, el = items[id], area = el.parentElement.closest('.mac-row').dataset.area;
    const kids = [...el.parentElement.children], i = kids.indexOf(el);
    popover = document.createElement('div');
    popover.className = 'mac-popover';
    popover.innerHTML = `
      <span class="mac-popicon">${itemIcon(id)}</span>
      <span class="mac-poptext"><b>${nameOf(id)}</b><span>1 menu bar item · ${AREAS[area].title}</span><span>Sorting available.</span></span>
      <button class="mac-button" type="button" data-left aria-label="Move Left" ${i === 0 ? 'disabled' : ''}>${ICON.left}</button>
      <button class="mac-button" type="button" data-right aria-label="Move Right" ${i === kids.length - 1 ? 'disabled' : ''}>${ICON.right}</button>
      <button class="mac-button" type="button" data-moveto ${id === 'blenny' ? 'disabled' : ''}>${ICON.moveTo}Move to…${ICON.chevron}</button>`;
    root.append(popover);
    const anchor = q('[data-controls]').getBoundingClientRect(), box = root.getBoundingClientRect();
    popover.style.right = `${box.right - anchor.right}px`;
    popover.style.top = `${anchor.bottom - box.top + 10}px`;
    popover.querySelector('[data-left]').addEventListener('click', () => moveWithin(id, -1));
    popover.querySelector('[data-right]').addEventListener('click', () => moveWithin(id, 1));
    popover.querySelector('[data-moveto]').addEventListener('click', (e) => {
      closeMenu();
      menu = document.createElement('div');
      menu.className = 'ctx';
      menu.innerHTML = Object.entries(AREAS).map(([key, a]) => `<button type="button" data-to="${key}" ${key === area ? 'disabled' : ''}>Move to ${a.title}</button>`).join('');
      document.body.append(menu);
      const r = e.currentTarget.getBoundingClientRect();
      menu.style.left = `${r.left}px`;
      menu.style.top = `${r.bottom + 4}px`;
      menu.addEventListener('click', (ev) => { const to = ev.target.closest('button')?.dataset.to; if (to) moveTo(id, to); });
    });
  }
  q('[data-controls]').addEventListener('click', () => (popover ? closePopover() : openPopover()));
  document.addEventListener('pointerdown', (e) => {
    if (menu && !menu.contains(e.target)) closeMenu();
    if (popover && !popover.contains(e.target) && !e.target.closest('[data-controls]') && !e.target.closest('.mac-item') && !e.target.closest('.ctx')) closePopover();
  });
  addEventListener('scroll', closePopover, { passive: true });

  // Context menu with the app's accessibility actions.
  root.addEventListener('contextmenu', (e) => {
    const el = e.target.closest('.mac-item');
    if (!el) return;
    e.preventDefault();
    select(el.dataset.id);
    closeMenu();
    const id = el.dataset.id, area = el.parentElement.closest('.mac-row').dataset.area;
    menu = document.createElement('div');
    menu.className = 'ctx';
    menu.innerHTML = `<button type="button" data-step="-1">Move Left</button><button type="button" data-step="1">Move Right</button>`
      + (id === 'blenny' ? '<div class="label">Blenny must remain Visible</div>'
        : Object.entries(AREAS).map(([key, a]) => `<button type="button" data-to="${key}" ${key === area ? 'disabled' : ''}>Move to ${a.title}</button>`).join(''));
    document.body.append(menu);
    menu.style.left = `${Math.min(e.clientX, innerWidth - 220)}px`;
    menu.style.top = `${Math.min(e.clientY, innerHeight - 160)}px`;
    menu.addEventListener('click', (ev) => {
      const b = ev.target.closest('button');
      if (!b) return;
      if (b.dataset.to) moveTo(id, b.dataset.to); else moveWithin(id, +b.dataset.step);
      closeMenu();
    });
  });

  // ------------------------------------------------------------------
  // Dragging: the target row highlights with "Release into …" and a dashed slot, as in the app.
  let press = null;
  root.addEventListener('pointerdown', (e) => {
    const el = e.target.closest('.mac-item');
    if (!el || e.button !== 0) return;
    e.preventDefault();
    press = { el, x: e.clientX, y: e.clientY, dragging: false };
    addEventListener('pointermove', onMove);
    addEventListener('pointerup', onUp, { once: true });
    addEventListener('pointercancel', onUp, { once: true });
  });
  function setTarget(row) {
    Object.entries(rows).forEach(([key, r]) => {
      const on = r === row;
      r.classList.toggle('is-target', on);
      r.querySelector('[data-sub]').innerHTML = on ? `<span class="mac-release">${ICON.down}Release into ${AREAS[key].title}</span>` : AREAS[key].subtitle;
    });
  }
  function onMove(e) {
    if (!press) return;
    if (!press.dragging) {
      if (Math.hypot(e.clientX - press.x, e.clientY - press.y) < 5) return;
      if (press.el.dataset.id === 'blenny') return; // Blenny must remain Visible.
      const r = press.el.getBoundingClientRect();
      press.dragging = true;
      press.ox = press.x - r.left;
      press.oy = press.y - r.top;
      press.ghost = press.el.cloneNode(true);
      press.ghost.classList.add('mac-ghost');
      document.body.append(press.ghost);
      press.el.classList.add('is-placeholder');
      closePopover();
      select(press.el.dataset.id);
    }
    press.ghost.style.transform = `translate(${e.clientX - press.ox}px, ${e.clientY - press.oy}px)`;
    const row = document.elementFromPoint(e.clientX, e.clientY)?.closest('.mac-row');
    if (!row || !root.contains(row)) { setTarget(null); return; }
    setTarget(row);
    const list = row.querySelector('[data-items]');
    let before = null;
    for (const c of list.children) {
      if (c === press.el) continue;
      const r = c.getBoundingClientRect();
      if (e.clientY < r.top || (e.clientY <= r.bottom && e.clientX < r.left + r.width / 2)) { before = c; break; }
    }
    if (press.el.parentElement !== list || press.el.nextElementSibling !== before) flip(() => list.insertBefore(press.el, before));
  }
  function onUp() {
    removeEventListener('pointermove', onMove);
    if (!press) return;
    const { el, dragging, ghost } = press;
    press = null;
    setTarget(null);
    if (!dragging) {
      select(el.dataset.id);
      if (popover) openPopover();
      return;
    }
    const to = el.getBoundingClientRect();
    ghost.animate([{ transform: ghost.style.transform }, { transform: `translate(${to.left}px, ${to.top}px)` }], { duration: 240, easing: 'cubic-bezier(.16,1,.3,1)' })
      .onfinish = () => { ghost.remove(); el.classList.remove('is-placeholder'); splash(el); };
    update();
  }

  update();
}
