// Animated caustic light over the illustrated sand. Each canvas is masked to its
// sand in CSS, so the light only falls on sand. The pattern lives in hero
// coordinates, so the sand bank and the rock's own sand heap share one field of
// light. It renders at half resolution, at 30 fps, and only while on screen.

const FRAGMENT = `
precision highp float;
uniform vec2 uRes;
uniform float uScale;   // canvas pixels per CSS pixel
uniform float uTime;
uniform float uCell;    // caustic cell size in CSS px
uniform float uSharp;   // line sharpness
uniform float uAmount;
uniform vec2 uOffset;   // canvas origin in hero CSS px
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
  vec2 css = vec2(gl_FragCoord.x, uRes.y - gl_FragCoord.y) / uScale + uOffset;
  // Seen from the side, the light pattern on the sand is squashed vertically.
  vec2 p = css / uCell * vec2(1.0, 1.8);
  float t = uTime;
  vec2 w = vec2(gnoise(p * 0.42 + vec2(t * 0.07, 0.0)), gnoise(p * 0.42 + vec2(19.1, -t * 0.07)));
  float a = cellLayer(p + w * 0.6, t);
  float b = cellLayer(p * 1.6 + w * 0.9 + 7.3, t * 1.23);
  float c = clamp(pow(a * 0.55 + b * 0.35 + a * b * 1.1, 1.8), 0.0, 1.0) * uAmount;
  gl_FragColor = vec4(vec3(1.0, 0.97, 0.86) * c, c);
}`;

const VERTEX = 'attribute vec2 p; void main(){ gl_Position = vec4(p, 0.0, 1.0); }';
const SCALE = 0.5;

export function createSandCaustics(canvas, { amount = 0.42, cell = 78, sharp = 6, reduceMotion = false } = {}) {
  const gl = canvas.getContext('webgl', { premultipliedAlpha: true, antialias: false });
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
  gl.uniform1f(u('uScale'), SCALE);
  gl.uniform1f(u('uCell'), cell);
  gl.uniform1f(u('uSharp'), sharp);
  gl.uniform1f(u('uAmount'), amount);
  const uRes = u('uRes'), uTime = u('uTime'), uOffset = u('uOffset');

  let visible = false, frame = 0;
  new IntersectionObserver(([e]) => { visible = e.isIntersecting; }).observe(canvas);

  function draw(t) {
    gl.uniform1f(uTime, t);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  }

  return {
    // Called by the dive whenever it lays out the hero: size and origin in hero CSS px.
    resize(w, h, x = 0, y = 0) {
      gl.uniform2f(uOffset, x, y);
      canvas.width = Math.max(1, Math.round(w * SCALE));
      canvas.height = Math.max(1, Math.round(h * SCALE));
      gl.viewport(0, 0, canvas.width, canvas.height);
      gl.uniform2f(uRes, canvas.width, canvas.height);
      draw(0);
    },
    render(t) {
      if (reduceMotion || !visible || (frame++ & 1)) return;
      draw(t);
    },
  };
}
