// Procedural underwater materials for rock and sand.
//
// Each surface owns a small WebGL context and works in three stages:
//   1. bake    a height field (plus hole and silhouette distance) once per size;
//   2. light   it once: albedo layers, normals, soft shadows, ambient occlusion,
//              wet highlights and water tint, plus a caustic-receptivity mask;
//   3. frame   composite animated caustics over the lit base while on screen.
// If WebGL is unavailable, the host keeps its CSS look.

const COMMON = `
precision highp float;
// Hash without sine: stable at the coordinate ranges used here.
float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
vec2 hash22(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973)); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.xx + p3.yz) * p3.zy); }
// Quintic gradient noise, roughly in [-0.7, 0.7].
float gnoise(vec2 p) {
  vec2 i = floor(p); vec2 f = fract(p);
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  float a = dot(hash22(i) * 2.0 - 1.0, f);
  float b = dot(hash22(i + vec2(1.0, 0.0)) * 2.0 - 1.0, f - vec2(1.0, 0.0));
  float c = dot(hash22(i + vec2(0.0, 1.0)) * 2.0 - 1.0, f - vec2(0.0, 1.0));
  float d = dot(hash22(i + vec2(1.0, 1.0)) * 2.0 - 1.0, f - vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
const mat2 ROT = mat2(1.6, 1.2, -1.2, 1.6);
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 6; i++) { s += a * gnoise(p); p = ROT * p; a *= 0.5; } return s; }
float fbm3(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 3; i++) { s += a * gnoise(p); p = ROT * p; a *= 0.5; } return s; }
float ridged(vec2 p) {
  float s = 0.0; float a = 0.5; float prev = 1.0;
  for (int i = 0; i < 5; i++) { float n = 1.0 - abs(gnoise(p) * 1.5); n *= n; s += n * a * prev; prev = n; p = ROT * p; a *= 0.5; }
  return s;
}
// x: F1, y: F2, z: random id of the nearest cell.
vec3 voronoi(vec2 p) {
  vec2 i = floor(p); vec2 f = fract(p);
  float d1 = 8.0; float d2 = 8.0; vec2 id = vec2(0.0);
  for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
    vec2 g = vec2(float(x), float(y));
    vec2 r = g + hash22(i + g) - f;
    float d = dot(r, r);
    if (d < d1) { d2 = d1; d1 = d; id = i + g; } else if (d < d2) { d2 = d; }
  }
  return vec3(sqrt(d1), sqrt(d2), hash12(id));
}
`;

// Shared geometry: silhouettes, holes and height fields, in CSS pixels, y down.
const GEOMETRY = `
uniform vec2 uBox;        // canvas size in CSS px
uniform float uPad;       // margin reserved for the drop shadow
uniform float uSeed;
uniform int uKind;        // 0 reef wall, 1 boulder, 2 sand bank
uniform vec4 uHoles[12];  // centre and radii in CSS px
uniform float uHoleCount;
uniform float uMound;     // sand mound centre, 0..1 across the bank

float holeField(vec2 p) {
  float m = 9.0;
  for (int i = 0; i < 12; i++) {
    if (float(i) >= uHoleCount) break;
    vec4 h = uHoles[i];
    m = min(m, length((p - h.xy) / h.zw));
  }
  return m;
}

// Signed distance to the silhouette in px, positive inside.
float shapeSD(vec2 p) {
  vec2 inner = uBox - 2.0 * uPad;
  vec2 q = p - uPad;
  if (uKind == 2) {
    // A low bank that rises into a mound under the perch rock on the right.
    float x = q.x / inner.x;
    float mound = exp(-pow((x - uMound) / 0.2, 2.0));
    float crest = inner.y * (0.5 - 0.22 * mound) + gnoise(vec2(q.x * 0.005, uSeed)) * 16.0 + gnoise(vec2(q.x * 0.03, uSeed + 3.0)) * 3.0;
    return q.y - crest;
  }
  vec2 c; vec2 r; float e;
  if (uKind == 0) { c = inner * vec2(0.5, 0.52); r = inner * vec2(0.46, 0.43); e = 2.8; }
  else { c = vec2(inner.x * 0.5, inner.y * 1.04); r = vec2(inner.x * 0.46, inner.y * 0.94); e = 2.7; }
  vec2 v = (q - c) / r;
  float a = atan(v.y, v.x);
  vec2 dir = vec2(cos(a), sin(a));
  float wobble = fbm3(dir * 1.5 + uSeed) * 0.26 + fbm3(dir * 4.5 + uSeed + 9.0) * 0.07 + fbm3(q * 0.02 + uSeed) * 0.03;
  wobble *= smoothstep(0.05, 0.55, length(v));
  vec2 av = pow(abs(v), vec2(e));
  float d = pow(av.x + av.y, 1.0 / e) - 1.0 + wobble;
  return -d * min(r.x, r.y);
}

float coralMask(vec2 p, vec2 w) { return smoothstep(0.02, 0.22, fbm(p * 0.0055 + uSeed * 3.0 + w * 0.8)); }
float barnacleMask(vec2 p) { return smoothstep(0.18, 0.34, fbm3(p * 0.007 + uSeed + 33.0)); }
vec2 rockWarp(vec2 p) { vec2 q = p * 0.0032 + uSeed; return vec2(fbm3(q * 1.2), fbm3(q * 1.2 + 5.2)); }

float rockHeight(vec2 p, float sd) {
  vec2 w = rockWarp(p);
  vec2 q = p * 0.0032 + uSeed;
  float h = fbm(q + w * 1.1) * 1.35;
  h += fbm(p * 0.011 + w * 0.7) * 0.42;
  h += ridged(p * 0.006 + w * 0.6) * 0.12 - 0.05;
  // A few long, irregular fractures instead of a crack network.
  float fr = abs(gnoise(p * 0.0045 + w * 2.5) + gnoise(p * 0.02) * 0.08);
  h -= smoothstep(0.04, 0.0, fr) * 0.035;
  float coral = coralMask(p, w);
  vec3 kv = voronoi(p * 0.09 + 1.7);
  h += coral * (0.03 + smoothstep(0.6, 0.0, kv.x) * 0.035);
  h += fbm3(p * 0.075) * 0.035 + fbm3(p * 0.16) * 0.012;
  vec3 sv = voronoi(p * 0.009 + 21.0);
  h += step(sv.z, 0.045) * smoothstep(0.27, 0.15, sv.x + fbm3(p * 0.04) * 0.2) * (0.07 + gnoise(p * 0.2) * 0.02);
  vec3 bv = voronoi(p * 0.034 + 9.7);
  float barn = step(bv.z, 0.55) * barnacleMask(p);
  h += barn * (0.11 * smoothstep(0.42, 0.14, bv.x) - 0.1 * smoothstep(0.13, 0.06, bv.x));
  // A domed body: rounded near the silhouette, full height inside.
  h += sqrt(smoothstep(-2.0, 280.0, sd)) * 1.5 - 0.55;
  float hd = holeField(p);
  h -= smoothstep(1.06, 0.5, hd) * 1.7;
  h += exp(-pow((hd - 1.1) * 5.0, 2.0)) * 0.1;
  return h;
}

float sandHeight(vec2 p, float sd) {
  // Seen from the side: crests run across the view, closer together far away (top).
  float y = max(sd, 0.0) + 6.0;
  float s = sqrt(y) * 1.15 + fbm3(vec2(p.x * 0.005, y * 0.012) + uSeed) * 3.2 + p.x * 0.002;
  float rip = pow(0.5 + 0.5 * sin(s * 3.14159), 1.6);
  float h = rip * 0.035 * smoothstep(0.0, 30.0, sd) * (0.6 + 0.8 * smoothstep(-0.2, 0.3, fbm3(p * 0.004 + 2.0)));
  h += fbm3(p * 0.006 + 4.0) * 0.18;
  h += gnoise(p * 0.8) * 0.004 + gnoise(p * 0.3) * 0.008;
  vec3 v = voronoi(p * 0.02 + 7.3);
  h += step(v.z, 0.03) * smoothstep(0.3, 0.1, v.x) * 0.1;
  h += sqrt(smoothstep(-2.0, 160.0, sd)) * 0.5;
  return h;
}
`;

const BAKE = COMMON + GEOMETRY + `
uniform vec2 uRes;
uniform float uScale;
void main() {
  vec2 p = vec2(gl_FragCoord.x, uRes.y - gl_FragCoord.y) / uScale;
  float sd = shapeSD(p);
  float h = uKind == 2 ? sandHeight(p, sd) : rockHeight(p, sd);
  float v = floor(clamp((h + 3.0) / 6.0, 0.0, 1.0) * 65535.0);
  float hd = uKind == 2 ? 2.0 : holeField(p);
  gl_FragColor = vec4(floor(v / 256.0) / 255.0, mod(v, 256.0) / 255.0, clamp(hd / 2.0, 0.0, 1.0), clamp(sd / 160.0 + 0.5, 0.0, 1.0));
}`;

const LIGHT = COMMON + GEOMETRY + `
uniform sampler2D uHeight;
uniform vec2 uRes;
uniform float uScale;
uniform int uPass;        // 0 colour, 1 caustic receptivity
uniform vec4 uFog;        // water tint and amount
const float K = 60.0;     // CSS px of relief per height unit
vec3 LS = normalize(vec3(-0.55, -0.78, 0.6));

float dec(vec4 t) { return (floor(t.r * 255.0 + 0.5) * 256.0 + floor(t.g * 255.0 + 0.5)) / 65535.0 * 6.0 - 3.0; }
vec2 uvOf(vec2 p) { return vec2(p.x, uBox.y - p.y) * uScale / uRes; }
float H(vec2 p) { return dec(texture2D(uHeight, uvOf(p))); }
float SD(vec2 p) { return (texture2D(uHeight, uvOf(p)).a - 0.5) * 160.0; }

void main() {
  vec2 uv = gl_FragCoord.xy / uRes;
  vec2 p = vec2(gl_FragCoord.x, uRes.y - gl_FragCoord.y) / uScale;
  vec4 T = texture2D(uHeight, uv);
  float h = dec(T);
  float holeD = T.b * 2.0;
  float sd = (T.a - 0.5) * 160.0;
  float px = 1.0 / uScale;
  vec3 n = normalize(vec3(-(H(p + vec2(px, 0.0)) - H(p - vec2(px, 0.0))) * K / (2.0 * px),
                          -(H(p + vec2(0.0, px)) - H(p - vec2(0.0, px))) * K / (2.0 * px), 1.0));

  // Soft shadow: march toward the sun across the height field.
  vec2 ldir = normalize(LS.xy);
  float rise = LS.z / length(LS.xy);
  float shadow = 1.0;
  for (int i = 1; i <= 22; i++) {
    float t = float(i) * 3.5;
    float ray = h * K + rise * t;
    float terr = H(p + ldir * t) * K;
    shadow = min(shadow, clamp(1.0 - (terr - ray) / (1.5 + t * 0.1), 0.0, 1.0));
  }

  // Ambient occlusion from two rings of height samples.
  float occ = 0.0;
  for (int i = 0; i < 14; i++) {
    float a = float(i) * 2.39996;
    float r = i < 7 ? 5.0 : 17.0;
    float hs = H(p + vec2(cos(a), sin(a)) * r);
    occ += clamp((hs - h) * K / r, 0.0, 1.0);
  }
  float ao = 1.0 - occ / 14.0 * (uKind == 2 ? 0.35 : 0.75);
  if (uKind == 2) shadow = mix(1.0, shadow, 0.35);

  float up = clamp(-n.y * 0.8 + n.z * 0.45, 0.0, 1.0);
  vec3 albedo;
  float wet;
  if (uKind == 2) {
    // Sand: warm base with subtle mineral grains and a few shell fragments.
    albedo = vec3(0.93, 0.85, 0.67) * (0.95 + 0.1 * fbm3(p * 0.008));
    float g = hash12(floor(p * 1.1));
    albedo *= 0.96 + 0.08 * hash12(floor(p * 2.0) + 3.0);
    albedo = mix(albedo, vec3(0.55, 0.49, 0.42), step(0.985, g) * 0.6);
    albedo = mix(albedo, vec3(1.0, 0.98, 0.95), step(0.95, g) * step(g, 0.975) * 0.5);
    albedo = mix(albedo, vec3(0.95, 0.72, 0.52), step(0.93, g) * step(g, 0.945) * 0.5);
    vec3 v = voronoi(p * 0.02 + 7.3);
    albedo = mix(albedo, vec3(0.98, 0.92, 0.88), step(v.z, 0.03) * smoothstep(0.28, 0.12, v.x));
    wet = 0.15;
  } else {
    // Rock: stone under olive turf algae, coralline crust, rare sponges and barnacle clusters.
    vec3 stone = mix(vec3(0.5, 0.46, 0.4), vec3(0.37, 0.39, 0.41), smoothstep(-0.3, 0.3, fbm(p * 0.0035 + uSeed)));
    stone *= 0.92 + 0.16 * fbm3(p * 0.04);
    albedo = stone;
    vec2 rw = rockWarp(p);
    albedo *= 1.0 - 0.28 * smoothstep(0.18, 0.36, fbm(p * 0.012 + 40.0));
    float turf = smoothstep(-0.16, 0.14, fbm(p * 0.007 + 7.0 + rw)) * smoothstep(0.1, 0.55, up);
    vec3 turfCol = mix(vec3(0.31, 0.4, 0.19), vec3(0.52, 0.52, 0.25), 0.5 + fbm3(p * 0.06));
    turfCol *= 0.88 + 0.24 * gnoise(p * 0.45);
    albedo = mix(albedo, turfCol, turf * 0.9);
    float cf = fbm(p * 0.0055 + uSeed * 3.0 + rw * 0.8);
    float coral = smoothstep(0.1, 0.13, cf) * (1.0 - turf * 0.6);
    float rim = smoothstep(0.1, 0.12, cf) * (1.0 - smoothstep(0.13, 0.17, cf));
    vec3 kv = voronoi(p * 0.09 + 1.7);
    vec3 crust = mix(vec3(0.68, 0.38, 0.52), vec3(0.88, 0.58, 0.68), 0.5 + fbm3(p * 0.05) * 1.3);
    crust *= 0.9 + 0.18 * smoothstep(0.5, 0.1, kv.x);
    crust = mix(crust, vec3(0.95, 0.82, 0.84), rim * 0.55);
    albedo = mix(albedo, crust, coral);
    vec3 sv = voronoi(p * 0.009 + 21.0);
    float sponge = step(sv.z, 0.045) * smoothstep(0.27, 0.21, sv.x + fbm3(p * 0.04) * 0.2);
    vec3 spongeCol = sv.z < 0.015 ? vec3(0.62, 0.36, 0.62) : sv.z < 0.03 ? vec3(0.98, 0.6, 0.22) : vec3(0.97, 0.83, 0.34);
    float pores = smoothstep(0.16, 0.08, voronoi(p * 0.22 + 5.0).x);
    albedo = mix(albedo, spongeCol * (0.9 + 0.2 * gnoise(p * 0.3)) * (1.0 - pores * 0.45), sponge);
    vec3 bv = voronoi(p * 0.034 + 9.7);
    float barn = step(bv.z, 0.55) * barnacleMask(p);
    albedo = mix(albedo, vec3(0.82, 0.8, 0.74), barn * smoothstep(0.42, 0.32, bv.x) * smoothstep(0.08, 0.14, bv.x));
    albedo = mix(albedo, vec3(0.1, 0.09, 0.08), barn * smoothstep(0.1, 0.06, bv.x));
    wet = (1.0 - turf) * (1.0 - coral * 0.5) * 0.6;
  }

  vec3 sun = vec3(1.0, 0.95, 0.84) * 1.15;
  vec3 sky = vec3(0.5, 0.76, 0.92) * 0.5;
  float diff = clamp((dot(n, LS) + 0.2) / 1.2, 0.0, 1.0);
  float hemi = 0.55 + 0.45 * dot(n, normalize(vec3(0.0, -0.6, 0.8)));
  vec3 col = albedo * (sun * diff * shadow + sky * hemi * ao) * mix(1.0, ao, 0.55);
  vec3 R = reflect(-LS, n);
  col += sun * pow(max(R.z, 0.0), mix(10.0, 36.0, wet)) * wet * 0.07 * shadow;
  col += vec3(0.9, 0.8, 0.6) * 0.05 * clamp(n.y, 0.0, 1.0) * albedo;

  // Crevices: dark and deep, lit only by a faint blue bounce.
  float inside = 1.0 - smoothstep(0.62, 0.98, holeD);
  vec3 cave = mix(vec3(0.03, 0.08, 0.12), vec3(0.008, 0.025, 0.04), smoothstep(0.9, 0.2, holeD));
  col = mix(col, cave, inside);

  col = mix(col, uFog.rgb, uFog.a);
  float alpha = smoothstep(-0.5, 1.2, sd);
  if (uKind == 2) alpha = smoothstep(-6.0, 14.0, sd);

  if (uPass == 1) {
    float recv = (uKind == 2 ? 1.0 : clamp(diff * 1.4, 0.0, 1.0) * shadow) * (1.0 - inside) * alpha;
    gl_FragColor = vec4(recv, 0.0, 0.0, 1.0);
    return;
  }
  // Soft contact shadow cast downward outside the silhouette.
  float shade = uKind == 2 ? 0.0 : 0.34 * smoothstep(-42.0, 2.0, SD(p - vec2(8.0, 18.0)));
  vec3 outCol = col * alpha;
  float outA = alpha + shade * (1.0 - alpha);
  gl_FragColor = vec4(outA > 0.0 ? outCol / outA : vec3(0.0), outA);
}`;

// Animated caustics, rendered at reduced resolution; they are soft enough to upsample.
const CAUSTIC = COMMON + `
uniform vec2 uRes;
uniform float uScale;     // texels per CSS px
uniform float uTime;
uniform float uCell;      // caustic cell size in CSS px
uniform float uSharp;     // caustic line sharpness
float cellLayer(vec2 p, float t) {
  vec2 i = floor(p); vec2 f = fract(p);
  float d1 = 8.0; float d2 = 8.0;
  for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
    vec2 g = vec2(float(x), float(y));
    vec2 o = 0.5 + 0.42 * sin(t * 0.8 + 6.2831 * hash22(i + g));
    vec2 r = g + o - f;
    float d = dot(r, r);
    if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
  }
  return exp(-(sqrt(d2) - sqrt(d1)) * uSharp);
}
void main() {
  vec2 p = vec2(gl_FragCoord.x, uRes.y - gl_FragCoord.y) / uScale / uCell;
  float t = uTime;
  vec2 w = vec2(gnoise(p * 0.42 + vec2(t * 0.07, 0.0)), gnoise(p * 0.42 + vec2(19.1, -t * 0.07)));
  float a = cellLayer(p + w * 0.6, t);
  float b = cellLayer(p * 1.6 + w * 0.9 + 7.3, t * 1.23);
  float c = pow(a * 0.55 + b * 0.35 + a * b * 1.1, 1.8);
  gl_FragColor = vec4(vec3(min(c, 1.0)), 1.0);
}`;

const COMPOSITE = COMMON + `
uniform sampler2D uBase;
uniform sampler2D uRecv;
uniform sampler2D uCausticMap;
uniform vec2 uRes;
uniform vec2 uSpread;     // chromatic offset in uv
uniform float uCaustic;   // strength
uniform float uTime;
void main() {
  vec2 uv = gl_FragCoord.xy / uRes;
  vec4 base = texture2D(uBase, uv);
  float recv = texture2D(uRecv, uv).r;
  vec3 c = vec3(texture2D(uCausticMap, uv + uSpread).r, texture2D(uCausticMap, uv).r, texture2D(uCausticMap, uv - uSpread).r);
  vec3 col = base.rgb + c * recv * uCaustic * vec3(1.0, 0.97, 0.88) * (0.35 + base.rgb * 0.9);
  col += (hash12(gl_FragCoord.xy + fract(uTime) * 37.0) - 0.5) / 255.0;
  gl_FragColor = vec4(col * base.a, base.a);
}`;

const VERT = 'attribute vec2 p; void main(){ gl_Position = vec4(p, 0.0, 1.0); }';

const KINDS = { wall: 0, boulder: 1, sand: 2 };

export function createSurface(host, { kind, pad, seed, fog, caustic, cell, sharp = 7, holes, mound }) {
  const canvas = document.createElement('canvas');
  canvas.className = 'material-canvas';
  canvas.setAttribute('aria-hidden', 'true');
  canvas.style.cssText = `position:absolute;left:${-pad}px;top:${-pad}px;width:calc(100% + ${pad * 2}px);height:calc(100% + ${pad * 2}px);pointer-events:none;`;
  const gl = canvas.getContext('webgl', { premultipliedAlpha: true, antialias: false });
  if (!gl) return null;

  const compile = (type, src) => {
    const s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
    return s;
  };
  const program = (frag) => {
    const pr = gl.createProgram();
    gl.attachShader(pr, compile(gl.VERTEX_SHADER, VERT));
    gl.attachShader(pr, compile(gl.FRAGMENT_SHADER, frag));
    gl.bindAttribLocation(pr, 0, 'p');
    gl.linkProgram(pr);
    if (!gl.getProgramParameter(pr, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(pr));
    const cache = {};
    return { pr, u: (n) => (cache[n] ??= gl.getUniformLocation(pr, n)) };
  };
  let bake, light, caus, comp;
  try {
    bake = program(BAKE);
    light = program(LIGHT);
    caus = program(CAUSTIC);
    comp = program(COMPOSITE);
  } catch (err) {
    console.error(err);
    return null;
  }
  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
  gl.disable(gl.BLEND);

  const target = () => {
    const tex = gl.createTexture();
    const fbo = gl.createFramebuffer();
    return { tex, fbo };
  };
  const height = target(), base = target(), recv = target(), light2 = target();
  const CAUSTIC_SCALE = 0.5;
  let W = 0, H = 0, CW = 0, CH = 0, box = null, scale = 1, ready = false;

  function alloc({ tex, fbo }, w = W, h = H, filter = gl.NEAREST) {
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);
  }

  function setGeometry(p, box) {
    gl.uniform2f(p.u('uBox'), box.w, box.h);
    gl.uniform1f(p.u('uPad'), pad);
    gl.uniform1f(p.u('uSeed'), seed);
    gl.uniform1i(p.u('uKind'), KINDS[kind]);
    gl.uniform2f(p.u('uRes'), W, H);
    gl.uniform1f(p.u('uScale'), scale);
    const list = holes ? holes() : [];
    const data = new Float32Array(48);
    list.slice(0, 12).forEach((h, i) => data.set([h.x + pad, h.y + pad, h.rx, h.ry], i * 4));
    gl.uniform4fv(p.u('uHoles'), data);
    gl.uniform1f(p.u('uHoleCount'), Math.min(12, list.length));
    gl.uniform1f(p.u('uMound'), mound ? mound() : 0.5);
  }

  // Bake and light once for the current size.
  function build() {
    const r = host.getBoundingClientRect();
    if (!r.width || !r.height) return;
    box = { w: r.width + pad * 2, h: r.height + pad * 2 };
    // Keep the static passes affordable on very large or very dense screens.
    scale = Math.min(devicePixelRatio || 1, 2, Math.sqrt(3_200_000 / (box.w * box.h)));
    W = Math.round(box.w * scale);
    H = Math.round(box.h * scale);
    canvas.width = W;
    canvas.height = H;
    [height, base, recv].forEach((t) => alloc(t));
    CW = Math.max(1, Math.round(box.w * CAUSTIC_SCALE));
    CH = Math.max(1, Math.round(box.h * CAUSTIC_SCALE));
    alloc(light2, CW, CH, gl.LINEAR);
    gl.viewport(0, 0, W, H);

    gl.useProgram(bake.pr);
    setGeometry(bake, box);
    gl.bindFramebuffer(gl.FRAMEBUFFER, height.fbo);
    gl.drawArrays(gl.TRIANGLES, 0, 3);

    gl.useProgram(light.pr);
    setGeometry(light, box);
    gl.uniform4f(light.u('uFog'), fog[0], fog[1], fog[2], fog[3]);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, height.tex);
    gl.uniform1i(light.u('uHeight'), 0);
    for (const [pass, t] of [[0, base], [1, recv]]) {
      gl.uniform1i(light.u('uPass'), pass);
      gl.bindFramebuffer(gl.FRAMEBUFFER, t.fbo);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
    }
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    ready = true;
  }

  function render(time) {
    if (!ready) return;
    // 1. Caustic light at half CSS resolution.
    gl.useProgram(caus.pr);
    gl.bindFramebuffer(gl.FRAMEBUFFER, light2.fbo);
    gl.viewport(0, 0, CW, CH);
    gl.uniform2f(caus.u('uRes'), CW, CH);
    gl.uniform1f(caus.u('uScale'), CAUSTIC_SCALE);
    gl.uniform1f(caus.u('uTime'), time);
    gl.uniform1f(caus.u('uCell'), cell);
    gl.uniform1f(caus.u('uSharp'), sharp);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    // 2. Composite over the lit base.
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.useProgram(comp.pr);
    gl.viewport(0, 0, W, H);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, base.tex);
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, recv.tex);
    gl.activeTexture(gl.TEXTURE2);
    gl.bindTexture(gl.TEXTURE_2D, light2.tex);
    gl.uniform1i(comp.u('uBase'), 0);
    gl.uniform1i(comp.u('uRecv'), 1);
    gl.uniform1i(comp.u('uCausticMap'), 2);
    gl.uniform2f(comp.u('uRes'), W, H);
    gl.uniform2f(comp.u('uSpread'), 1.4 / box.w, 0);
    gl.uniform1f(comp.u('uCaustic'), caustic);
    gl.uniform1f(comp.u('uTime'), time);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  }

  host.prepend(canvas);
  host.classList.add('has-material');
  return { host, canvas, build, render };
}

// Holes are read from DOM children so the carved crevices always match the
// elements that hold the blenny and the landed icons.
export function holesFrom(host, selector, shrink = 1) {
  return () => {
    const hr = host.getBoundingClientRect();
    return [...document.querySelectorAll(selector)].map((el) => {
      const r = el.getBoundingClientRect();
      return { x: r.left - hr.left + r.width / 2, y: r.top - hr.top + r.height / 2, rx: (r.width / 2) * shrink, ry: (r.height / 2) * shrink };
    });
  };
}

export function createMaterials({ reduceMotion }) {
  const specs = [
  ];
  const surfaces = [];
  for (const spec of specs) {
    const host = document.querySelector(spec.selector);
    if (!host) continue;
    const surface = createSurface(host, { ...spec, holes: spec.holes?.(host), mound: spec.mound?.(host) });
    if (!surface) continue;
    surface.visible = false;
    surfaces.push(surface);
  }

  // Build shortly before a surface scrolls into view; animate only while it is on screen.
  const buildIO = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      const s = surfaces.find((x) => x.host === e.target);
      if (s && e.isIntersecting && !s.built) { s.build(); s.built = true; s.render(0); }
    });
  }, { rootMargin: '80% 0px' });
  const showIO = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      const s = surfaces.find((x) => x.host === e.target);
      if (s) s.visible = e.isIntersecting;
    });
  });
  surfaces.forEach((s) => { buildIO.observe(s.host); showIO.observe(s.host); });

  let timer = 0, frame = 0;
  const rebuild = () => {
    clearTimeout(timer);
    timer = setTimeout(() => surfaces.forEach((s) => {
      if (s.built) { s.build(); s.render(0); }
    }), 180);
  };
  surfaces.forEach((s) => new ResizeObserver(rebuild).observe(s.host));

  return {
    render(t) {
      // Caustics read fine at 30 fps; skip every other frame.
      if (reduceMotion || (frame++ & 1)) return;
      surfaces.forEach((s) => { if (s.visible && s.built) s.render(t); });
    },
  };
}
