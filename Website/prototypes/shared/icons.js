// Generic, invented menu bar glyphs for the website prototypes.
// None of these represent a real third-party product.
(function () {
  const glyphs = [
    { id: 'wifi', name: 'Wi-Fi', intent: 'visible', body: '<path d="M3 9a13 13 0 0 1 18 0M6 12.5a8.5 8.5 0 0 1 12 0M9 16a4 4 0 0 1 6 0"/><circle cx="12" cy="19.2" r="1.1" fill="currentColor" stroke="none"/>' },
    { id: 'battery', name: 'Battery', intent: 'visible', body: '<rect x="2.5" y="7" width="17" height="10" rx="2.5"/><path d="M22 10.5v3"/><rect x="5" y="9.5" width="9" height="5" rx="1" fill="currentColor" stroke="none"/>' },
    { id: 'search', name: 'Search', intent: 'visible', body: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>' },
    { id: 'input', name: 'Input', intent: 'visible', body: '<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M8.5 16l3.5-9 3.5 9M9.8 13h4.4"/>' },
    { id: 'sun', name: 'Weatherly', intent: 'visible', body: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>' },
    { id: 'cloud', name: 'Driftbox', intent: 'revealable', body: '<path d="M7 18h10a4 4 0 0 0 .6-7.95A6 6 0 0 0 6.2 9.2 4.5 4.5 0 0 0 7 18z"/>' },
    { id: 'music', name: 'Tidal Radio', intent: 'revealable', body: '<path d="M9 18V5l11-2v13"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="17.5" cy="16" r="2.5"/>' },
    { id: 'clip', name: 'Clipshell', intent: 'revealable', body: '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V3h6v1M8.5 10h7M8.5 14h7M8.5 18h4"/>' },
    { id: 'timer', name: 'Pomodoro', intent: 'revealable', body: '<circle cx="12" cy="13" r="8"/><path d="M12 13V9M10 2h4M19 6l1.5-1.5"/>' },
    { id: 'chat', name: 'Chatter', intent: 'revealable', body: '<path d="M4 5h16v11H9l-5 4z"/>' },
    { id: 'coffee', name: 'Awake', intent: 'revealable', body: '<path d="M4 9h13v5a5 5 0 0 1-5 5H9a5 5 0 0 1-5-5z"/><path d="M17 11h1.5a2.5 2.5 0 0 1 0 5H17M8 3v3M12 3v3"/>' },
    { id: 'plane', name: 'Sendit', intent: 'revealable', body: '<path d="M22 2L11 13M22 2l-7 20-4-9-9-4z"/>' },
    { id: 'bolt', name: 'Zap Tools', intent: 'revealable', body: '<path d="M13 2L4 14h7l-1 8 9-12h-7z"/>' },
    { id: 'shield', name: 'Tunnel VPN', intent: 'hidden', body: '<path d="M12 3l8 3v5c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6z"/><path d="M9 12l2 2 4-4"/>' },
    { id: 'graph', name: 'Load Meter', intent: 'hidden', body: '<path d="M3 17l4-5 4 3 4-7 6 6"/><path d="M3 21h18"/>' },
    { id: 'eye', name: 'Watcher', intent: 'hidden', body: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>' },
    { id: 'bell', name: 'Nudge', intent: 'hidden', body: '<path d="M6 16V11a6 6 0 0 1 12 0v5l2 2H4z"/><path d="M10 20a2 2 0 0 0 4 0"/>' },
    { id: 'disk', name: 'Diskette', intent: 'hidden', body: '<ellipse cx="12" cy="6" rx="8" ry="3"/><path d="M4 6v12c0 1.7 3.6 3 8 3s8-1.3 8-3V6M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3"/>' },
  ];

  function svg(glyph, size = 16, strokeWidth = 1.9) {
    return `<svg viewBox="0 0 24 24" width="${size}" height="${size}" fill="none" stroke="currentColor" stroke-width="${strokeWidth}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${glyph.body}</svg>`;
  }

  // Blenny's production face-silhouette menu bar template (Assets/MenuBar).
  const blennyGlyph = `<svg viewBox="1.5 -0.1 21 21" width="16" height="16" aria-hidden="true"><path fill="currentColor" fill-rule="evenodd" d="M3 12.8C2.6 9.4 4.6 7 7.1 6.2C9.8 5.25 14.2 5.25 16.9 6.2C19.4 7 21.4 9.4 21 12.8C20.8 16.35 17.65 18.25 12 18.25C6.35 18.25 3.2 16.35 3 12.8Z M3.9 11.15A2.25 3.1 0 1 0 8.4 11.15A2.25 3.1 0 1 0 3.9 11.15Z M15.6 11.15A2.25 3.1 0 1 0 20.1 11.15A2.25 3.1 0 1 0 15.6 11.15Z"/><g fill="none" stroke="currentColor" stroke-width="1.45" stroke-linecap="round" stroke-linejoin="round"><path d="M7.5 7L7.15 3.25M7.25 4.85L5.45 3.5M7.25 4.85L8.8 3.3"/><path d="M16.5 7L16.85 3.25M16.75 4.85L18.55 3.5M16.75 4.85L15.2 3.3"/></g><g fill="currentColor"><ellipse cx="6.85" cy="11.2" rx="0.95" ry="1.6"/><ellipse cx="17.15" cy="11.2" rx="0.95" ry="1.6"/></g></svg>`;

  // Rasterize a glyph for canvas drawing.
  function image(glyph, color = '#fff', size = 64, strokeWidth = 1.9) {
    const markup = svg(glyph, size, strokeWidth).replace('<svg ', `<svg xmlns="http://www.w3.org/2000/svg" color="${color}" `);
    const img = new Image();
    img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(markup);
    return img;
  }

  function clock() {
    const d = new Date();
    const day = d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
    const time = d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
    return `${day}  ${time}`;
  }

  window.MenuGlyphs = { glyphs, svg, image, blennyGlyph, clock };
})();
