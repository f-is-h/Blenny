// Menu bar items for invented apps, drawn like real macOS menu bar extras:
// compact, mostly solid template glyphs, and a few text items. None of them
// represents a real product, except one easter egg: Usage4Claude, a sibling
// app by Blenny's own developer. `text` is shown beside the glyph in the menu
// bar; `w` is that item's width there. `icon` names the app's own icon in
// assets/img/apps/, shown wherever the app itself is meant rather than its
// menu bar item: in its reef crevice, in the deep and in the Organize demo.
const L = 'stroke="currentColor" fill="none"';

export const glyphs = [
  // The real sibling app: its own template icon in the menu bar, its app icon in
  // the Organize demo, and an easter egg in the reef.
  { id: 'u4c', name: 'Usage4Claude', area: 'surface', mask: 'assets/img/usage4claude-mark.png', img: 'assets/img/usage4claude-128.png', url: 'https://u4c.fi5h.xyz/' },
  { id: 'wifi', name: 'Wi-Fi', area: 'surface', body: `<path ${L} stroke-width="2.4" d="M3.4 9.4a12.4 12.4 0 0 1 17.2 0M6.5 12.6a7.9 7.9 0 0 1 11 0M9.5 15.7a3.7 3.7 0 0 1 5 0"/><circle cx="12" cy="19.4" r="1.7"/>` },
  { id: 'battery', name: 'Battery', area: 'surface', body: `<rect ${L} stroke-width="1.6" x="2" y="7" width="18" height="10" rx="3"/><rect x="4.1" y="9.1" width="10.6" height="5.8" rx="1.5"/><path ${L} stroke-width="1.9" d="M21.7 10.3v3.4"/>` },
  { id: 'search', name: 'Search', area: 'surface', body: `<circle ${L} stroke-width="2.4" cx="10.4" cy="10.4" r="6.1"/><path ${L} stroke-width="2.7" d="M15 15l5.2 5.2"/>` },
  { id: 'input', name: 'Input', area: 'surface', body: `<rect ${L} stroke-width="1.7" x="3" y="3.5" width="18" height="17" rx="4"/><path ${L} stroke-width="2.1" d="M8.2 16.4L12 7.2l3.8 9.2M9.6 13.3h4.8"/>` },
  { id: 'sun', icon: 'brightwater', name: 'Brightwater', area: 'surface', text: '72°', w: 54, body: `<circle cx="12" cy="12" r="4.4"/><path ${L} stroke-width="2.1" d="M12 2.6v2.2M12 19.2v2.2M2.6 12h2.2M19.2 12h2.2M5.4 5.4l1.5 1.5M17.1 17.1l1.5 1.5M5.4 18.6l1.5-1.5M17.1 6.9l1.5-1.5"/>` },
  { id: 'cloud', icon: 'tidecloud', name: 'Tidecloud', area: 'reef', body: `<path d="M7.1 19.2h10.1a4.4 4.4 0 0 0 .8-8.7A6.3 6.3 0 0 0 6.1 9.4a4.9 4.9 0 0 0 1 9.8z"/>` },
  { id: 'music', icon: 'seafoam-radio', name: 'Seafoam Radio', area: 'reef', body: `<path ${L} stroke-width="2.1" d="M9.2 17.3V5.7l10.6-2.2v11.4"/><path ${L} stroke-width="2.1" d="M9.2 9l10.6-2.2"/><ellipse cx="6.5" cy="17.6" rx="3" ry="2.6"/><ellipse cx="17.1" cy="15.2" rx="3" ry="2.6"/>` },
  { id: 'clip', icon: 'clipshell', name: 'Clipshell', area: 'reef', body: `<path ${L} stroke-width="1.8" d="M8.5 5H6.8A1.8 1.8 0 0 0 5 6.8v12.4A1.8 1.8 0 0 0 6.8 21h10.4a1.8 1.8 0 0 0 1.8-1.8V6.8A1.8 1.8 0 0 0 17.2 5h-1.7"/><rect x="8.3" y="2.8" width="7.4" height="4.2" rx="1.4"/><path ${L} stroke-width="1.8" d="M8.6 11.5h6.8M8.6 15.2h4.6"/>` },
  { id: 'timer', icon: 'kelp-timer', name: 'Kelp Timer', area: 'reef', text: '24:58', w: 66, body: `<circle ${L} stroke-width="2.1" cx="12" cy="13.3" r="7.6"/><path d="M12 13.3V7.5a5.8 5.8 0 0 1 5.4 3.7z"/><path ${L} stroke-width="2.1" d="M9.6 2.8h4.8M18.7 5.4l1.4-1.4"/>` },
  { id: 'chat', icon: 'shoal-chat', name: 'Shoal Chat', area: 'reef', body: `<path d="M6.3 3.4h11.4a2.6 2.6 0 0 1 2.6 2.6v8.1a2.6 2.6 0 0 1-2.6 2.6h-7.2l-4.6 3.9v-3.9a2.6 2.6 0 0 1-2.2-2.6V6a2.6 2.6 0 0 1 2.6-2.6z"/>` },
  { id: 'coffee', icon: 'stay-up', name: 'Stay Up', area: 'reef', body: `<path d="M3.8 8.6h12.8v5.2a5.4 5.4 0 0 1-5.4 5.4H9.2a5.4 5.4 0 0 1-5.4-5.4z"/><path ${L} stroke-width="1.9" d="M16.6 10.4h1.3a2.6 2.6 0 0 1 0 5.2h-1.6M8 2.6v3M11.8 2.6v3"/>` },
  { id: 'plane', icon: 'gull-send', name: 'Gull Send', area: 'reef', body: `<path d="M21.6 2.4L2.6 10.1l7.1 2.7z"/><path d="M21.6 2.4l-9.3 11.1 2.4 7.6z"/>` },
  { id: 'bolt', icon: 'eel-tools', name: 'Eel Tools', area: 'reef', body: `<path d="M13.8 1.8L4.4 13.6h6.7L9.9 22.2l9.7-12.3h-6.8z"/>` },
  { id: 'shield', icon: 'burrow-vpn', name: 'Burrow VPN', area: 'deep', body: `<path fill-rule="evenodd" d="M12 2.6l7.8 3v5.5c0 5-3.3 8.6-7.8 10.3-4.5-1.7-7.8-5.3-7.8-10.3V5.6zM8.6 11.6l-1.3 1.3 3.3 3.3 6.1-6.1-1.3-1.3-4.8 4.8z"/>` },
  { id: 'graph', icon: 'sonar-stats', name: 'Sonar Stats', area: 'deep', text: '12%', w: 52, body: `<rect x="3" y="12.5" width="4" height="8" rx="1.2"/><rect x="10" y="7.5" width="4" height="13" rx="1.2"/><rect x="17" y="3.5" width="4" height="17" rx="1.2"/>` },
  { id: 'eye', icon: 'lookout', name: 'Lookout', area: 'deep', body: `<path fill-rule="evenodd" d="M1.8 12S5.5 5.2 12 5.2 22.2 12 22.2 12 18.5 18.8 12 18.8 1.8 12 1.8 12zM12 8.4a3.6 3.6 0 1 0 0 7.2 3.6 3.6 0 0 0 0-7.2z"/><circle cx="12" cy="12" r="1.7"/>` },
  { id: 'bell', icon: 'buoy-alerts', name: 'Buoy Alerts', area: 'deep', body: `<path d="M12 2.6a1.4 1.4 0 0 1 1.4 1.4v.6a6.2 6.2 0 0 1 4.8 6v4.6l2 2.6v.9H3.8v-.9l2-2.6v-4.6a6.2 6.2 0 0 1 4.8-6V4A1.4 1.4 0 0 1 12 2.6z"/><path d="M9.6 19.9h4.8a2.4 2.4 0 0 1-4.8 0z"/>` },
  { id: 'disk', icon: 'ballast-disk', name: 'Ballast Disk', area: 'deep', body: `<ellipse cx="12" cy="5.6" rx="8" ry="2.9"/><path d="M4 8.4v3.3c0 1.6 3.6 2.9 8 2.9s8-1.3 8-2.9V8.4c-1.6 1.3-4.6 2-8 2s-6.4-.7-8-2z"/><path d="M4 14.2v3.6c0 1.6 3.6 2.9 8 2.9s8-1.3 8-2.9v-3.6c-1.6 1.3-4.6 2-8 2s-6.4-.7-8-2z"/>` },
];

export const AREAS = {
  surface: { name: 'Surface', role: 'Always visible' },
  reef: { name: 'Reef', role: 'Shown on reveal' },
  deep: { name: 'Deep', role: 'Always hidden' },
};

export const appIcon = (g, size = 30, cls = 'app-icon') =>
  `<img class="${cls}" src="assets/img/apps/${g.icon}.webp" alt="" width="${size}" height="${size}" draggable="false">`;

// Glyph bodies are solid by default; outlined parts carry their own stroke.
export function glyphSVG(glyph, size = 16) {
  // A template image takes the menu bar's text colour, like an NSImage template.
  // The URL is made absolute: inside a custom property it would otherwise
  // resolve against the stylesheet rather than the page.
  if (glyph.mask) return `<span class="glyph-mask" style="--mask:url('${new URL(glyph.mask, document.baseURI).href}');width:${size}px;height:${size}px"></span>`;
  if (glyph.img) return `<img class="glyph-img" src="${glyph.img}" alt="" width="${size}" height="${size}" draggable="false">`;
  return `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${glyph.body}</svg>`;
}

// Blenny's production menu bar template (Assets/MenuBar/BlennyMenuBarTemplate.svg).
export const BLENNY_BODY = 'M3 12.8C2.6 9.4 4.6 7 7.1 6.2C9.8 5.25 14.2 5.25 16.9 6.2C19.4 7 21.4 9.4 21 12.8C20.8 16.35 17.65 18.25 12 18.25C6.35 18.25 3.2 16.35 3 12.8Z M3.9 11.15A2.25 3.1 0 1 0 8.4 11.15A2.25 3.1 0 1 0 3.9 11.15Z M15.6 11.15A2.25 3.1 0 1 0 20.1 11.15A2.25 3.1 0 1 0 15.6 11.15Z';
export const BLENNY_FEELERS = 'M7.5 7L7.15 3.25M7.25 4.85L5.45 3.5M7.25 4.85L8.8 3.3M16.5 7L16.85 3.25M16.75 4.85L18.55 3.5M16.75 4.85L15.2 3.3';
export const blennyMark = (size = 16) => `<svg viewBox="1.5 -0.1 21 21" width="${size}" height="${size}" aria-hidden="true"><path fill="currentColor" fill-rule="evenodd" d="${BLENNY_BODY}"/><path fill="none" stroke="currentColor" stroke-width="1.45" stroke-linecap="round" stroke-linejoin="round" d="${BLENNY_FEELERS}"/><g fill="currentColor"><ellipse cx="6.85" cy="11.2" rx="0.95" ry="1.6"/><ellipse cx="17.15" cy="11.2" rx="0.95" ry="1.6"/></g></svg>`;

export function clockText(date = new Date()) {
  const day = date.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
  const time = date.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
  return `${day}  ${time}`;
}
