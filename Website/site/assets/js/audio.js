// Sound for the dive, synthesised with Web Audio: no audio files, nothing to
// license. Off by default; the menu bar's speaker turns it on, and the choice
// is remembered. Browsers only allow audio after a gesture, so a remembered
// "on" waits for the visitor's first click or key press.
//
// The ambience is a calm sea, not a texture: soft washes of water that swell
// and fade at irregular intervals with near-silence between them, and now and
// then a few tiny bubbles. There are no sustained tones, which read as
// machinery. Below the reef the washes grow darker, rarer and quieter, until
// the deep is almost silent. Effects are short and quiet.

const KEY = 'blenny-sound';
const read = () => { try { return localStorage.getItem(KEY); } catch { return null; } };
const write = (v) => { try { localStorage.setItem(KEY, v); } catch { /* storage unavailable */ } };

let ctx = null, master, sfx, bedFilter, pink = null, on = false, depth = 0, waveTimer = 0, trickleTimer = 0;
const listeners = new Set();

function noiseBuffer(seconds) {
  const b = ctx.createBuffer(1, ctx.sampleRate * seconds, ctx.sampleRate);
  const d = b.getChannelData(0);
  for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  return b;
}

// Pink noise (Paul Kellet's filter): the natural spectrum of water, without the
// rumble of brown noise or the hiss of white.
function pinkBuffer(seconds) {
  const b = ctx.createBuffer(1, ctx.sampleRate * seconds, ctx.sampleRate);
  const d = b.getChannelData(0);
  let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
  for (let i = 0; i < d.length; i++) {
    const w = Math.random() * 2 - 1;
    b0 = 0.99886 * b0 + w * 0.0555179; b1 = 0.99332 * b1 + w * 0.0750759; b2 = 0.969 * b2 + w * 0.153852;
    b3 = 0.8665 * b3 + w * 0.3104856; b4 = 0.55 * b4 + w * 0.5329522; b5 = -0.7616 * b5 - w * 0.016898;
    d[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11;
    b6 = w * 0.115926;
  }
  return b;
}

// A short, dark room for the effects: decaying stereo noise.
function impulse(seconds) {
  const b = ctx.createBuffer(2, ctx.sampleRate * seconds, ctx.sampleRate);
  for (let c = 0; c < 2; c++) {
    const d = b.getChannelData(c);
    for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / d.length, 3.2);
  }
  return b;
}

function init() {
  ctx = new (window.AudioContext || window.webkitAudioContext)();
  master = ctx.createGain();
  master.gain.value = 0;
  master.connect(ctx.destination);

  const room = ctx.createConvolver();
  room.buffer = impulse(2.6);
  const wet = ctx.createGain();
  wet.gain.value = 0.38;
  room.connect(wet).connect(master);
  sfx = ctx.createGain();
  sfx.gain.value = 0.55;
  sfx.connect(master);
  sfx.connect(room);

  pink = pinkBuffer(12);
  // A barely-there bed of soft water, so the gaps between washes never sound
  // like a switched-off speaker.
  const bed = ctx.createBufferSource();
  bed.buffer = pink;
  bed.loop = true;
  bedFilter = ctx.createBiquadFilter();
  bedFilter.type = 'lowpass';
  bedFilter.frequency.value = 520;
  bedFilter.Q.value = 0.3;
  const bedGain = ctx.createGain();
  bedGain.gain.value = 0.05;
  bed.connect(bedFilter).connect(bedGain).connect(master);
  bed.start();
  applyDepth();
}

function applyDepth() {
  if (!ctx) return;
  bedFilter.frequency.setTargetAtTime(160 + 420 * Math.pow(1 - depth, 1.5), ctx.currentTime, 1.5);
}

// One wash of water: it swells, brightens a little as it peaks, then drains
// away more slowly, somewhere left or right in the stereo field.
function wave() {
  const t = ctx.currentTime;
  const dur = 5 + Math.random() * 3.5, rise = 1.4 + Math.random() * 1;
  const below = Math.min(1, depth / 0.75);
  const base = 260 + 900 * Math.pow(1 - below, 1.6);
  const peak = 0.13 * (1 - below * 0.75) * (0.55 + Math.random() * 0.45);
  const src = ctx.createBufferSource();
  src.buffer = pink;
  const filter = ctx.createBiquadFilter();
  filter.type = 'lowpass';
  filter.Q.value = 0.4;
  filter.frequency.setValueAtTime(base * 0.55, t);
  filter.frequency.exponentialRampToValueAtTime(base * 1.5, t + rise);
  filter.frequency.exponentialRampToValueAtTime(base * 0.45, t + dur);
  const g = ctx.createGain();
  g.gain.setValueAtTime(0.0001, t);
  g.gain.linearRampToValueAtTime(peak, t + rise);
  g.gain.setTargetAtTime(0.0001, t + rise, (dur - rise) / 3.2);
  const pan = ctx.createStereoPanner();
  pan.pan.value = (Math.random() - 0.5) * 0.9;
  src.connect(filter).connect(g).connect(pan).connect(master);
  src.start(t, Math.random() * 6);
  src.stop(t + dur + 0.5);
  // Unhurried: the next wash arrives as this one fades, often after a pause;
  // in the deep they come less often still.
  waveTimer = setTimeout(wave, (dur * 0.85 + 2 + Math.random() * 5) * 1000 * (1 + below));
}

// Now and then a few tiny bubbles rise past, never in the deep.
function trickle() {
  if (depth < 0.75) {
    const n = 2 + Math.floor(Math.random() * 3);
    for (let i = 0; i < n; i++) tone({ from: 700 + Math.random() * 500, to: 1600 + Math.random() * 900, at: i * (0.09 + Math.random() * 0.12), peak: 0.018 + Math.random() * 0.012, decay: 0.06, glide: 0.05 });
  }
  trickleTimer = setTimeout(trickle, 4000 + Math.random() * 7000);
}

function set(next) {
  on = next;
  write(on ? 'on' : 'off');
  clearTimeout(waveTimer);
  clearTimeout(trickleTimer);
  if (on) {
    if (!ctx) init();
    ctx.resume();
    wave();
    trickleTimer = setTimeout(trickle, 2500);
  }
  // Fade in over a few seconds, so turning sound on never arrives as a burst.
  if (ctx) master.gain.setTargetAtTime(on ? 0.36 : 0, ctx.currentTime, on ? 1.6 : 0.15);
  listeners.forEach((fn) => fn(on));
}

// A remembered "on" starts with the first gesture.
if (read() === 'on') {
  const start = (e) => {
    removeEventListener('pointerdown', start, true);
    removeEventListener('keydown', start, true);
    // A press on the speaker is handled by its own click; starting here too would
    // turn the sound on and straight back off.
    if (!e.target?.closest?.('#sound')) set(true);
  };
  addEventListener('pointerdown', start, true);
  addEventListener('keydown', start, true);
}

// ---- Effects --------------------------------------------------------------

function env(gain, t, attack, peak, decay) {
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(peak, t + attack);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + attack + decay);
}

function tone({ type = 'sine', from, to, at = 0, attack = 0.005, peak = 0.2, decay = 0.1, glide = 0.06 }) {
  const t = ctx.currentTime + at;
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.type = type;
  o.frequency.setValueAtTime(from, t);
  if (to) o.frequency.exponentialRampToValueAtTime(to, t + glide);
  env(g, t, attack, peak, decay);
  o.connect(g).connect(sfx);
  o.start(t);
  o.stop(t + attack + decay + 0.05);
}

function burst({ at = 0, from = 3000, to = 500, peak = 0.25, decay = 0.6, q = 0.9 }) {
  const t = ctx.currentTime + at;
  const src = ctx.createBufferSource();
  src.buffer = noiseBuffer(decay + 0.1);
  const f = ctx.createBiquadFilter();
  f.type = 'bandpass';
  f.Q.value = q;
  f.frequency.setValueAtTime(from, t);
  f.frequency.exponentialRampToValueAtTime(to, t + decay);
  const g = ctx.createGain();
  env(g, t, 0.01, peak, decay);
  src.connect(f).connect(g).connect(sfx);
  src.start(t);
}

const bubble = (pitch = 1, at = 0, peak = 0.16) => tone({ from: 260 * pitch, to: 900 * pitch, at, peak, decay: 0.09, glide: 0.07 });

const EFFECTS = {
  // A jellyfish discharging: a crackle of bright static over a short low buzz.
  zap: () => {
    for (let i = 0; i < 11; i++) burst({ at: Math.random() * 0.6, from: 5000 + Math.random() * 2500, to: 1900, peak: 0.12 + Math.random() * 0.1, decay: 0.035 + Math.random() * 0.05, q: 2.2 });
    tone({ type: 'sawtooth', from: 96, to: 68, peak: 0.09, attack: 0.01, decay: 0.5, glide: 0.45 });
  },
  // The download bubble bursting.
  pop: () => { tone({ from: 180, to: 520, peak: 0.16, decay: 0.14, glide: 0.09 }); for (let i = 0; i < 5; i++) bubble(1.1 + Math.random() * 0.9, 0.08 + i * 0.05, 0.06); },
  // A click in open water.
  bubble: () => { bubble(0.9 + Math.random() * 0.4); if (Math.random() < 0.5) bubble(1.4 + Math.random() * 0.4, 0.07, 0.08); },
  // A new zone on the depth gauge.
  ping: () => { tone({ from: 1180, peak: 0.09, attack: 0.004, decay: 1.6 }); tone({ from: 2360, peak: 0.02, attack: 0.004, decay: 0.8 }); },
  // The Reef comes up, or goes back down.
  expand: () => { bubble(0.7, 0, 0.14); bubble(1.05, 0.06, 0.12); bubble(1.5, 0.12, 0.08); },
  collapse: () => { bubble(1.3, 0, 0.1); bubble(0.85, 0.07, 0.1); },
  // An icon dropped into a row of the Organize demo.
  drip: () => tone({ from: 1500, to: 520, peak: 0.12, decay: 0.12, glide: 0.08 }),
  // The easter egg leaping out of its crevice.
  hop: () => { tone({ type: 'triangle', from: 300, to: 760, peak: 0.12, decay: 0.16, glide: 0.14 }); bubble(1.6, 0.18, 0.08); bubble(2, 0.26, 0.06); },
  // Bioluminescence answering a click in the dark.
  shimmer: () => [0, 0.05, 0.11, 0.18].forEach((at, i) => tone({ from: 1760 * [1, 1.25, 1.5, 2][i], at, peak: 0.035, decay: 0.7 })),
  // Breaking through the surface at the end of the ascent.
  splash: () => {
    burst({ from: 4200, to: 700, peak: 0.32, decay: 0.75, q: 0.6 });
    burst({ at: 0.12, from: 2400, to: 400, peak: 0.16, decay: 0.9, q: 1.2 });
    for (let i = 0; i < 6; i++) bubble(1 + Math.random(), 0.2 + i * 0.07, 0.06);
  },
};

export const sound = {
  get on() { return on; },
  toggle() { set(!on); },
  onChange(fn) { listeners.add(fn); },
  // depth01: 0 at the surface, 1 at 60 m.
  setDepth(d) {
    if (Math.abs(d - depth) < 0.004) return;
    depth = d;
    if (on) applyDepth();
  },
  play(name) {
    if (!on || !ctx || ctx.state !== 'running') return;
    EFFECTS[name]?.();
  },
};
