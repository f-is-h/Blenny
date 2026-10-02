// Ambient life on a 2D canvas: schools of small fish in the shallows, a manta
// passing through the deep, bioluminescent plankton and jellyfish in the dark,
// and bubbles from clicks and fast pointer moves.

import { BLENNY_BODY } from './glyphs.js';


// A soft glow dot, rendered once and stamped with additive blending.
function glowSprite(rgb) {
  const c = document.createElement('canvas');
  c.width = c.height = 64;
  const g = c.getContext('2d');
  const grad = g.createRadialGradient(32, 32, 0, 32, 32, 32);
  grad.addColorStop(0, `rgba(${rgb}, 1)`);
  grad.addColorStop(0.18, `rgba(${rgb}, 0.7)`);
  grad.addColorStop(0.45, `rgba(${rgb}, 0.16)`);
  grad.addColorStop(1, `rgba(${rgb}, 0)`);
  g.fillStyle = grad;
  g.fillRect(0, 0, 64, 64);
  return c;
}
// Places for the school to take when it draws the Blenny menu bar mark: [x, y,
// heading]. Fish swim in a ring around the body outline and around each eye,
// and stand head-up along the three prongs of each feeler, so the shape reads
// as lines of fish rather than a cloud. Coordinates are in mark units (the
// template's 21-unit view box), scaled to `size` px and centred.
const FEELERS = [
  [[7.5, 7], [7.15, 3.25], [0.2, 0.52, 0.86]], [[7.25, 4.85], [5.45, 3.5], [0.5, 0.95]], [[7.25, 4.85], [8.8, 3.3], [0.5, 0.95]],
  [[16.5, 7], [16.85, 3.25], [0.2, 0.52, 0.86]], [[16.75, 4.85], [18.55, 3.5], [0.5, 0.95]], [[16.75, 4.85], [15.2, 3.3], [0.5, 0.95]],
];
const LOOPS = [[6.15, 11.15, 3.6], [17.85, 11.15, 3.6]]; // eye centres and reach; anything else circles the body
const markCache = new Map();
function markPoints(count, size) {
  const key = `${count}x${size}`;
  if (markCache.has(key)) return markCache.get(key);
  // The mark's view box starts at (1.5, -0.1) and is 21 units square.
  const k = size / 21, vx = 1.5, vy = -0.1;
  const toPx = (x, y) => [(x - vx) * k - size / 2, (y - vy) * k - size / 2];

  // Feelers: fixed places along each prong, heading outward from the base.
  const out = [];
  for (const [[x0, y0], [x1, y1], ts] of FEELERS) {
    const ang = Math.atan2((y1 - y0), (x1 - x0));
    for (const t of ts) {
      const [px, py] = toPx(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t);
      out.push([px, py, ang]);
    }
  }

  // Body: the outline of the body and both eye holes, rasterised once.
  const c = document.createElement('canvas');
  c.width = c.height = size;
  const g = c.getContext('2d', { willReadFrequently: true });
  g.setTransform(k, 0, 0, k, -vx * k, -vy * k);
  g.fill(new Path2D(BLENNY_BODY), 'evenodd');
  const data = g.getImageData(0, 0, size, size).data;
  const inside = (x, y) => x >= 0 && y >= 0 && x < size && y < size && data[(y * size + x) * 4 + 3] > 128;
  const cand = [];
  for (let y = 0; y < size; y += 2) for (let x = 0; x < size; x += 2) {
    if (inside(x, y) && (!inside(x - 3, y) || !inside(x + 3, y) || !inside(x, y - 3) || !inside(x, y + 3))) cand.push([x, y]);
  }
  // Greedy spacing: shrink the minimum distance until one full pass yields enough
  // points, then drop the most crowded ones so the outline stays evenly covered.
  const want = Math.max(0, count - out.length);
  const order = cand.map((p, i) => [p, (i * 7919) % cand.length]).sort((a, b) => a[1] - b[1]).map((e) => e[0]);
  let pts = [];
  for (let d = size / 6; d > 2 && pts.length < want; d *= 0.94) {
    pts = [];
    for (const p of order) if (pts.every((q) => (q[0] - p[0]) ** 2 + (q[1] - p[1]) ** 2 >= d * d)) pts.push(p);
  }
  while (pts.length > want) {
    let worst = 0, best = Infinity;
    pts.forEach((p, i) => {
      let near = Infinity;
      pts.forEach((q, j) => { if (i !== j) near = Math.min(near, (q[0] - p[0]) ** 2 + (q[1] - p[1]) ** 2); });
      if (near < best) { best = near; worst = i; }
    });
    pts.splice(worst, 1);
  }
  // Heading: along the outline (the main axis of nearby filled pixels), turned
  // so every ring is swum the same way round.
  const R = Math.round(size / 40);
  for (const [x, y] of pts) {
    let n = 0, mx = 0, my = 0, sxx = 0, syy = 0, sxy = 0;
    for (let v = -R; v <= R; v++) for (let u = -R; u <= R; u++) {
      if (u * u + v * v > R * R || !inside(x + u, y + v)) continue;
      n++; mx += u; my += v; sxx += u * u; syy += v * v; sxy += u * v;
    }
    mx /= n || 1; my /= n || 1;
    let ang = 0.5 * Math.atan2(2 * (sxy / (n || 1) - mx * my), sxx / (n || 1) - mx * mx - (syy / (n || 1) - my * my));
    const ux = x / k + vx, uy = y / k + vy; // back to mark units
    const loop = LOOPS.find(([cx, cy, r]) => (ux - cx) ** 2 + (uy - cy) ** 2 < r * r) || [12, 12.3];
    const rx = ux - loop[0], ry = uy - loop[1];
    if (Math.cos(ang) * -ry + Math.sin(ang) * rx < 0) ang += Math.PI;
    out.push([x - size / 2, y - size / 2, ang]);
  }
  markCache.set(key, out);
  return out;
}

const GLOWS = [glowSprite('120, 255, 236'), glowSprite('110, 200, 255'), glowSprite('190, 160, 255')];

export function createLife(canvas) {
  const ctx = canvas.getContext('2d');
  let W = 0, H = 0, dpr = 1;
  let fish = [];
  const bubbles = [];
  const manta = { x: -400, y: 0, vy: 0, active: false, next: 0, flap: 0, seed: 0 };
  const plankton = [];
  let jellies = [];
  // The school forms the Blenny mark around a resting pointer and scatters when it moves.
  const form = { on: false, cx: 0, cy: 0, pts: [], next: 0 };

  function resize() {
    dpr = Math.min(devicePixelRatio || 1, 2);
    W = innerWidth; H = innerHeight;
    canvas.width = W * dpr; canvas.height = H * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    jellies = Array.from({ length: W < 700 ? 2 : 4 }, (_, i) => makeJelly(
      W * (0.12 + 0.78 * ((i * 0.618 + 0.2) % 1)), H * (0.25 + 0.6 * ((i * 0.37 + 0.3) % 1)),
      (W < 700 ? 22 : 30) * (0.7 + ((i * 0.53) % 1) * 0.6), i,
    ));
    fish = [];
    const schools = W < 700 ? 2 : 3;
    for (let s = 0; s < schools; s++) {
      const dir = s % 2 ? -1 : 1;
      const speed = 34 + s * 12;
      const cy = H * (0.25 + s * 0.22);
      const cx = Math.random() * W;
      for (let i = 0; i < 22 + s * 5; i++) {
        fish.push({
          s, dir, speed, cy,
          x: cx + (Math.random() - 0.5) * 160, y: cy + (Math.random() - 0.5) * 70,
          vx: dir * speed, vy: 0, ph: Math.random() * 6, size: 0.7 + Math.random() * 0.55, ang: dir > 0 ? 0 : Math.PI,
        });
      }
    }
    form.on = false;
    form.pts = markPoints(fish.length, W < 700 ? 240 : 360);
  }

  function gather(pointer) {
    const half = (W < 700 ? 240 : 360) / 2 + 10;
    form.on = true;
    // Keep clear of the depth gauge on the right.
    form.cx = Math.max(half, Math.min(W - half - (W > 820 ? 230 : 0), pointer.x));
    form.cy = Math.max(half + 40, Math.min(H - half, pointer.y));
    // Pair fish with points left to right, so the school folds in without crossing much.
    const byX = [...fish].sort((a, b) => a.x - b.x);
    const pts = [...form.pts].sort((a, b) => a[0] - b[0]);
    byX.forEach((f, i) => { f.target = pts[i % pts.length]; });
  }
  function scatter() {
    form.on = false;
    fish.forEach((f) => {
      const dx = f.x - form.cx, dy = f.y - form.cy, d = Math.hypot(dx, dy) || 1;
      const kick = 260 + Math.random() * 220;
      f.vx += (dx / d) * kick; f.vy += (dy / d) * kick;
    });
  }

  function burst(x, y, n = 10, spread = 26) {
    for (let i = 0; i < n; i++) {
      bubbles.push({
        x: x + (Math.random() - 0.5) * spread, y: y + (Math.random() - 0.5) * spread * 0.4,
        r: 1.5 + Math.random() * 4.5, vy: -(50 + Math.random() * 90), ph: Math.random() * 6, life: 1,
      });
    }
  }

  // Bioluminescent sparks: they flare where the water is disturbed and fade.
  function spark(x, y, n = 12, spread = 30) {
    for (let i = 0; i < n && plankton.length < 420; i++) {
      const a = Math.random() * Math.PI * 2, v = 10 + Math.random() * 60;
      plankton.push({
        x: x + (Math.random() - 0.5) * spread, y: y + (Math.random() - 0.5) * spread,
        vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: 1, decay: 0.35 + Math.random() * 0.45,
        size: 5 + Math.random() * 11, glow: GLOWS[Math.random() < 0.8 ? 0 : 1], ph: Math.random() * 6,
      });
    }
  }

  // Jellyfish swim by jet propulsion: the bell snaps narrow and tall, the jelly
  // surges along its axis, then the bell slowly relaxes wide and flat while it
  // coasts and sinks a little. Tentacles and oral arms are simple verlet chains
  // hung from the rim and the centre, so they are dragged by the body, bunch up
  // and stream behind on each stroke, and drift apart while it coasts.
  function makeJelly(x, y, size, i) {
    const j = {
      x, y, vx: 0, vy: 0, ang: 0, size, cyc: (i * 0.37) % 1, rate: 0.5 + ((i * 0.29) % 1) * 0.16,
      ph: i * 1.7, hue: i % 2 ? 2 : 1,
      // Thin marginal tentacles, each its own length (some broken short, a few
      // trailing far), and a few short, frilly oral arms in the middle.
      tentacles: Array.from({ length: 9 }, (_, k) => ({
        x: (k / 8 - 0.5) * 1.8 + (Math.random() - 0.5) * 0.12,
        len: size * (0.9 + Math.random() * 2.2 + (Math.random() < 0.25 ? 1.6 : 0)),
        ph: Math.random() * 6, w: 0.7 + Math.random() * 0.6, n: 12,
      })),
      arms: Array.from({ length: 3 }, (_, k) => ({ x: (k - 1) * 0.18, len: size * (1.1 + Math.random() * 0.5), ph: Math.random() * 6, n: 7 })),
    };
    [...j.tentacles, ...j.arms].forEach((c) => hang(j, c));
    return j;
  }
  // Lay a chain straight down from its anchor.
  function hang(j, c) {
    c.seg = c.len / (c.n - 1);
    c.pts = Array.from({ length: c.n }, (_, q) => {
      const x = j.x + c.x * j.size, y = j.y + q * c.seg;
      return { x, y, px: x, py: y };
    });
  }
  function stepChain(c, ax, ay, dt, t, k) {
    const p0 = c.pts[0];
    p0.x = p0.px = ax; p0.y = p0.py = ay;
    const g = 22 * dt * dt;
    for (let q = 1; q < c.n; q++) {
      const p = c.pts[q];
      // Water is thick: most of the velocity is lost each frame. A faint, slow
      // current keeps the strands alive while the jelly coasts.
      const vx = (p.x - p.px) * 0.9, vy = (p.y - p.py) * 0.9;
      p.px = p.x; p.py = p.y;
      p.x += vx + Math.sin(t * 0.9 + c.ph + q * 0.55 + k) * 9 * dt * dt * q;
      p.y += vy + g;
    }
    for (let it = 0; it < 3; it++) {
      for (let q = 1; q < c.n; q++) {
        const a = c.pts[q - 1], p = c.pts[q];
        const dx = p.x - a.x, dy = p.y - a.y, d = Math.hypot(dx, dy) || 1;
        const diff = (d - c.seg) / d;
        if (q === 1) { p.x -= dx * diff; p.y -= dy * diff; }
        else { a.x += dx * diff * 0.5; a.y += dy * diff * 0.5; p.x -= dx * diff * 0.5; p.y -= dy * diff * 0.5; }
      }
    }
  }

  // A jagged arc: midpoint displacement, a soft cyan halo under a white core,
  // with now and then a short fork.
  function bolt(x0, y0, x1, y1, k) {
    let pts = [[x0, y0], [x1, y1]];
    let rough = Math.hypot(x1 - x0, y1 - y0) * 0.28;
    for (let d = 0; d < 4; d++, rough *= 0.55) {
      const next = [pts[0]];
      for (let i = 1; i < pts.length; i++) {
        const [ax, ay] = pts[i - 1], [bx, by] = pts[i];
        const nx = -(by - ay), ny = bx - ax, n = Math.hypot(nx, ny) || 1, off = (Math.random() - 0.5) * rough;
        next.push([(ax + bx) / 2 + (nx / n) * off, (ay + by) / 2 + (ny / n) * off], pts[i]);
      }
      pts = next;
    }
    const path = () => { ctx.beginPath(); pts.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y))); };
    ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    path(); ctx.strokeStyle = `rgba(110, 230, 255, ${(0.35 * k).toFixed(3)})`; ctx.lineWidth = 4; ctx.stroke();
    path(); ctx.strokeStyle = `rgba(245, 255, 255, ${(0.9 * k).toFixed(3)})`; ctx.lineWidth = 1.2; ctx.stroke();
    if (Math.random() < 0.5) {
      const [mx, my] = pts[Math.floor(pts.length * (0.3 + Math.random() * 0.4))];
      const a = Math.atan2(y1 - y0, x1 - x0) + (Math.random() < 0.5 ? -0.7 : 0.7), L = Math.hypot(x1 - x0, y1 - y0) * 0.35;
      ctx.beginPath(); ctx.moveTo(mx, my); ctx.lineTo(mx + Math.cos(a) * L * 0.5 + (Math.random() - 0.5) * 6, my + Math.sin(a) * L * 0.5 + (Math.random() - 0.5) * 6); ctx.lineTo(mx + Math.cos(a) * L, my + Math.sin(a) * L);
      ctx.strokeStyle = `rgba(200, 250, 255, ${(0.6 * k).toFixed(3)})`; ctx.lineWidth = 0.9; ctx.stroke();
    }
  }

  // Click a jelly in the dark and it discharges; it also flinches into a stroke.
  const ZAP = 0.75;
  function zap(x, y) {
    let hit = null, best = Infinity;
    for (const j of jellies) {
      const d = Math.hypot(x - j.x, y - (j.y - j.size * 0.4));
      if (d < j.size * 2.2 && d < best) { best = d; hit = j; }
    }
    if (!hit) return false;
    hit.zap = ZAP;
    hit.cyc = 0;
    spark(x, y, 34, 50);
    return true;
  }

  function drawJelly(j, t, dt, alpha, torch) {
    const s = j.size;
    // Swim cycle: a quick contraction (first 28%), then a slow relaxation that
    // overshoots a little wider than rest before settling.
    if (dt > 0) j.cyc = (j.cyc + dt * j.rate) % 1;
    const c = j.cyc;
    const squeeze = c < 0.28 ? Math.sin((c / 0.28) * Math.PI * 0.5) : Math.pow(1 - (c - 0.28) / 0.72, 2.2);
    const flare = c > 0.28 ? Math.sin(((c - 0.28) / 0.72) * Math.PI) * 0.06 : 0;
    const w = s * (1 - 0.3 * squeeze + flare), h = s * (0.7 + 0.32 * squeeze - flare);

    if (dt > 0) {
      // Thrust along the bell's axis only while it contracts; drag and a slight sink otherwise.
      const thrust = c < 0.28 ? Math.sin((c / 0.28) * Math.PI) * 190 * (s / 30) : 0;
      j.ang += (Math.sin(t * 0.11 + j.ph) * 0.4 - j.ang) * dt * 0.4;
      j.vx += Math.sin(j.ang) * thrust * dt;
      j.vy += (-Math.cos(j.ang) * thrust + 7) * dt;
      const drag = Math.exp(-dt * 1.7);
      j.vx *= drag; j.vy *= drag;
      j.x += j.vx * dt; j.y += j.vy * dt;
    }
    const cos = Math.cos(j.ang), sin = Math.sin(j.ang);
    const world = (lx, ly) => [j.x + lx * cos - ly * sin, j.y + lx * sin + ly * cos];
    if (dt > 0) {
      j.tentacles.forEach((tn, k) => { const [ax, ay] = world(tn.x * w * 0.95, 0); stepChain(tn, ax, ay, dt, t, k); });
      j.arms.forEach((arm, k) => { const [ax, ay] = world(arm.x * w, -h * 0.08); stepChain(arm, ax, ay, dt, t, k + 3); });
    }

    const lit = 0.55 + 0.45 * Math.exp(-((j.x - torch.x) ** 2 + (j.y - torch.y) ** 2) / (torch.r * torch.r * 2));
    ctx.globalAlpha = alpha * lit;
    const [gx, gy] = world(0, -h * 0.4);
    ctx.drawImage(GLOWS[j.hue], gx - s * 2.2, gy - s * 2.2, s * 4.4, s * 4.4);

    // Easter egg: a clicked jelly discharges. Its glow flares and flickering arcs
    // leap from its tentacle tips and bell for a moment.
    const zk = j.zap > 0 ? j.zap / ZAP : 0;
    if (j.zap > 0 && dt > 0) j.zap = Math.max(0, j.zap - dt);
    if (zk > 0 && Math.random() < 0.8) {
      ctx.globalAlpha = Math.min(1, zk * 1.3);
      ctx.drawImage(GLOWS[0], gx - s * 4, gy - s * 4, s * 8, s * 8);
      const from = j.tentacles.filter((_, i) => i % 2 === 0).map((tn) => tn.pts[tn.n - 1]).concat([{ x: gx, y: gy }]);
      for (const p of from) {
        if (Math.random() < 0.3) continue;
        const a = Math.random() * Math.PI * 2, L = s * (1.6 + Math.random() * 2.8);
        bolt(p.x, p.y, p.x + Math.cos(a) * L, p.y + Math.sin(a) * L, zk);
      }
      ctx.globalAlpha = alpha * lit;
    }

    // Tentacles: thin, thinning and fading toward the tip; white-hot while discharging.
    const rgb = zk > 0 ? '230, 255, 255' : j.hue === 2 ? '210, 190, 255' : '170, 245, 255';
    for (const tn of j.tentacles) {
      for (let q = 1; q < tn.n; q++) {
        const f = q / (tn.n - 1), a = tn.pts[q - 1], p = tn.pts[q];
        ctx.strokeStyle = `rgba(${rgb}, ${Math.min(1, 0.55 * (1 - f * 0.85) * (1 + zk * 1.5)).toFixed(3)})`;
        ctx.lineWidth = tn.w * (1.3 - f);
        ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(p.x, p.y); ctx.stroke();
      }
    }
    // Oral arms: short, wide, frilled ribbons along their chains.
    ctx.fillStyle = j.hue === 2 ? 'rgba(235, 200, 255, 0.22)' : 'rgba(200, 250, 255, 0.22)';
    for (const arm of j.arms) {
      const left = [], right = [];
      arm.pts.forEach((p, q) => {
        const a = arm.pts[Math.max(0, q - 1)], b = arm.pts[Math.min(arm.n - 1, q + 1)];
        let nx = -(b.y - a.y), ny = b.x - a.x;
        const d = Math.hypot(nx, ny) || 1; nx /= d; ny /= d;
        const half = w * 0.09 * (1 - (q / arm.n) * 0.6), frill = Math.sin(q * 2.4 + t * 3 + arm.ph) * 1.4;
        left.push([p.x + nx * (half + frill), p.y + ny * (half + frill)]);
        right.push([p.x - nx * (half - frill), p.y - ny * (half - frill)]);
      });
      ctx.beginPath();
      left.forEach(([x, y], q) => (q ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
      right.reverse().forEach(([x, y]) => ctx.lineTo(x, y));
      ctx.closePath();
      ctx.fill();
    }

    // Bell: translucent dome with a bright rim and inner organs.
    ctx.save();
    ctx.translate(j.x, j.y);
    ctx.rotate(j.ang);
    const g = ctx.createRadialGradient(0, -h * 0.4, 0, 0, -h * 0.2, w);
    g.addColorStop(0, 'rgba(240, 255, 255, 0.55)');
    g.addColorStop(0.6, j.hue === 2 ? 'rgba(170, 140, 255, 0.28)' : 'rgba(110, 230, 255, 0.28)');
    g.addColorStop(1, 'rgba(110, 230, 255, 0.05)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.moveTo(-w, 0);
    ctx.bezierCurveTo(-w, -h * 1.35, w, -h * 1.35, w, 0);
    // The margin pinches in while contracting and flares out while relaxing.
    ctx.quadraticCurveTo(0, h * (0.28 - 0.2 * squeeze), -w, 0);
    ctx.fill();
    ctx.strokeStyle = 'rgba(220, 255, 255, 0.7)';
    ctx.lineWidth = 1.3;
    ctx.stroke();
    if (zk > 0) { ctx.fillStyle = `rgba(225, 255, 255, ${(0.5 * zk).toFixed(3)})`; ctx.fill(); }
    ctx.fillStyle = 'rgba(255, 220, 245, 0.35)';
    for (let k = -1; k <= 1; k += 2) {
      ctx.beginPath();
      ctx.ellipse(k * w * 0.3, -h * 0.45, w * 0.18, h * 0.22, k * 0.4, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.restore();
    ctx.globalAlpha = 1;

    // Gone off the top: come back from below with the strands hanging straight.
    if (j.y < -s * 6) {
      j.y = H + s * 2; j.x = W * (0.1 + Math.random() * 0.8); j.vx = j.vy = 0;
      [...j.tentacles, ...j.arms].forEach((ch) => hang(j, ch));
    }
  }

  function drawFish(f, t, alpha) {
    // Face the way the fish swims; once settled in the mark, face right and hold.
    const sp = Math.hypot(f.vx, f.vy);
    const want = form.on && sp < 60 ? (f.target?.[2] ?? 0) : Math.atan2(f.vy, f.vx);
    let da = want - f.ang;
    da = Math.atan2(Math.sin(da), Math.cos(da));
    f.ang += da * 0.18;
    ctx.save();
    ctx.translate(f.x, f.y);
    ctx.rotate(f.ang);
    // In the mark, fish even out in size and darken a little so the shape reads.
    f.fk = (f.fk || 0) + ((form.on ? 1 : 0) - (f.fk || 0)) * 0.04;
    const size = f.size + (0.85 - f.size) * f.fk;
    ctx.scale(size, size);
    // A small silversided reef fish: tapered body, forked tail that beats with
    // the swim, a dorsal fin, and a pale belly line.
    const a = (0.36 + 0.24 * f.fk) * alpha;
    const wag = Math.sin(t * 14 + f.ph) * 1.8;
    ctx.fillStyle = `rgba(4, 48, 76, ${a})`;
    ctx.beginPath();
    ctx.moveTo(10, 0.3);
    ctx.bezierCurveTo(8, -3.4, 0, -3.9, -6, -2.2);
    ctx.quadraticCurveTo(-8.5, -1.2, -9.5, -0.5 + wag * 0.3);
    ctx.lineTo(-14.5, -4.2 + wag);
    ctx.quadraticCurveTo(-12.2, 0 + wag * 0.6, -14.5, 4 + wag);
    ctx.lineTo(-9.5, 0.6 + wag * 0.3);
    ctx.quadraticCurveTo(-8.5, 1.3, -6, 2);
    ctx.bezierCurveTo(0, 3.4, 7.5, 3, 10, 0.3);
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(1, -3.4); ctx.quadraticCurveTo(-2.5, -6, -5, -2.6); ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = `rgba(210, 240, 250, ${a * 0.55})`;
    ctx.lineWidth = 0.7;
    ctx.beginPath(); ctx.moveTo(7, 0.9); ctx.quadraticCurveTo(0, 1.9, -7, 0.9); ctx.stroke();
    ctx.restore();
  }

  // A reef manta seen from above, swimming left. Each wingbeat is a wave from
  // root to tip: the tips lag behind the shoulders, and seen from above the
  // wings foreshorten as they sweep up and down. Thrust comes on the downstroke.
  // The torch lights its back as it passes through the beam.
  function drawManta(t, dt, alpha, torch) {
    const m = manta;
    m.flap += dt * 1.35;
    const ph = m.flap;
    const span = 0.62 + 0.38 * Math.cos(ph);
    const lag = Math.sin(ph - 0.9) * 24;
    const S = 150;
    const speed = 44 + 26 * Math.max(0, Math.sin(ph + 0.4));
    m.x -= speed * dt;
    m.vy = Math.cos(t * 0.23 + m.seed) * 14;
    m.y += m.vy * dt;
    const bank = Math.atan2(m.vy, speed) * 0.8;
    const scale = Math.min(1.1, Math.max(0.55, W / 1300));

    ctx.save();
    ctx.translate(m.x, m.y);
    ctx.rotate(-bank);
    // The shape is drawn head-right; mirror it so the manta faces the way it swims (left).
    ctx.scale(-scale, scale);

    // Falcate wings: the leading edge bows forward from the head, the tips sweep
    // back into a point, and the trailing edge curves in toward the body.
    const tipY = S * span, tipX = -34 - lag;
    const body = new Path2D();
    body.moveTo(-44, -10);
    body.bezierCurveTo(-26, -tipY * 0.22, -22 - lag * 0.6, -tipY * 0.66, tipX, -tipY);
    body.bezierCurveTo(-6 - lag * 0.5, -tipY * 0.9, 34, -tipY * 0.5, 36, -15);
    // Cephalic fins, rolled forward on either side of the mouth.
    body.quadraticCurveTo(48, -18, 55, -12.5);
    body.quadraticCurveTo(51, -7, 43, -7);
    body.quadraticCurveTo(46, 0, 43, 7);
    body.quadraticCurveTo(51, 7, 55, 12.5);
    body.quadraticCurveTo(48, 18, 36, 15);
    body.bezierCurveTo(34, tipY * 0.5, -6 - lag * 0.5, tipY * 0.9, tipX, tipY);
    body.bezierCurveTo(-22 - lag * 0.6, tipY * 0.66, -26, tipY * 0.22, -44, 10);
    body.quadraticCurveTo(-52, 0, -44, -10);

    // Whip tail, trailing with the wingbeat.
    ctx.strokeStyle = `rgba(6, 24, 40, ${0.6 * alpha})`;
    ctx.lineCap = 'round';
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.moveTo(-50, 0);
    ctx.quadraticCurveTo(-95, Math.sin(ph - 1.5) * 9, -142, Math.sin(ph - 2.4) * 5);
    ctx.stroke();

    // Dark back, a touch lighter toward the wingtips, with the pale shoulder
    // chevrons of a reef manta.
    const g = ctx.createRadialGradient(8, 0, 6, -10, 0, S);
    g.addColorStop(0, `rgba(5, 20, 36, ${0.74 * alpha})`);
    g.addColorStop(0.7, `rgba(9, 32, 54, ${0.66 * alpha})`);
    g.addColorStop(1, `rgba(16, 48, 76, ${0.5 * alpha})`);
    ctx.fillStyle = g;
    ctx.fill(body);
    ctx.fillStyle = `rgba(150, 196, 220, ${0.14 * alpha})`;
    for (const k of [-1, 1]) {
      ctx.beginPath();
      ctx.moveTo(30, k * 13);
      ctx.quadraticCurveTo(18, k * (24 + 30 * span), -2, k * (24 + 40 * span));
      ctx.quadraticCurveTo(10, k * (20 + 16 * span), 24, k * 10);
      ctx.fill();
    }
    // Spine ridge and a faint rim where light catches the wing edges.
    ctx.strokeStyle = `rgba(120, 180, 215, ${0.1 * alpha})`;
    ctx.lineWidth = 1.2;
    ctx.stroke(body);
    ctx.beginPath(); ctx.moveTo(36, 0); ctx.lineTo(-44, 0); ctx.stroke();

    // Torchlight on its back.
    const beam = Math.exp(-((m.x - torch.x) ** 2 + (m.y - torch.y) ** 2) / (torch.r * torch.r * 1.6));
    if (beam > 0.02) {
      ctx.fillStyle = `rgba(90, 170, 210, ${0.28 * beam * torch.k * alpha})`;
      ctx.fill(body);
    }
    ctx.restore();
  }

  // depthM: current depth in metres; pointer: {x, y, speed}; torch: {x, y, r, k}.
  function render(t, dt, depthM, pointer, torch, scrollKick = 0) {
    ctx.clearRect(0, 0, W, H);

    // A manta glides across now and then once the diver reaches the deep,
    // behind the glowing life.
    const deep = Math.max(0, Math.min(1, (depthM - 34) / 6));
    if (deep > 0.01) {
      if (!manta.active && t > manta.next) {
        Object.assign(manta, { active: true, x: W + 260, y: H * (0.3 + Math.random() * 0.35), flap: Math.random() * 6, seed: Math.random() * 6 });
      }
      if (manta.active) {
        drawManta(t, dt, deep, torch);
        if (manta.x < -300) { manta.active = false; manta.next = t + 14 + Math.random() * 10; }
      }
    }

    // In the dark, a moving pointer stirs up plankton.
    if (torch.k > 0.05 && pointer.active && pointer.speed > 120 && dt > 0) {
      spark(pointer.x, pointer.y, Math.min(4, Math.ceil(pointer.speed / 500)), 18);
    }
    if (torch.k > 0.01 || plankton.length) {
      ctx.globalCompositeOperation = 'lighter';
      if (torch.k > 0.01) jellies.forEach((j) => drawJelly(j, t, dt, torch.k, torch));
      for (let i = plankton.length - 1; i >= 0; i--) {
        const p = plankton[i];
        p.life -= dt * p.decay;
        if (p.life <= 0) { plankton.splice(i, 1); continue; }
        p.vx *= 0.94; p.vy = p.vy * 0.94 - 4 * dt;
        p.x += p.vx * dt; p.y += p.vy * dt;
        const a = p.life * p.life * (0.75 + 0.25 * Math.sin(t * 9 + p.ph));
        const sz = p.size * (0.5 + 0.5 * p.life);
        ctx.globalAlpha = a * Math.max(0.35, torch.k);
        ctx.drawImage(p.glow, p.x - sz, p.y - sz, sz * 2, sz * 2);
      }
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = 'source-over';
    }

    // Small schooling fish belong in the sunlit shallows.
    const shallow = Math.max(0, Math.min(1, (32 - depthM) / 8));
    const now = performance.now();
    // Gather only for a pointer resting on open water with no scrolling either (a
    // trackpad scroll leaves the pointer still), and not again right after scattering.
    const busy = Math.max(pointer.t, pointer.scrollT);
    if (form.on && (now - busy < 120 || shallow < 0.5)) { scatter(); form.next = now + 12000; }
    else if (!form.on && pointer.active && pointer.open && shallow > 0.5 && pointer.t > 0 && now - busy > 10000 && now > form.next) gather(pointer);
    if (scrollKick > 0.35) {
      // A fast scroll startles the school.
      fish.forEach((f) => { f.vx += (Math.random() - 0.5) * 120 * scrollKick; f.vy += (Math.random() - 0.5) * 120 * scrollKick; });
      if (form.on) scatter();
    }
    if (shallow > 0.01) {
      fish.forEach((f) => {
        if (form.on && f.target) {
          // Drift toward the fish's place in the mark: a soft spring with a
          // cruising-speed cap, so the school takes several seconds to gather.
          const tx = form.cx + f.target[0] + Math.sin(t * 1.6 + f.ph) * 1.5, ty = form.cy + f.target[1] + Math.cos(t * 1.3 + f.ph) * 1.5;
          f.vx += ((tx - f.x) * 1.1 - f.vx * 1.5) * dt;
          f.vy += ((ty - f.y) * 1.1 - f.vy * 1.5) * dt;
          const sp = Math.hypot(f.vx, f.vy), cap = 70 + f.size * 20;
          if (sp > cap) { f.vx *= cap / sp; f.vy *= cap / sp; }
          f.x += f.vx * dt; f.y += f.vy * dt;
          drawFish(f, t, shallow);
          return;
        }
        const dx = f.x - pointer.x, dy = f.y - pointer.y, d = Math.hypot(dx, dy) || 1;
        if (d < 150) { f.vx += (dx / d) * 9; f.vy += (dy / d) * 9; }
        f.vx += (f.dir * f.speed - f.vx) * 0.02;
        f.vy += ((f.cy + Math.sin(t * 0.5 + f.s) * 40 - f.y) * 0.4 - f.vy) * 0.03;
        f.x += f.vx * dt; f.y += f.vy * dt + Math.sin(t * 3 + f.ph) * 0.15;
        if (f.x > W + 60) f.x = -60;
        if (f.x < -60) f.x = W + 60;
        drawFish(f, t, shallow);
      });
    }

    // A quick pointer leaves a few bubbles behind.
    if (pointer.speed > 900 && Math.random() < 0.35) burst(pointer.x, pointer.y, 1, 10);

    for (let i = bubbles.length - 1; i >= 0; i--) {
      const b = bubbles[i];
      b.y += b.vy * dt;
      b.x += Math.sin(t * 4 + b.ph) * 0.35;
      b.life -= dt * 0.45;
      if (b.life <= 0 || b.y < -10) { bubbles.splice(i, 1); continue; }
      ctx.strokeStyle = `rgba(255, 255, 255, ${0.75 * b.life})`;
      ctx.lineWidth = 1.2;
      ctx.beginPath(); ctx.arc(b.x, b.y, b.r, 0, Math.PI * 2); ctx.stroke();
      ctx.fillStyle = `rgba(255, 255, 255, ${0.5 * b.life})`;
      ctx.beginPath(); ctx.arc(b.x - b.r * 0.35, b.y - b.r * 0.35, b.r * 0.28, 0, Math.PI * 2); ctx.fill();
    }
  }

  resize();
  return { resize, render, burst, spark, zap };
}
