// Full-screen WebGL water. Open water has no caustic pattern of its own:
// light shows up as volumetric shafts, a rippled surface overhead in the
// shallows, forward scattering toward the sun and lit particles at several
// depths of field. Colour and light follow the dive depth.
// Without WebGL the page keeps its CSS gradient background.

const FRAGMENT = `
precision highp float;
uniform vec2 uRes;
uniform float uTime;
uniform float uDepth;   // 0 at the surface, 1 at 60 m
uniform float uScroll;  // CSS pixels scrolled
uniform vec4 uTorch;    // torch centre (device px, GL origin), radius (device px), strength
uniform vec2 uLean;     // pointer offset from the centre, -0.5..0.5
uniform float uStreak;  // 0 at rest, up to 1 while scrolling fast

float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec2 hash22(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.xx + p3.yz) * p3.zy); }
float gnoise(vec2 p) {
  vec2 i = floor(p); vec2 f = fract(p);
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  float a = dot(hash22(i) * 2.0 - 1.0, f);
  float b = dot(hash22(i + vec2(1.0, 0.0)) * 2.0 - 1.0, f - vec2(1.0, 0.0));
  float c = dot(hash22(i + vec2(0.0, 1.0)) * 2.0 - 1.0, f - vec2(0.0, 1.0));
  float d = dot(hash22(i + vec2(1.0, 1.0)) * 2.0 - 1.0, f - vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { s += a * gnoise(p); p = mat2(1.6, 1.2, -1.2, 1.6) * p; a *= 0.5; } return s; }

vec3 water(float d) {
  vec3 col = mix(vec3(0.56, 0.93, 0.97), vec3(0.14, 0.68, 0.85), smoothstep(0.0, 0.12, d));
  col = mix(col, vec3(0.05, 0.46, 0.7), smoothstep(0.1, 0.38, d));
  col = mix(col, vec3(0.03, 0.28, 0.5), smoothstep(0.36, 0.7, d));
  return mix(col, vec3(0.025, 0.18, 0.36), smoothstep(0.7, 1.0, d));
}

// Soft, smoothly animated interference used for the rippled surface overhead.
float ripples(vec2 p, float t) {
  float v = 0.0;
  v += sin(p.x * 1.3 + gnoise(p * 0.7 + t * 0.2) * 3.0 + t * 0.9);
  v += sin(p.x * 0.7 - p.y * 1.9 + gnoise(p * 0.5 - t * 0.15) * 4.0 - t * 0.7);
  v += sin(p.x * 2.1 + p.y * 0.8 + t * 1.3);
  return v / 3.0;
}

void main() {
  vec2 uv = gl_FragCoord.xy / uRes;
  float aspect = uRes.x / uRes.y;
  vec2 p = vec2(uv.x * aspect, uv.y);
  float t = uTime;
  float light = exp(-uDepth * 3.0);

  // Water column, slightly brighter toward the top of the view.
  float d = clamp(uDepth + (1.0 - uv.y) * 0.06, 0.0, 1.0);
  vec3 col = water(d);
  col *= 0.94 + 0.08 * fbm(p * 1.4 + vec2(t * 0.01, uScroll * 0.0003));

  // Forward scattering around the sun, high on the upper left.
  vec2 sunPos = vec2((0.12 + uLean.x * 0.07) * aspect, 1.35 + uLean.y * 0.04);
  vec2 dv = p - sunPos;
  float dist = length(dv);
  col += vec3(0.85, 0.98, 0.95) * 0.42 * light * exp(-dist * 1.5);

  // Volumetric light shafts: noise in the angle around the sun, slowly swaying.
  float ang = atan(dv.x, -dv.y);
  float sway = t * 0.035;
  float shafts = 0.0;
  shafts += smoothstep(0.05, 0.6, gnoise(vec2(ang * 10.0 + sway, t * 0.05)) + 0.2) * 0.55;
  shafts += smoothstep(0.1, 0.7, gnoise(vec2(ang * 23.0 - sway * 1.7, t * 0.08 + 4.0)) + 0.15) * 0.35;
  shafts += smoothstep(0.2, 0.8, gnoise(vec2(ang * 47.0 + sway * 2.3, t * 0.12 + 9.0)) + 0.1) * 0.2;
  float shaftFade = exp(-(dist - 0.35) * 0.95) * smoothstep(0.0, 0.25, dist);
  float shaftLight = shafts * shaftFade * exp(-uDepth * 2.1);
  col += vec3(0.8, 0.97, 1.0) * shaftLight * 0.3;

  // Underside of the surface: a bright, softly rippled ceiling in the first metres.
  float ceiling = smoothstep(0.84, 1.0, uv.y) * (1.0 - smoothstep(0.0, 0.06, uDepth));
  if (ceiling > 0.001) {
    float persp = 1.0 / (1.08 - uv.y);
    vec2 sp = vec2((uv.x - 0.5) * aspect * persp * 3.0, persp * 2.0);
    float r = ripples(sp, t);
    float glint = pow(max(0.0, r), 3.0);
    col = mix(col, vec3(0.86, 0.98, 1.0), ceiling * (0.28 + 0.22 * r));
    col += vec3(1.0) * glint * ceiling * 0.35;
  }

  // Suspended particles at three depths of field; near ones are large and soft.
  for (int L = 0; L < 3; L++) {
    float fl = float(L);
    float density = 22.0 - fl * 7.0;
    vec2 g = vec2(gl_FragCoord.x, gl_FragCoord.y - uScroll * (0.15 + 0.35 * fl)) / uRes.y * density;
    g += vec2(sin(t * 0.07 + fl) * 0.4, t * (0.05 + 0.03 * fl));
    vec2 cell = floor(g);
    vec2 f = fract(g) - 0.5;
    vec2 o = hash22(cell + fl * 31.0) - 0.5;
    float keep = step(0.62 + fl * 0.1, hash12(cell + fl * 7.0));
    float radius = mix(0.03, 0.09, fl * 0.5) * (0.6 + 0.8 * hash12(cell + 3.0));
    float blur = mix(0.35, 0.95, fl * 0.5);
    // Fast scrolling stretches the particles into streaks, nearer ones the most.
    vec2 q = f - o * 0.7;
    q.y /= 1.0 + uStreak * (2.0 + fl * 3.0);
    float disc = smoothstep(radius, radius * (1.0 - blur), length(q)) * (1.0 + uStreak * 0.6);
    float twinkle = 0.75 + 0.25 * sin(t * (1.0 + hash12(cell) * 2.0) + hash12(cell + 9.0) * 30.0);
    float bright = (0.1 + 0.26 * light) * (1.0 - fl * 0.25) * (1.0 + shaftLight * 4.0) * twinkle;
    col += vec3(0.92, 0.98, 1.0) * disc * keep * bright;
  }

  // The deep is dark except where the torch points: a soft hot spot, a wider
  // spill and a faint cyan scatter in the water around the beam.
  if (uTorch.w > 0.001) {
    float r = length(gl_FragCoord.xy - uTorch.xy) / uTorch.z;
    float spot = exp(-r * r * 1.6);
    float spill = exp(-r * r * 0.22);
    float lit = 0.16 + 0.55 * spill + 0.75 * spot;
    col = mix(col, col * lit + vec3(0.05, 0.22, 0.26) * spot * 0.55, uTorch.w);
  }

  // Lens vignette and dither against banding in the smooth gradients.
  col *= 1.0 - 0.3 * pow(length((uv - vec2(0.5, 0.55)) * vec2(1.0, 1.1)), 2.2);
  col += (hash12(gl_FragCoord.xy + fract(t * 7.0) * 61.0) - 0.5) / 255.0;
  gl_FragColor = vec4(col, 1.0);
}`;

const VERTEX = 'attribute vec2 p; void main(){ gl_Position = vec4(p, 0.0, 1.0); }';

export function createSea(canvas) {
  const gl = canvas.getContext('webgl', { antialias: false, alpha: false, powerPreference: 'high-performance' });
  if (!gl) {
    canvas.remove();
    return { resize() {}, render() {} };
  }
  const compile = (type, src) => {
    const s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) console.error(gl.getShaderInfoLog(s));
    return s;
  };
  const prog = gl.createProgram();
  gl.attachShader(prog, compile(gl.VERTEX_SHADER, VERTEX));
  gl.attachShader(prog, compile(gl.FRAGMENT_SHADER, FRAGMENT));
  gl.bindAttribLocation(prog, 0, 'p');
  gl.linkProgram(prog);
  gl.useProgram(prog);
  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
  const u = (n) => gl.getUniformLocation(prog, n);
  const uRes = u('uRes'), uTime = u('uTime'), uDepth = u('uDepth'), uScroll = u('uScroll');
  const uTorch = u('uTorch'), uLean = u('uLean'), uStreak = u('uStreak');

  function resize() {
    // The water is soft; large screens render slightly below native resolution.
    const pixels = innerWidth * innerHeight;
    const dpr = Math.min(devicePixelRatio || 1, pixels > 2_000_000 ? 1 : 1.5);
    canvas.width = Math.round(innerWidth * dpr);
    canvas.height = Math.round(innerHeight * dpr);
    gl.viewport(0, 0, canvas.width, canvas.height);
  }

  let leanX = 0, leanY = 0;
  function render(time, depth01, scroll, torch, pointer, streak = 0) {
    gl.uniform1f(uStreak, streak);
    const sx = canvas.width / innerWidth, sy = canvas.height / innerHeight;
    gl.uniform2f(uRes, canvas.width, canvas.height);
    gl.uniform4f(uTorch, torch.x * sx, canvas.height - torch.y * sy, torch.r * sx, torch.k);
    if (pointer.active) {
      leanX += (pointer.x / innerWidth - 0.5 - leanX) * 0.03;
      leanY += (0.5 - pointer.y / innerHeight - leanY) * 0.03;
    }
    gl.uniform2f(uLean, leanX, leanY);
    gl.uniform1f(uTime, time);
    gl.uniform1f(uDepth, depth01);
    gl.uniform1f(uScroll, scroll);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  }

  resize();
  return { resize, render };
}
