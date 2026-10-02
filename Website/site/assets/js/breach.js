// The end of the ascent: the water surface sweeps down across the screen as the
// diver breaks through, with a bright wash of air and a spray of droplets.
// The overlay canvas exists only while the effect plays.

const DURATION = 1500;

export function createBreach() {
  let running = false;

  function play() {
    if (running) return;
    running = true;
    const canvas = document.createElement('canvas');
    canvas.className = 'breach';
    canvas.setAttribute('aria-hidden', 'true');
    document.body.append(canvas);
    const ctx = canvas.getContext('2d');
    const dpr = Math.min(devicePixelRatio || 1, 2);
    const W = innerWidth, H = innerHeight;
    canvas.width = W * dpr; canvas.height = H * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    const drops = [];
    const start = performance.now();
    let last = start, lastY = -40;

    const surface = (x, ys, T) => ys + Math.sin(x * 0.011 + T * 7) * 12 + Math.sin(x * 0.029 - T * 5) * 5;

    function frame(now) {
      const k = Math.min(1, (now - start) / DURATION);
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      const T = now / 1000;
      ctx.clearRect(0, 0, W, H);

      // Phase one: the surface line falls through the view. Phase two: the air wash fades.
      const sweep = Math.min(1, k / 0.5);
      const ease = 1 - Math.pow(1 - sweep, 2.2);
      const ys = -40 + (H + 80) * ease;
      const wash = k < 0.5 ? 0.62 : 0.62 * Math.pow(1 - (k - 0.5) / 0.5, 1.6);

      if (wash > 0.002) {
        // Air above the line, bright and slightly warm toward the top.
        const g = ctx.createLinearGradient(0, 0, 0, Math.max(1, ys));
        g.addColorStop(0, `rgba(255, 252, 240, ${wash})`);
        g.addColorStop(1, `rgba(205, 245, 255, ${wash * 0.7})`);
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.moveTo(0, 0);
        for (let x = 0; x <= W + 20; x += 20) ctx.lineTo(x, surface(x, ys, T));
        ctx.lineTo(W, 0);
        ctx.closePath();
        ctx.fill();
      }
      if (sweep < 1) {
        // A refraction band just under the line, then the line itself.
        const band = ctx.createLinearGradient(0, ys, 0, ys + 110);
        band.addColorStop(0, 'rgba(230, 252, 255, 0.45)');
        band.addColorStop(1, 'rgba(230, 252, 255, 0)');
        ctx.fillStyle = band;
        ctx.fillRect(0, ys - 12, W, 130);
        ctx.save();
        ctx.shadowColor = 'rgba(255, 255, 255, 0.95)';
        ctx.shadowBlur = 18;
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.95)';
        ctx.lineWidth = 3;
        ctx.beginPath();
        for (let x = 0; x <= W + 20; x += 14) {
          const y = surface(x, ys, T);
          if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();
        ctx.restore();
        // Spray thrown up where the line passes.
        const n = Math.min(40, Math.round((ys - lastY) / 6));
        for (let i = 0; i < n; i++) {
          const x = Math.random() * W;
          drops.push({ x, y: surface(x, ys, T), vx: (Math.random() - 0.5) * 220, vy: -(260 + Math.random() * 620), r: 1.5 + Math.random() * 4.5, life: 1 });
        }
      }
      lastY = ys;

      for (let i = drops.length - 1; i >= 0; i--) {
        const d = drops[i];
        d.vy += 1500 * dt;
        d.x += d.vx * dt; d.y += d.vy * dt;
        d.life -= dt * 0.9;
        if (d.life <= 0 || d.y > H + 20) { drops.splice(i, 1); continue; }
        ctx.fillStyle = `rgba(255, 255, 255, ${0.85 * d.life})`;
        ctx.beginPath();
        ctx.ellipse(d.x, d.y, d.r * 0.8, d.r * (1 + Math.min(1.2, Math.abs(d.vy) / 900)), 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = `rgba(120, 200, 235, ${0.5 * d.life})`;
        ctx.lineWidth = 1;
        ctx.stroke();
      }

      if (k < 1 || drops.length) requestAnimationFrame(frame);
      else { canvas.remove(); running = false; }
    }
    requestAnimationFrame(frame);
  }

  return { play };
}
