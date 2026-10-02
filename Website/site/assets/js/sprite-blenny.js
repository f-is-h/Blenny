// The rendered Blenny: three pre-aligned frames (base, blink, excited) with
// vector pupils clipped to each tilted eyeball, so the eyes can follow a point.

const BASE = 'assets/img/scene/';
const VIEW = { w: 1677, h: 1145 };
// Measured on the frames: centre, semi-axes and tilt of each eyeball, in frame pixels.
const EYES = [
  { cx: 314, cy: 716, a: 262, b: 184, angle: -57.9 },
  { cx: 1369, cy: 713, a: 220, b: 181, angle: 71.3 },
];
let uid = 0;

const frameSrc = (name) => ({
  src: `${BASE}blenny-${name}-840.webp`,
  srcset: `${BASE}blenny-${name}-840.webp 840w, ${BASE}blenny-${name}-1680.webp 1677w`,
});

export function createSpriteBlenny({ sizes = '(max-width: 820px) 60vw, 420px', base = '' } = {}) {
  const id = `sprite-blenny-${++uid}`;
  const el = document.createElement('div');
  el.className = 'sprite-blenny';
  const frames = {};
  for (const name of ['base', 'blink', 'excited']) {
    const img = new Image();
    const { src, srcset } = frameSrc(name);
    img.src = base + src;
    img.srcset = srcset.replaceAll(BASE, base + BASE);
    img.sizes = sizes;
    img.alt = '';
    img.decoding = 'async';
    img.draggable = false;
    img.className = `frame frame-${name}`;
    frames[name] = img;
    el.append(img);
  }

  // Cave shading painted in code, confined to the character's own pixels.
  const shade = document.createElement('div');
  shade.className = 'shade';
  shade.style.webkitMaskImage = shade.style.maskImage = `url(${base}${BASE}blenny-base-840.webp)`;
  el.append(shade);

  const pupilSize = (e) => ({ rx: e.b * 0.46, ry: e.b * 0.53 });
  el.insertAdjacentHTML('beforeend', `
    <svg class="pupils" viewBox="0 0 ${VIEW.w} ${VIEW.h}" aria-hidden="true">
      <defs>
        <radialGradient id="${id}-pupil" cx="0.42" cy="0.36" r="0.72">
          <stop offset="0" stop-color="#5c2e19"/><stop offset="0.55" stop-color="#3a1b10"/><stop offset="1" stop-color="#1c0b05"/>
        </radialGradient>
        ${EYES.map((e, i) => `<clipPath id="${id}-eye${i}"><ellipse cx="${e.cx}" cy="${e.cy}" rx="${e.a}" ry="${e.b}" transform="rotate(${e.angle} ${e.cx} ${e.cy})"/></clipPath>`).join('')}
      </defs>
      ${EYES.map((e, i) => {
        const { rx, ry } = pupilSize(e);
        return `<g clip-path="url(#${id}-eye${i})"><g class="pupil">
          <ellipse cx="${e.cx}" cy="${e.cy}" rx="${rx}" ry="${ry}" fill="url(#${id}-pupil)"/>
          <ellipse cx="${e.cx - rx * 0.32}" cy="${e.cy - ry * 0.4}" rx="${rx * 0.26}" ry="${ry * 0.24}" fill="#fff" opacity="0.95"/>
          <circle cx="${e.cx + rx * 0.3}" cy="${e.cy + ry * 0.34}" r="${rx * 0.09}" fill="#fff" opacity="0.6"/>
        </g></g>`;
      }).join('')}
    </svg>`);
  const pupils = [...el.querySelectorAll('.pupil')];

  let state = 'base';
  function show(name) {
    state = name;
    for (const [n, img] of Object.entries(frames)) img.style.visibility = n === name ? 'visible' : 'hidden';
    el.classList.toggle('is-blinking', name === 'blink');
    el.classList.toggle('is-excited', name === 'excited');
  }
  show('base');

  // Keep each pupil inside its eyeball: the reachable region is the eye ellipse
  // shrunk by the pupil size, in the eye's own rotated frame.
  function lookAt(x, y) {
    const r = el.getBoundingClientRect();
    if (!r.width || r.bottom < -200 || r.top > innerHeight + 200) return;
    const s = r.width / VIEW.w;
    EYES.forEach((e, i) => {
      const dx = x - (r.left + e.cx * s), dy = y - (r.top + e.cy * s);
      const d = Math.hypot(dx, dy) || 1;
      const ux = dx / d, uy = dy / d;
      const t = (e.angle * Math.PI) / 180;
      const lx = ux * Math.cos(t) + uy * Math.sin(t);
      const ly = -ux * Math.sin(t) + uy * Math.cos(t);
      const { rx, ry } = pupilSize(e);
      const a = e.a - Math.max(rx, ry) * 1.02, b = e.b - Math.max(rx, ry) * 1.02;
      const limit = 1 / Math.sqrt((lx / a) ** 2 + (ly / b) ** 2);
      const k = Math.min(1, d / (320 * s + 120));
      pupils[i].style.transform = `translate(${ux * limit * k}px, ${uy * limit * k}px)`;
    });
  }

  function blink() {
    if (state !== 'base') return;
    show('blink');
    setTimeout(() => { if (state === 'blink') show('base'); }, 140);
  }
  let exciteTimer = 0;
  function excite(ms = 900) {
    show('excited');
    clearTimeout(exciteTimer);
    exciteTimer = setTimeout(() => show('base'), ms);
  }
  (function schedule() {
    setTimeout(() => {
      blink();
      if (Math.random() < 0.25) setTimeout(blink, 260);
      schedule();
    }, 1800 + Math.random() * 3600);
  })();

  // Pupils stay hidden until the frames are decoded, so they never float in an empty hole.
  Promise.all(Object.values(frames).map((img) => img.decode().catch(() => {})))
    .then(() => el.classList.add('is-ready'));
  return { el, lookAt, blink, excite };
}
