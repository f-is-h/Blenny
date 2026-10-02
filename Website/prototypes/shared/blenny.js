// Animated Blenny character shared by the website prototypes.
// Usage: const fish = Blenny.create(); container.append(fish.el); fish.lookAt(x, y);
(function () {
  let uid = 0;

  const style = document.createElement('style');
  style.textContent = `
    .blenny-character { position: relative; width: 100%; line-height: 0; }
    .blenny-character svg { width: 100%; height: auto; overflow: visible; }
    .blenny-character .eye { transform-box: fill-box; transform-origin: 50% 50%; transition: transform 90ms ease-in; }
    .blenny-character.is-blinking .eye { transform: scaleY(0.08); }
    .blenny-character .pupil { transition: transform 140ms ease-out; }
    .blenny-character .cirrus { transform-box: fill-box; transform-origin: 50% 100%; animation: blenny-cirrus 2.6s ease-in-out infinite; }
    .blenny-character .cirrus-r { animation-delay: -1.3s; }
    .blenny-character.is-excited .cirrus { animation-duration: 0.45s; }
    .blenny-character .mouth { transform-box: fill-box; transform-origin: 50% 50%; transition: transform 160ms ease; }
    .blenny-character.is-excited .mouth { transform: scale(1.7, 2.2); }
    @keyframes blenny-cirrus { 0%, 100% { transform: rotate(-7deg); } 50% { transform: rotate(7deg); } }
  `;
  document.head.append(style);

  const EYES = [
    { cx: 60, cy: 94 },
    { cx: 140, cy: 94 },
  ];
  const VIEW = { w: 200, h: 150 };

  function markup(id) {
    return `
<svg viewBox="0 0 ${VIEW.w} ${VIEW.h}" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
  <defs>
    <radialGradient id="${id}-body" cx="40%" cy="28%" r="80%">
      <stop offset="0" stop-color="#FFC66B"/>
      <stop offset="0.5" stop-color="#FF8B35"/>
      <stop offset="1" stop-color="#E4492A"/>
    </radialGradient>
    <radialGradient id="${id}-blush">
      <stop offset="0" stop-color="#FF4F6A" stop-opacity="0.5"/>
      <stop offset="1" stop-color="#FF4F6A" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <g fill="none" stroke="#FF9A3F" stroke-width="8" stroke-linecap="round" stroke-linejoin="round">
    <g class="cirrus cirrus-l"><path d="M68 52 L64 12 M65 26 L51 14 M65 26 L78 13"/></g>
    <g class="cirrus cirrus-r"><path d="M132 52 L136 12 M135 26 L149 14 M135 26 L122 13"/></g>
  </g>
  <path d="M10 150 C10 72 50 36 100 36 C150 36 190 72 190 150 Z" fill="url(#${id}-body)"/>
  <g fill="#3CCBF2">
    <ellipse cx="96" cy="56" rx="10" ry="6.5" transform="rotate(-12 96 56)"/>
    <ellipse cx="121" cy="50" rx="8" ry="5.5"/>
    <ellipse cx="120" cy="68" rx="7" ry="5.5" transform="rotate(18 120 68)"/>
    <ellipse cx="80" cy="72" rx="5.5" ry="7" transform="rotate(20 80 72)"/>
  </g>
  <ellipse cx="42" cy="124" rx="20" ry="11" fill="url(#${id}-blush)"/>
  <ellipse cx="158" cy="124" rx="20" ry="11" fill="url(#${id}-blush)"/>
  ${EYES.map((e, i) => `
  <g class="eye">
    <ellipse cx="${e.cx}" cy="${e.cy}" rx="26" ry="28" fill="#FFFCF4"/>
    <g class="pupil" data-eye="${i}">
      <ellipse cx="${e.cx}" cy="${e.cy}" rx="12.5" ry="14.5" fill="#3A1C11"/>
      <circle class="glint" cx="${e.cx + 4}" cy="${e.cy - 6}" r="4.2" fill="#fff"/>
    </g>
  </g>`).join('')}
  <ellipse cx="88" cy="114" rx="5" ry="3" fill="#E55A2A"/>
  <ellipse cx="112" cy="114" rx="5" ry="3" fill="#E55A2A"/>
  <ellipse class="mouth" cx="100" cy="130" rx="6" ry="2.6" fill="#5A170E"/>
</svg>`;
  }

  function create(options = {}) {
    const id = `blenny-${++uid}`;
    const el = document.createElement('div');
    el.className = 'blenny-character';
    el.innerHTML = markup(id);
    const svg = el.querySelector('svg');
    const pupils = [...el.querySelectorAll('.pupil')];
    const reach = options.reach ?? 10;

    function lookAt(clientX, clientY) {
      const r = svg.getBoundingClientRect();
      if (!r.width) return;
      const scale = r.width / VIEW.w;
      EYES.forEach((eye, i) => {
        const ex = r.left + eye.cx * scale;
        const ey = r.top + eye.cy * scale;
        const dx = clientX - ex;
        const dy = clientY - ey;
        const d = Math.hypot(dx, dy) || 1;
        const k = Math.min(1, d / 260) * reach;
        pupils[i].style.transform = `translate(${(dx / d) * k}px, ${(dy / d) * k * 0.9}px)`;
      });
    }

    function blink() {
      el.classList.add('is-blinking');
      setTimeout(() => el.classList.remove('is-blinking'), 130);
    }

    function excite(ms = 900) {
      el.classList.add('is-excited');
      clearTimeout(el._exciteTimer);
      el._exciteTimer = setTimeout(() => el.classList.remove('is-excited'), ms);
    }

    (function scheduleBlink() {
      setTimeout(() => {
        blink();
        if (Math.random() < 0.25) setTimeout(blink, 220);
        scheduleBlink();
      }, 1800 + Math.random() * 3600);
    })();

    return { el, lookAt, blink, excite };
  }

  window.Blenny = { create };
})();
