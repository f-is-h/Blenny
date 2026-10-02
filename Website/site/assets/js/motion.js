// Entrance animations, magnetic buttons, card spotlights and rippling headlines.

// Wrap each word of a headline (including words inside <em>) for a staggered rise.
function splitWords(el) {
  let i = 0;
  const walk = (node) => {
    [...node.childNodes].forEach((child) => {
      if (child.nodeType === Node.TEXT_NODE) {
        const frag = document.createDocumentFragment();
        child.textContent.split(/(\s+)/).forEach((part) => {
          if (!part) return;
          if (/^\s+$/.test(part)) { frag.append(' '); return; }
          const w = document.createElement('span');
          w.className = 'w';
          const inner = document.createElement('span');
          inner.textContent = part;
          inner.style.setProperty('--i', i++);
          w.append(inner);
          frag.append(w);
        });
        child.replaceWith(frag);
      } else if (child.nodeType === Node.ELEMENT_NODE) {
        walk(child);
      }
    });
  };
  el.setAttribute('aria-label', el.textContent.replace(/\s+/g, ' ').trim());
  walk(el);
  el.querySelectorAll('.w').forEach((w) => w.setAttribute('aria-hidden', 'true'));
}

export function initMotion({ reduceMotion }) {
  document.querySelectorAll('.split').forEach(splitWords);

  // Stagger sibling reveals inside the same container.
  document.querySelectorAll('.cards, .limits, .faq, .steps').forEach((group) => {
    [...group.children].forEach((c, i) => c.style.setProperty('--d', `${i * 80}ms`));
  });

  const io = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (!e.isIntersecting) return;
      e.target.classList.add('in');
      io.unobserve(e.target);
    });
  }, { rootMargin: '0px 0px -12% 0px', threshold: 0.12 });
  document.querySelectorAll('.split, .reveal').forEach((el) => io.observe(el));

  if (reduceMotion || matchMedia('(hover: none)').matches) return;

  // Buttons lean toward the pointer.
  document.querySelectorAll('.magnetic').forEach((el) => {
    el.addEventListener('pointermove', (e) => {
      const r = el.getBoundingClientRect();
      const x = (e.clientX - r.left - r.width / 2) / r.width;
      const y = (e.clientY - r.top - r.height / 2) / r.height;
      el.style.transform = `translate(${x * 14}px, ${y * 12}px)`;
    });
    el.addEventListener('pointerleave', () => {
      el.animate([{ transform: el.style.transform || 'none' }, { transform: 'none' }], { duration: 500, easing: 'cubic-bezier(.34,1.56,.64,1)' });
      el.style.transform = '';
    });
  });

  waterHeadlines();

  // A soft light follows the pointer across safety cards.
  document.querySelectorAll('.card').forEach((card) => {
    card.addEventListener('pointermove', (e) => {
      const r = card.getBoundingClientRect();
      card.style.setProperty('--mx', `${e.clientX - r.left}px`);
      card.style.setProperty('--my', `${e.clientY - r.top}px`);
    });
  });
}

// Headlines waver as if seen through moving water while the pointer is on them:
// a gentle swell while it rests, stronger the faster it sweeps. One shared SVG
// displacement filter is applied only to the headline being touched, and only
// until the ripple settles. Its noise drifts back and forth, so the text flows
// rather than shimmers; the filter region is wide enough that the drift never
// uncovers an edge.
function waterHeadlines() {
  document.body.insertAdjacentHTML('beforeend', `<svg class="fx-defs" width="0" height="0" aria-hidden="true">
    <filter id="water-ripple" x="-20%" y="-30%" width="140%" height="160%" color-interpolation-filters="sRGB">
      <feTurbulence type="fractalNoise" baseFrequency="0.0055 0.024" numOctaves="1" seed="4" result="noise"/>
      <feOffset in="noise" dx="0" dy="0" result="flow"/>
      <feDisplacementMap in="SourceGraphic" in2="flow" scale="0" xChannelSelector="R" yChannelSelector="G"/>
    </filter></svg>`);
  const flow = document.querySelector('#water-ripple feOffset');
  const disp = document.querySelector('#water-ripple feDisplacementMap');
  let active = null, hovering = false, energy = 0, raf = 0, last = null;
  function tick(now) {
    const t = now / 1000;
    const floor = hovering ? 9 : 0;
    energy += (Math.max(floor, energy * 0.93) - energy) * 0.25;
    flow.setAttribute('dx', (Math.sin(t * 1.3) * 60).toFixed(1));
    flow.setAttribute('dy', (Math.sin(t * 1.9 + 1) * 18).toFixed(1));
    disp.setAttribute('scale', energy.toFixed(2));
    if (!hovering && energy < 0.3) {
      if (active) active.style.filter = '';
      active = null; raf = 0;
      return;
    }
    raf = requestAnimationFrame(tick);
  }
  document.querySelectorAll('h1, h2').forEach((h) => {
    h.addEventListener('pointerenter', () => {
      hovering = true;
      energy = Math.max(energy, 14);
      if (active !== h) {
        if (active) active.style.filter = '';
        active = h;
        h.style.filter = 'url(#water-ripple)';
      }
      if (!raf) raf = requestAnimationFrame(tick);
    });
    h.addEventListener('pointermove', (e) => {
      if (last) energy = Math.min(30, energy + Math.hypot(e.clientX - last.x, e.clientY - last.y) * 0.3);
      last = { x: e.clientX, y: e.clientY };
    });
    h.addEventListener('pointerleave', () => { hovering = false; last = null; });
  });
}
