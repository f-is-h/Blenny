// The dive: icons sink out of the crowded menu bar to their area, the depth
// gauge follows the reader, and the fish button runs a bounded reveal session.
// The menu bar mirrors the app: the area Blenny conceals sits left of the arrow
// and the fish, Visible apps sit to their right.

import { glyphs, glyphSVG, appIcon } from './glyphs.js';
import { createSpriteBlenny } from './sprite-blenny.js';
import { sound } from './audio.js';

const MAX_DEPTH = 60;
const REVEAL_MS = 5200;
// Transparent holes in reef-ledge-3200.webp (reef-ledge-10-holes-v2), found with
// tools/scene_assets.py holes: [x0, y0, x1, y1] in image px.
const LEDGE = { w: 3200, h: 1450 };
const LEDGE_HOME = [700, 784, 1192, 1100];
const LEDGE_HOLES = [
  [252, 972, 408, 1112], [484, 652, 656, 812], [1480, 680, 1680, 864], [1792, 860, 1964, 1036],
  [2112, 408, 2284, 520], [2300, 712, 2528, 888], [2400, 988, 2568, 1108], [2792, 848, 2928, 1016],
];
// The smallest hole, high in the middle, is kept for the easter egg.
const LEDGE_EGG = [1316, 444, 1456, 552];

// Position an element over a ledge-image box, grown by a fraction of its size.
function place(el, [x0, y0, x1, y1], grow = 0) {
  const w = x1 - x0, h = y1 - y0;
  el.style.left = `${((x0 - w * grow) / LEDGE.w) * 100}%`;
  el.style.top = `${((y0 - h * grow) / LEDGE.h) * 100}%`;
  el.style.width = `${((w * (1 + 2 * grow)) / LEDGE.w) * 100}%`;
  el.style.height = `${((h * (1 + 2 * grow)) / LEDGE.h) * 100}%`;
  return el;
}
const div = (cls) => Object.assign(document.createElement('div'), { className: cls });

const smooth = (t) => t * t * (3 - 2 * t);

export function createDive({ toast, life, reduceMotion, onSand }) {
  const $ = (s) => document.querySelector(s);
  const tray = $('#tray'), concealed = $('#concealed'), fish = $('#fish'), arrow = $('#revealArrow'), layer = $('#fallers'), ledge = $('#ledge');
  const zones = [...document.querySelectorAll('section[data-zone]')];

  // Crowded menu bar, in the same order as the Organize demo: Deep apps farthest
  // left, Reef apps next to the arrow, Surface apps right of the fish.
  const fallers = [];
  const rank = { deep: 0, reef: 1, surface: 2 };
  [...glyphs].sort((a, b) => rank[a.area] - rank[b.area]).forEach((g) => {
    const slot = document.createElement('div');
    slot.className = 'slot';
    slot.innerHTML = glyphSVG(g) + (g.text ? `<span class="slot-text">${g.text}</span>` : '');
    if (g.w) { slot.classList.add('has-text'); slot.style.setProperty('--w', `${g.w}px`); }
    (g.area === 'surface' ? tray : concealed).append(slot);
    if (g.url) {
      slot.classList.add('is-link');
      slot.title = g.name;
      slot.addEventListener('click', () => window.open(g.url, '_blank', 'noopener'));
    }
    if (g.area === 'surface') return;
    const el = document.createElement('div');
    el.className = `faller is-${g.area}`;
    // The menu bar item sinks; once it settles in its home it shows as the app.
    el.innerHTML = `${glyphSVG(g, 40)}${appIcon(g, 48)}${g.area === 'deep' ? '<span class="breath"><i></i><i></i><i></i></span>' : ''}`;
    layer.append(el);
    fallers.push({ g, el, slot, phase: Math.random() * Math.PI * 2 });
  });
  // The timer item counts down like a real one.
  const timerText = fallers.find((f) => f.g.id === 'timer')?.slot.querySelector('.slot-text');
  if (timerText) {
    let left = 24 * 60 + 58;
    setInterval(() => {
      left = left > 0 ? left - 1 : 25 * 60;
      timerText.textContent = `${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}`;
    }, 1000);
  }
  const reef = fallers.filter((f) => f.g.area === 'reef');
  const deep = fallers.filter((f) => f.g.area === 'deep');

  // The reef ledge, back to front: dark crevice interiors, the home blenny and
  // its shadow, then the rock image (added in HTML) whose rims hide the edges.
  const rock = ledge.querySelector('.ledge-rock');
  reef.forEach((f, i) => { f.crevice = place(div('ledge-back'), LEDGE_HOLES[i], 0.08); ledge.insertBefore(f.crevice, rock); });
  // The easter egg lives in its own crevice: an icon that peeks out now and then.
  const egg = glyphs.find((g) => g.id === 'u4c');
  const eggBack = place(div('ledge-back'), LEDGE_EGG, 0.08);
  const eggPocket = place(div('ledge-egg'), LEDGE_EGG, 0.02);
  const eggJump = place(div('egg-jump'), LEDGE_EGG, 0.02);
  eggPocket.innerHTML = eggJump.innerHTML = `<img src="${egg.img}" alt="" draggable="false">`;
  ledge.insertBefore(eggBack, rock);
  ledge.insertBefore(eggPocket, rock);
  ledge.append(eggJump);
  const cave = place(Object.assign(new Image(), { className: 'ledge-cave', src: 'assets/img/scene/cave.webp', alt: '', loading: 'lazy' }), LEDGE_HOME, 0.06);
  const home = place(div('ledge-pocket'), [LEDGE_HOME[0] - 20, LEDGE_HOME[1] - 420, LEDGE_HOME[2] + 20, LEDGE_HOME[3] + 60]);
  const homeShade = place(div('ledge-shade'), LEDGE_HOME);
  ledge.insertBefore(cave, rock);
  ledge.insertBefore(home, rock);
  ledge.insertBefore(homeShade, rock);
  const reefBlenny = createSpriteBlenny({ sizes: '(max-width: 820px) 40vw, 240px' });
  home.append(reefBlenny.el);

  // The hero blenny at the tide line: ducks from a close pointer, pops out when clicked.
  const perch = $('#perch'), perchPocket = $('#perchPocket');
  const heroBlenny = createSpriteBlenny({ sizes: '(max-width: 820px) 40vw, 260px' });
  perchPocket.append(heroBlenny.el);
  const perchLayers = [['.perch-cave', 14], ['.perch-pocket', 6], ['.perch-shade', 6], ['.perch-rock', 2], ['.perch-light', 2]]
    .map(([sel, k]) => [perch.querySelector(sel), k]);
  function popOut(el, ms = 1500) {
    el.classList.add('is-out');
    clearTimeout(el._out);
    el._out = setTimeout(() => el.classList.remove('is-out'), ms);
  }
  perch.addEventListener('click', () => {
    heroBlenny.excite(1400);
    popOut(perch, 1600);
    const r = perchPocket.getBoundingClientRect();
    life.burst(r.left + r.width / 2, r.top + r.height * 0.45, 12, 60);
  });

  // ------------------------------------------------------------------
  let vh = innerHeight;
  let started = false;
  // Sand art: mound peak at 72.5% across, crest top at 30.4% down (sand-seafloor-v1).
  // The perch rock carries its own sand heap and sits in front of this bank.
  const heroSand = $('#heroSand'), sandImg = heroSand.querySelector('.sand-img'), sandLight = $('#sandLight');
  function fitSand() {
    const pw = perch.offsetWidth, hw = heroSand.offsetWidth;
    if (!pw || !hw) return;
    const cx = perch.offsetLeft + pw / 2;
    const sandH = 0.48 * pw;
    // Stretch horizontally so the mound is wide enough for the rock's flat base, and always cover both edges.
    const sandW = Math.max(2.2 * pw, cx / 0.725, (hw - cx) / 0.275);
    heroSand.style.height = `${sandH}px`;
    const box = { width: `${sandW}px`, height: `${sandH}px`, left: `${cx - 0.725 * sandW}px` };
    Object.assign(sandImg.style, box);
    Object.assign(sandLight.style, box);
    // The bank sits behind the rock, so it may rise as high as it likes behind it. What matters is
    // the rock's two ends: there the mound has dropped by up to about 0.13 x the rock width, and the crest
    // must still reach the top of the rock's own sand heap (30% up the rock image) so the heap's
    // soft edges fade into sand rather than into open water.
    const rockH = pw * 1502 / 2400;
    const bottom = sandH * (1 - 0.304) - 0.13 * pw - 0.3 * rockH;
    perch.style.bottom = `${bottom}px`;
    const heroH = heroSand.parentElement.clientHeight;
    onSand?.(
      { w: sandW, h: sandH, x: cx - 0.725 * sandW, y: heroH - sandH },
      { w: pw, h: rockH, x: perch.offsetLeft, y: heroH - bottom - rockH },
    );
  }

  let growth = 1.2;
  function layout() {
    vh = innerHeight;
    fitSand();
    const sy = scrollY;
    let holeH = Infinity;
    reef.forEach((f) => {
      const r = f.crevice.getBoundingClientRect();
      f.tx = r.left + r.width / 2;
      f.ty = r.top + sy + r.height * 0.56;
      holeH = Math.min(holeH, r.height);
    });
    // Size landed icons to the smallest crevice: the tile is 52 px at scale 1 (x0.4 render scale).
    growth = Math.max(0.1, Math.min(1.6, (holeH * 0.78) / 20.8 - 1));
    const bed = $('#bed').getBoundingClientRect();
    deep.forEach((f, i) => {
      const t = (i + 0.5) / deep.length;
      f.tx = bed.left + bed.width * (0.12 + 0.62 * t);
      f.ty = bed.top + sy + bed.height * (0.35 + (i % 2) * 0.22);
    });
    if (!started) {
      // The menu bar is fixed, so its viewport position is also its position at scroll 0.
      fallers.forEach((f) => {
        const r = f.slot.getBoundingClientRect();
        f.sx = r.left + r.width / 2;
        f.sy = r.top + r.height / 2;
      });
      started = true;
    }
    fallers.forEach((f) => { f.k = (f.ty - f.sy) / Math.max(1, f.ty - vh * 0.56); });
  }

  // Depth is interpolated inside each section's own range.
  function depthAt(sy) {
    const probe = sy + vh * 0.5;
    let m = 0, name = 'SURFACE';
    for (const z of zones) {
      if (probe < z.offsetTop) break;
      const t = Math.min(1, (probe - z.offsetTop) / z.offsetHeight);
      m = +z.dataset.from + (z.dataset.to - z.dataset.from) * t;
      name = z.dataset.zone;
    }
    return { m, name };
  }

  // Gauge.
  const rail = $('#rail'), depthEl = $('#depth'), zoneEl = $('#zone'), bob = $('#bob');
  [0, 10, 20, 30, 40, 50, 60].forEach((m) => {
    const t = document.createElement('span');
    t.className = 'tick';
    t.style.top = `${(m / MAX_DEPTH) * 100}%`;
    t.textContent = m;
    rail.append(t);
  });

  // ------------------------------------------------------------------
  // Reveal session: the concealed area opens left of the arrow and the Reef apps
  // show there, as briskly as in the real menu bar; their icons leave the reef
  // meanwhile. Deep apps stay concealed.
  // Until the reader first scrolls or uses the arrow, the menu bar is the crowded,
  // unmanaged one: everything shows, which reads as expanded. After that Blenny
  // manages it for the rest of the visit.
  let revealTimer = 0, revealing = false, snapTimer = 0, managed = false, sinking = false;
  function setReveal(open) {
    if (open !== revealing) sound.play(open ? 'expand' : 'collapse');
    revealing = open;
    concealed.classList.add('is-snappy');
    clearTimeout(snapTimer);
    snapTimer = setTimeout(() => concealed.classList.remove('is-snappy'), 300);
    fish.classList.toggle('is-active', open);
    setArrow(open);
  }
  function reveal() {
    fish.classList.remove('is-hinting');
    clearTimeout(revealTimer);
    if (!managed && !sinking) {
      // First use at the top: Blenny takes over and collapses the crowd.
      managed = true;
      setReveal(false);
      toast('Blenny tucks the Reef and the Deep away. Click again to expand the Reef.');
      return;
    }
    managed = true;
    const open = !revealing;
    setReveal(open);
    reefBlenny.excite(1400);
    heroBlenny.excite(1400);
    if (!open) return;
    toast('The Reef comes up for a moment. The Deep stays down.');
    reef.forEach((f) => {
      const r = f.el.getBoundingClientRect();
      if (r.bottom > 0 && r.top < innerHeight) life.burst(r.left + r.width / 2, r.top + r.height / 2, 5, 16);
    });
    revealTimer = setTimeout(() => setReveal(false), REVEAL_MS);
  }
  // The app's own arrow: chevron.right.2 while collapsed, chevron.left.2 while expanded.
  function setArrow(open) {
    if (open === arrow._open) return;
    arrow._open = open;
    arrow.classList.toggle('is-open', open);
    const label = open ? 'Collapse Revealable items' : 'Expand Revealable items';
    arrow.setAttribute('aria-label', label);
    arrow.title = label;
  }
  fish.addEventListener('click', reveal);
  arrow.addEventListener('click', reveal);
  $('#tryReveal').addEventListener('click', reveal);

  // ------------------------------------------------------------------
  // Easter egg: a sibling app hides in the highest crevice. It peeks out now
  // and then, ducks when the pointer comes close, and jumps out when clicked.
  // The rock image sits in front of it, so hits are tested against the crevice box.
  let eggCard = null, eggTimer = 0, eggVisible = false, eggBusy = false;
  const eggRect = () => eggBack.getBoundingClientRect();
  const inEgg = (e, pad = 0) => {
    const r = eggRect();
    return e.clientX > r.left - pad && e.clientX < r.right + pad && e.clientY > r.top - pad && e.clientY < r.bottom + pad;
  };
  const eggState = (state) => { eggPocket.dataset.state = state; };
  const later = (fn, ms) => { eggTimer = setTimeout(fn, ms); };
  // A small, endless routine: hide, then either peek and look around or come up and bob.
  function eggRoutine() {
    clearTimeout(eggTimer);
    if (!eggVisible || eggBusy) return;
    eggState('hidden');
    later(() => {
      if (Math.random() < 0.55) {
        eggState('peek');
        later(() => { eggState('peek-left'); later(() => { eggState('peek-right'); later(() => { eggState('peek'); later(eggRoutine, 700); }, 900); }, 900); }, 700);
      } else {
        eggState('up');
        later(() => { eggState('bob'); later(eggRoutine, 2200); }, 600);
      }
    }, 1600 + Math.random() * 3200);
  }
  new IntersectionObserver(([e]) => {
    eggVisible = e.isIntersecting;
    if (reduceMotion) { eggState('up'); return; }
    if (eggVisible) eggRoutine(); else { clearTimeout(eggTimer); eggState('hidden'); }
  }, { threshold: 0.2 }).observe(ledge);

  function closeEgg() {
    if (!eggCard) return;
    const card = eggCard;
    eggCard = null;
    card.classList.remove('is-on');
    setTimeout(() => card.remove(), 400);
  }
  function openEgg() {
    if (eggCard) { closeEgg(); return; }
    const r = eggRect();
    eggCard = document.createElement('a');
    eggCard.className = 'egg-card';
    eggCard.href = egg.url;
    eggCard.target = '_blank';
    eggCard.rel = 'noopener';
    eggCard.innerHTML = `<img src="${egg.img}" alt="" width="44" height="44"><span><small>You found a neighbour</small><b>${egg.name}</b>Tracks your Claude and Codex usage from the menu bar. Made by Blenny's developer.<em>Visit Usage4Claude ↗</em></span>`;
    document.body.append(eggCard);
    const w = eggCard.offsetWidth;
    eggCard.style.left = `${Math.max(12, Math.min(innerWidth - w - 12, r.left + r.width / 2 - w / 2))}px`;
    eggCard.style.top = `${Math.max(44, r.top - eggCard.offsetHeight - 14)}px`;
    requestAnimationFrame(() => eggCard?.classList.add('is-on'));
  }
  // Click: the icon leaps out over the rock with a flip, then drops back in.
  function jumpEgg() {
    if (eggBusy) return;
    eggBusy = true;
    clearTimeout(eggTimer);
    eggState('hidden');
    eggJump.classList.remove('is-jumping');
    void eggJump.offsetWidth;
    eggJump.classList.add('is-jumping');
    const r = eggRect();
    sound.play('hop');
    life.burst(r.left + r.width / 2, r.top + r.height / 2, 16, 34);
    reefBlenny.excite(1400);
    setTimeout(openEgg, reduceMotion ? 0 : 420);
    setTimeout(() => {
      eggJump.classList.remove('is-jumping');
      eggBusy = false;
      eggState('up');
      later(eggRoutine, 2600);
    }, reduceMotion ? 0 : 1250);
  }
  ledge.addEventListener('pointermove', (e) => {
    ledge.style.cursor = inEgg(e) ? 'pointer' : '';
    // Like the blennies, it ducks when the pointer comes too close.
    if (!eggBusy && !reduceMotion && e.pointerType === 'mouse' && inEgg(e, 40) && eggPocket.dataset.state !== 'hidden') {
      clearTimeout(eggTimer);
      eggState('duck');
      later(eggRoutine, 1800);
    }
  });
  ledge.addEventListener('click', (e) => { if (inEgg(e, 6)) { if (eggCard) closeEgg(); else jumpEgg(); } });
  document.addEventListener('pointerdown', (e) => { if (eggCard && !e.target.closest('.egg-card') && !inEgg(e, 6)) closeEgg(); });
  addEventListener('scroll', () => { if (eggCard) closeEgg(); }, { passive: true });

  // Zone changes: the gauge pings like a sonar and the zone name decodes.
  const GLYPHS = '░▒▓<>/\\|=+*~';
  let decode = 0;
  function announce(name) {
    cancelAnimationFrame(decode);
    if (reduceMotion || !lastZone) { zoneEl.textContent = name; return; }
    sound.play('ping');
    const ping = document.createElement('span');
    ping.className = 'ping';
    ping.style.top = bob.style.top;
    rail.append(ping);
    setTimeout(() => ping.remove(), 1400);
    const start = performance.now();
    (function step(now) {
      const k = Math.min(1, (now - start) / 520);
      const shown = Math.floor(name.length * k);
      zoneEl.textContent = name.slice(0, shown) + [...name.slice(shown)].map((c) => (c === ' ' ? ' ' : GLYPHS[(Math.random() * GLYPHS.length) | 0])).join('');
      if (k < 1) decode = requestAnimationFrame(step);
    })(start);
  }

  // ------------------------------------------------------------------
  let depthSmooth = 0, hinted = false, lastZone = '';
  function update(t, pointer, torch) {
    const sy = scrollY;
    const { m, name } = depthAt(sy);
    depthSmooth += (m - depthSmooth) * 0.14;
    if (Math.abs(m - depthSmooth) < 0.01) depthSmooth = m;

    document.body.classList.toggle('is-bright', depthSmooth < 4);
    depthEl.textContent = depthSmooth < 10 ? depthSmooth.toFixed(1) : Math.round(depthSmooth);
    if (name !== lastZone) { announce(name); lastZone = name; }
    bob.style.top = `${(depthSmooth / MAX_DEPTH) * 100}%`;

    const bright = depthSmooth < 4;
    sinking = sy > 8;
    if (sinking) managed = true;
    const crowded = !managed;
    setArrow(crowded || revealing);
    fallers.forEach((f) => {
      const shown = crowded || (revealing && f.g.area === 'reef');
      f.slot.classList.toggle('is-gone', !shown);
      let y = Math.min(f.ty, f.sy + sy * f.k);
      const p = Math.min(1, Math.max(0, (y - f.sy) / (f.ty - f.sy)));
      const e = smooth(p);
      // Icons sit still in the menu bar and only start to drift once the dive begins.
      const sway = reduceMotion ? 0 : (1 - e) * Math.min(1, sy / 160);
      let x = f.sx + (f.tx - f.sx) * e + Math.sin(sy * 0.005 + f.phase + t * 0.6) * 36 * sway;
      let rot = Math.sin(sy * 0.004 + f.phase) * 40 * sway;
      let scale = 1 + Math.min(1, p * 3) * growth;
      const landed = p >= 0.999;
      if (landed && f.g.area === 'deep' && !reduceMotion) y += Math.sin(t * 0.8 + f.phase) * 2;

      // Icons that are in the menu bar are not also in the water.
      f.el.classList.toggle('is-up', (revealing && sinking && f.g.area === 'reef') || (!sinking && managed));
      f.el.classList.toggle('is-housed', landed && f.g.area === 'reef');
      f.el.classList.toggle('is-sleeping', landed && f.g.area === 'deep');
      // Deep apps stay hidden in the dark; only the torch picks them out.
      if (f.g.area === 'deep') {
        const beam = Math.exp(-(((x - torch.x) ** 2 + (y - sy - torch.y) ** 2) / (torch.r * torch.r)));
        const lit = landed ? 1 - torch.k + torch.k * beam : 1;
        const opacity = landed ? (0.12 + 0.88 * lit).toFixed(2) : '';
        if (opacity !== f.opacity) { f.opacity = opacity; f.el.style.opacity = opacity; }
      }
      // Dark glyphs read on bright shallow water; light ones once the water deepens.
      f.el.style.color = bright ? '#0b1d2a' : '#eef9ff';
      // Landing reef icons slip behind the rock (z 3) so the crevice rims overlap them.
      const layer = f.g.area === 'reef' && p > 0.85 ? 2 : -1;
      if (layer !== f.layer) { f.layer = layer; f.el.style.zIndex = layer; }
      f.el.style.transform = `translate3d(${x}px, ${y}px, 0) rotate(${rot}deg) scale(${scale * 0.4})`;
    });

    // Reef blenny: peeks when its reef is on screen, pops out during a reveal.
    const hr = home.getBoundingClientRect();
    const onScreen = hr.top < vh * 0.9 && hr.bottom > 0;
    home.classList.toggle('is-peeking', onScreen);
    if (revealing !== home._revealing) { home._revealing = revealing; home.classList.toggle('is-out', revealing); }
    if (onScreen) {
      if (revealing) reefBlenny.lookAt(hr.left + hr.width / 2, -400);
      else reefBlenny.lookAt(pointer.x, pointer.y);
      if (!hinted && hr.top < vh * 0.6) { hinted = true; fish.classList.add('is-hinting'); }
    }

    // Hero blenny: ducks when the pointer comes too close, like the real thing.
    const pr = perchPocket.getBoundingClientRect();
    if (pr.bottom > 0 && pr.top < vh) {
      const cx = pr.left + pr.width / 2, cy = pr.top + pr.height * 0.7;
      const near = Math.hypot(pointer.x - cx, pointer.y - cy) < pr.width * 0.32 && pointer.active;
      perch.classList.toggle('is-shy', near && !perch.classList.contains('is-out'));
      heroBlenny.lookAt(revealing ? cx : pointer.x, revealing ? -400 : pointer.y);
      // Depth parallax: the cave moves most, the rock least.
      if (pointer.active && !reduceMotion) {
        const nx = pointer.x / innerWidth - 0.5, ny = pointer.y / vh - 0.5;
        perchLayers.forEach(([el, k]) => { el.style.transform = `translate(${-nx * k}px, ${-ny * k * 0.6}px)`; });
      }
    }

    return depthSmooth;
  }

  return { layout, update, reveal, maxDepth: MAX_DEPTH };
}
