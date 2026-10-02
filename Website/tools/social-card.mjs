// Builds the social preview card (GitHub social preview and the site's
// og:image) from the illustrated background, the site's own type and the
// site's menu bar glyphs, then renders it with headless Chrome.
//
//   node tools/social-card.mjs BACKGROUND.png OUT_DIR
//
// Lays the card out natively at each size it is used at, so nothing is cropped:
// 1280 × 640 for the GitHub social preview and 1200 × 630 for the site's
// og:image. Each renders at 2x as OUT_DIR/blenny-social-WxH@2x.png, next to the
// page that was rendered. Fonts load from Google Fonts, so the machine needs
// network access.

import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { basename, join, resolve } from 'node:path';
import { glyphs, blennyMark } from '../site/assets/js/glyphs.js';

const [bgArg, outArg] = process.argv.slice(2);
if (!bgArg || !outArg) {
  console.error('usage: node tools/social-card.mjs BACKGROUND.png OUT_DIR');
  process.exit(64);
}
const out = resolve(outArg);
mkdirSync(out, { recursive: true });
copyFileSync(resolve(bgArg), join(out, 'social-background.png'));

const svg = (g) => `<svg viewBox="0 0 24 24" width="15" height="15" fill="currentColor" stroke-linecap="round" stroke-linejoin="round">${g.body}</svg>`;
const byId = Object.fromEntries(glyphs.map((g) => [g.id, g]));
// A calm, managed menu bar: Blenny's arrow and fish, then a few Visible items.
const tray = ['wifi', 'battery', 'search', 'input'].map((id) => `<span class="item">${svg(byId[id])}</span>`).join('');

const card = (W, H) => `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,400..700&family=Fraunces:ital,opsz,wght,SOFT,WONK@0,9..144,300..600,0..100,0..1;1,9..144,300..600,0..100,0..1&family=Martian+Mono:wdth,wght@87.5..112.5,400..500&display=block">
<style>
  * { box-sizing: border-box; margin: 0; }
  html, body { width: ${W}px; height: ${H}px; overflow: hidden; }
  body { position: relative; background: #1d8fc0 url(social-background.png) left center / cover no-repeat; color: #032a42; -webkit-font-smoothing: antialiased; }
  /* A soft wash keeps the text side calm without hiding the light rays. */
  body::before { content: ""; position: absolute; inset: 0; background: linear-gradient(90deg, rgba(160, 232, 246, 0.42), rgba(160, 232, 246, 0.18) 42%, rgba(160, 232, 246, 0) 62%); }
  .menubar { position: absolute; left: 0; right: 0; top: 0; height: 34px; display: flex; align-items: center; gap: 6px; padding: 0 16px;
    font: 500 14px/1 -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif; color: #0b1d2a;
    background: rgba(248, 253, 255, 0.55); backdrop-filter: blur(22px) saturate(1.6); box-shadow: 0 1px 0 rgba(255, 255, 255, 0.5), 0 10px 30px rgba(0, 50, 80, 0.12); }
  .app { display: flex; align-items: center; gap: 8px; font-weight: 700; }
  .app svg { color: #e8601f; }
  .menus { display: flex; gap: 18px; margin-left: 18px; opacity: 0.85; }
  .right { margin-left: auto; display: flex; align-items: center; gap: 14px; }
  .item { display: grid; place-items: center; width: 18px; }
  .fish { display: grid; place-items: center; width: 30px; height: 24px; border-radius: 6px; color: #e8601f; background: rgba(255, 139, 53, 0.22); }
  .chev svg { display: block; }
  .clock { margin-left: 4px; font-variant-numeric: tabular-nums; }
  .copy { position: absolute; left: ${Math.round(W * 0.072)}px; top: ${Math.round(H * 0.231)}px; width: 560px; }
  .eyebrow { font: 500 15px/1.3 "Martian Mono", monospace; font-stretch: 87.5%; letter-spacing: 0.16em; text-transform: uppercase; color: #045683; }
  .eyebrow b { font-weight: 500; color: #d9541a; }
  h1 { margin-top: 18px; font: 360 152px/0.86 "Fraunces", serif; font-variation-settings: "SOFT" 100, "WONK" 1; letter-spacing: -0.035em; }
  .tag { margin-top: 26px; font: 360 50px/1 "Fraunces", serif; font-variation-settings: "SOFT" 100, "WONK" 1; letter-spacing: -0.025em; }
  .tag em { font-weight: 300; color: #fff; text-shadow: 0 0 34px rgba(255, 255, 255, 0.75); }
  .meta { margin-top: 30px; font: 500 15px/1.4 "Martian Mono", monospace; font-stretch: 87.5%; letter-spacing: 0.1em; color: rgba(3, 42, 66, 0.78); }
</style></head>
<body>
  <div class="menubar">
    <span class="app">${blennyMark(17)}Blenny</span>
    <span class="menus"><span>Features</span><span>How it works</span><span>Safety</span></span>
    <span class="right">
      <span class="chev"><svg viewBox="0 0 16 16" width="13" height="13"><path d="M3.5 3.5L8 8l-4.5 4.5M8.5 3.5L13 8l-4.5 4.5" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/></svg></span>
      <span class="fish">${blennyMark(17)}</span>
      ${tray}
      <span class="clock">Fri 9:41 AM</span>
    </span>
  </div>
  <div class="copy">
    <p class="eyebrow">Menu bar organizer · <b>Only for macOS 27</b></p>
    <h1>Blenny</h1>
    <p class="tag">Too much at the <em>surface.</em></p>
    <p class="meta">Free &amp; open source · Surface, Reef, Deep</p>
  </div>
</body></html>`;

const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
for (const [W, H] of [[1280, 640], [1200, 630]]) {
  const page = join(out, `social-card-${W}x${H}.html`);
  writeFileSync(page, card(W, H));
  const png = join(out, `blenny-social-${W}x${H}@2x.png`);
  execFileSync(chrome, [
    '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=2',
    `--window-size=${W},${H}`, '--virtual-time-budget=8000', `--screenshot=${png}`, `file://${page}`,
  ], { stdio: 'inherit' });
  console.log(`wrote ${basename(png)}`);
}
