// Procedural kelp: curved stipes with alternating, gradient-filled blades.
// Whole strands sway from the base; each blade flutters on its own.

const NS = 'http://www.w3.org/2000/svg';

function bezier(p0, p1, p2, p3, t) {
  const u = 1 - t;
  return [
    u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
    u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1],
  ];
}

// Small deterministic random so the kelp looks the same on every visit.
function random(seed) {
  let s = seed;
  return () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

export function growKelp(host, { strands = 4, seed = 7 } = {}) {
  const rand = random(seed);
  const W = 240, H = 460;
  const svg = document.createElementNS(NS, 'svg');
  svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
  svg.setAttribute('preserveAspectRatio', 'xMidYMax meet');
  svg.innerHTML = `
    <defs>
      <linearGradient id="kelp-blade" x1="0" y1="0" x2="1" y2="0">
        <stop offset="0" stop-color="#24583a"/>
        <stop offset="0.55" stop-color="#4f8f49"/>
        <stop offset="1" stop-color="#a9c96a"/>
      </linearGradient>
      <linearGradient id="kelp-stipe" x1="0" y1="1" x2="0" y2="0">
        <stop offset="0" stop-color="#1c4630"/>
        <stop offset="1" stop-color="#5d9150"/>
      </linearGradient>
    </defs>`;

  for (let s = 0; s < strands; s++) {
    const g = document.createElementNS(NS, 'g');
    g.setAttribute('class', 'strand');
    g.style.animationDuration = `${5 + rand() * 3}s`;
    g.style.animationDelay = `${-rand() * 6}s`;
    const depth = s / (strands - 1);
    g.style.opacity = (0.55 + 0.45 * (1 - depth)).toFixed(2);

    const x0 = 30 + s * ((W - 60) / (strands - 1)) + (rand() - 0.5) * 16;
    const top = 40 + rand() * 110;
    const p0 = [x0, H];
    const p1 = [x0 + (rand() - 0.5) * 70, H * 0.7];
    const p2 = [x0 + (rand() - 0.5) * 90, H * 0.4];
    const p3 = [x0 + (rand() - 0.5) * 60, top];

    const stipe = document.createElementNS(NS, 'path');
    stipe.setAttribute('d', `M${p0} C${p1} ${p2} ${p3}`);
    stipe.setAttribute('fill', 'none');
    stipe.setAttribute('stroke', 'url(#kelp-stipe)');
    stipe.setAttribute('stroke-width', '3.2');
    stipe.setAttribute('stroke-linecap', 'round');
    g.append(stipe);

    let side = rand() < 0.5 ? -1 : 1;
    for (let t = 0.12; t < 0.98; t += 0.07 + rand() * 0.04) {
      const [x, y] = bezier(p0, p1, p2, p3, t);
      const [nx, ny] = bezier(p0, p1, p2, p3, Math.min(1, t + 0.01));
      const along = Math.atan2(ny - y, nx - x) * (180 / Math.PI);
      const angle = along + side * (35 + rand() * 30);
      const L = (46 - t * 22) * (0.8 + rand() * 0.4);
      const Wd = L * (0.2 + rand() * 0.07);
      const wave = (rand() - 0.5) * Wd * 0.8;

      const holder = document.createElementNS(NS, 'g');
      holder.setAttribute('transform', `translate(${x.toFixed(1)} ${y.toFixed(1)}) rotate(${angle.toFixed(1)})`);
      const leaf = document.createElementNS(NS, 'g');
      leaf.setAttribute('class', 'leaf');
      leaf.style.animationDelay = `${-rand() * 4}s`;
      leaf.style.animationDuration = `${2.6 + rand() * 1.8}s`;
      const blade = document.createElementNS(NS, 'path');
      blade.setAttribute('d', `M0 0 C${L * 0.25} ${-Wd} ${L * 0.7} ${-Wd * 0.8 + wave} ${L} ${wave} C${L * 0.7} ${Wd * 0.8 + wave} ${L * 0.25} ${Wd} 0 0Z`);
      blade.setAttribute('fill', 'url(#kelp-blade)');
      const rib = document.createElementNS(NS, 'path');
      rib.setAttribute('d', `M2 0 Q${L * 0.5} ${wave * 0.5} ${L * 0.92} ${wave}`);
      rib.setAttribute('class', 'rib');
      leaf.append(blade, rib);
      holder.append(leaf);
      g.append(holder);
      side = -side;
    }
    svg.append(g);
  }
  host.replaceChildren(svg);
}
