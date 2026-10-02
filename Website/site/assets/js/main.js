// Entry point: wires the sea, the dive, ambient life and the demo together
// and runs them from a single animation frame loop.

import { blennyMark, clockText } from './glyphs.js';
import { createSea } from './sea.js';
import { createLife } from './life.js';
import { createDive } from './dive.js';
import { createBoard } from './board.js';
import { initMotion } from './motion.js';
import { createSandCaustics } from './caustics.js';
import { growKelp } from './kelp.js';
import { createBreach } from './breach.js';
import { sound } from './audio.js';
import { resolveDownloads, latestDownload } from './release.js';

resolveDownloads();

// Every module loaded; entrance animations can take over from the CSS failsafe.
document.documentElement.classList.add('motion');

const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
const $ = (s) => document.querySelector(s);

document.querySelectorAll('[data-mark]').forEach((el) => { el.innerHTML = blennyMark(16); });
const clock = $('#clock');
const tickClock = () => { clock.textContent = clockText(); };
tickClock();
setInterval(tickClock, 15000);

// Toast.
const toastEl = $('#toast');
let toastTimer = 0;
function toast(text) {
  toastEl.textContent = text;
  toastEl.classList.add('is-on');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toastEl.classList.remove('is-on'), 3400);
}

// App menu in the menu bar.
const appButton = $('#appButton'), appMenu = $('#appMenu');
function setMenu(open) {
  appMenu.hidden = !open;
  appButton.setAttribute('aria-expanded', String(open));
  if (open) appMenu.querySelector('a')?.focus({ preventScroll: true });
}
appButton.addEventListener('click', () => setMenu(appMenu.hidden));
appMenu.addEventListener('click', (e) => { if (e.target.closest('a')) setMenu(false); });
document.addEventListener('pointerdown', (e) => { if (!appMenu.hidden && !e.target.closest('.appmenu')) setMenu(false); });
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !appMenu.hidden) { setMenu(false); appButton.focus(); }
});

const sea = createSea($('#sea'));
const life = createLife($('#life'));
// Every jellyfish discharge, including the ones passed along a chain, crackles.
life.onZap(({ manta }) => { sound.play('zap'); if (manta) sound.play('flee'); });
const caustics = createSandCaustics($('#sandLight'), { reduceMotion });
const rockCaustics = createSandCaustics($('#perchLight'), { reduceMotion });
const dive = createDive({
  toast, life, reduceMotion,
  onSand: (sand, rock) => {
    caustics.resize(sand.w, sand.h, sand.x, sand.y);
    rockCaustics.resize(rock.w, rock.h, rock.x, rock.y);
  },
});
createBoard($('#board'), { toast, burst: life.burst });
initMotion({ reduceMotion });
growKelp($('#kelp'));
growKelp($('#kelpSmall'), { strands: 3, seed: 19 });

// Pointer state shared by the blennies, the fish schools and the bubbles.
// t: last pointer move; scrollT: last scroll; open: the pointer rests on open water, not on content.
const pointer = { x: -9999, y: -9999, speed: 0, active: false, t: 0, scrollT: 0, open: false };
const CONTENT = 'h1, h2, h3, p, li, a, button, summary, .window, .note, .card, .perch, .ledge, .menubar, .dmg, .gauge, .egg-card';
let lastPointer = { x: 0, y: 0, t: 0 };
addEventListener('pointermove', (e) => {
  const now = performance.now();
  const dt = Math.max(1, now - lastPointer.t) / 1000;
  pointer.speed = Math.hypot(e.clientX - lastPointer.x, e.clientY - lastPointer.y) / dt;
  pointer.x = e.clientX; pointer.y = e.clientY; pointer.active = e.pointerType === 'mouse'; pointer.t = now;
  pointer.open = !e.target.closest?.(CONTENT);
  lastPointer = { x: e.clientX, y: e.clientY, t: now };
}, { passive: true });
document.addEventListener('pointerleave', () => { pointer.active = false; });
addEventListener('pointerdown', (e) => {
  if (e.target.closest('a, button, .window, details, .ctx, .menubar, .egg-card')) return;
  life.burst(e.clientX, e.clientY, 9, 22);
  if (torch.k > 0.2) {
    if (!life.zap(e.clientX, e.clientY)) { life.spark(e.clientX, e.clientY, 26); sound.play('shimmer'); }
  }
  else sound.play('bubble');
});

// Below the reef the light gives out. A torch follows the pointer (or sweeps
// slowly on touch screens); the water, the Deep apps and the plankton answer to it.
const torch = { x: innerWidth * 0.5, y: innerHeight * 0.5, r: 260, k: 0 };
function aimTorch(t, depth) {
  const k = Math.max(0, Math.min(1, (depth - 34) / 6));
  torch.k = k * (1 - Math.max(0, Math.min(1, (depth - 58.5) / 1.5)) * 0.7);
  torch.r = Math.max(170, Math.min(300, innerWidth * 0.22));
  const tx = pointer.active ? pointer.x : innerWidth * (0.5 + 0.32 * Math.sin(t * 0.23)), ty = pointer.active ? pointer.y : innerHeight * (0.55 + 0.22 * Math.sin(t * 0.31 + 1));
  const ease = reduceMotion ? 1 : 0.16;
  torch.x += (tx - torch.x) * ease;
  torch.y += (ty - torch.y) * ease;
}

// Sound: the speaker in the menu bar. It is off until the visitor turns it on;
// once per visitor, after the dive has begun, it suggests itself.
const soundButton = $('#sound'), soundHint = $('#soundHint');
function showSound(on) {
  soundButton.setAttribute('aria-pressed', String(on));
  soundButton.setAttribute('aria-label', on ? 'Sound on. Turn sound off' : 'Sound off. Turn sound on');
}
sound.onChange(showSound);
showSound(sound.on);
function hideHint() {
  if (soundHint.hidden) return;
  soundHint.classList.add('is-leaving');
  setTimeout(() => { soundHint.hidden = true; soundHint.classList.remove('is-leaving'); }, 300);
}
soundButton.addEventListener('click', () => { hideHint(); sound.toggle(); });
soundHint.addEventListener('click', () => { hideHint(); if (!sound.on) sound.toggle(); });
// No hint for anyone who has already chosen, or already seen it.
let hinted = false;
try { hinted = !!(localStorage.getItem('blenny-sound') || localStorage.getItem('blenny-sound-hint')); } catch { /* storage unavailable */ }
function maybeHint() {
  if (hinted || sound.on) return;
  hinted = true;
  try { localStorage.setItem('blenny-sound-hint', '1'); } catch { /* storage unavailable */ }
  soundHint.hidden = false;
  soundButton.classList.add('is-hinting');
  setTimeout(hideHint, 7000);
}
// Suggest it once the reader is clearly diving, not the moment the page opens.
addEventListener('scroll', function onDive() {
  if (scrollY < innerHeight * 0.6) return;
  removeEventListener('scroll', onDive);
  setTimeout(maybeHint, 900);
}, { passive: true });

// Back to the surface: a slow ascent with a trail of bubbles, ending as the
// diver breaks through the surface.
const breach = createBreach();
let ascending = false;
function ascend(duration = Math.min(3200, 1200 + scrollY / 6), bubbles = 0.5) {
  const from = scrollY;
  if (ascending || from < 4) return;
  if (reduceMotion) { scrollTo(0, 0); return; }
  ascending = true;
  let breached = false;
  const start = performance.now();
  const ease = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
  (function step(now) {
    const t = Math.min(1, (now - start) / duration);
    scrollTo(0, from * (1 - ease(t)));
    if (Math.random() < bubbles) life.burst(innerWidth * (0.15 + Math.random() * 0.7), innerHeight + 10, 2, 40);
    if (!breached && t > 0.8) { breached = true; breach.play(); sound.play('splash'); }
    if (t < 1) requestAnimationFrame(step);
    else ascending = false;
  })(start);
}
$('#up').addEventListener('click', () => ascend());

// Download: the bubble pops, the disk image starts downloading, and Blenny
// rockets the visitor up to the surface in one quick breath. Until the latest
// disk image is known the link opens the Releases page instead, in a new tab,
// and the page stays where it is.
const cta = $('.bubble-cta');
const rocket = () => setTimeout(() => ascend(1700, 0.95), 350);
cta.addEventListener('click', () => {
  const r = cta.getBoundingClientRect();
  life.burst(r.left + r.width / 2, r.top + r.height / 2, 34, r.width * 0.8);
  sound.play('pop');
  cta.classList.remove('is-popping');
  void cta.offsetWidth;
  cta.classList.add('is-popping');
  // The pop replaces the bubble's breathing for a moment; give it back after.
  setTimeout(() => cta.classList.remove('is-popping'), 650);
  if (latestDownload.url) rocket();
  else cta.target = '_blank';
});

// Scene art is part of the picture, not something to drag out of it.
document.addEventListener('dragstart', (e) => { if (e.target.closest?.('img, .perch, .ledge')) e.preventDefault(); });

// Parallax for the giant depth numbers.
const marks = [...document.querySelectorAll('.depthmark')].map((el) => ({ el, section: el.parentElement }));

function onResize() {
  sea.resize();
  life.resize();
  dive.layout();
}
addEventListener('resize', onResize);
new ResizeObserver(() => dive.layout()).observe($('#main'));

let last = performance.now(), lastScroll = scrollY, streak = 0;
const gauge = $('.gauge');
function frame(now) {
  const t = now / 1000;
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  pointer.speed *= 0.9;
  // Scroll speed drives particle streaks, startles the fish and blurs the depth readout.
  const v = dt > 0 ? Math.abs(scrollY - lastScroll) / dt : 0;
  if (scrollY !== lastScroll) pointer.scrollT = now;
  lastScroll = scrollY;
  streak += (Math.min(1, Math.max(0, v - 400) / 2600) - streak) * (v > 400 ? 0.2 : 0.06);
  if (reduceMotion) streak = 0;
  const blur = (streak * 2.2).toFixed(1);
  if (blur !== gauge._blur) { gauge._blur = blur; gauge.style.setProperty('--speed-blur', `${blur}px`); }

  const depth = dive.update(t, pointer, torch);
  sound.setDepth(depth / dive.maxDepth);
  aimTorch(t, depth);
  sea.render(reduceMotion ? 0 : t, depth / dive.maxDepth, scrollY, torch, pointer, streak);
  life.render(t, reduceMotion ? 0 : dt, depth, pointer, torch, streak);
  caustics.render(t);
  rockCaustics.render(t);

  const vh = innerHeight;
  marks.forEach(({ el, section }) => {
    const r = section.getBoundingClientRect();
    if (r.bottom < 0 || r.top > vh) return;
    el.style.setProperty('--p', ((vh / 2 - (r.top + r.height / 2)) / vh).toFixed(3));
  });

  requestAnimationFrame(frame);
}

(document.fonts?.ready ?? Promise.resolve()).then(() => {
  dive.layout();
  requestAnimationFrame(frame);
});
