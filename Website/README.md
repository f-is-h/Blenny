# Blenny website

Source for the Blenny product website at `https://blenny.fi5h.xyz`, the address
the app already opens from its Website menu item. The site is served by
Cloudflare Workers static assets.

The website is a separate deliverable from the macOS application. Nothing in
this directory is built, linked, or packaged by the Swift package.

## Layout

```
Website/
├── README.md
├── wrangler.jsonc         Cloudflare Workers static-assets configuration
├── site/                  Production site, deployed as-is with no build step
│   ├── index.html         The single-page dive, 0 to 60 m
│   ├── 404.html           Served for unknown paths
│   ├── _headers           Security and cache headers applied by Cloudflare
│   ├── robots.txt, sitemap.xml, llms.txt, apple-touch-icon.png
│   └── assets/
│       ├── css/site.css
│       ├── img/           App icon derivatives; scene/ holds the layered hero and reef art
│       └── js/            ES modules, one per concern (see below)
├── art/                   Production sources for the illustrated art (not deployed)
├── tools/scene_assets.py  Clean generated PNGs and locate transparent holes
├── tools/social-card.mjs  Render the social preview card with headless Chrome
└── prototypes/            Direction sketches kept for reference; not deployed
    └── material-lab/      Procedural rock and sand materials (materials.js) and a GPU benchmark; not used by the site
```

JavaScript modules in `site/assets/js/`:

| Module | Responsibility |
| --- | --- |
| `main.js` | Entry point; wires everything and runs the single animation loop |
| `sea.js` | Full-screen WebGL water: depth colour, light shafts, surface ripples, particles with depth of field, the Deep's torch |
| `caustics.js` | Animated caustic light on the sand bank and the hero rock's sand heap, one continuous field masked to the sand |
| `kelp.js` | Procedural kelp strands with swaying stipes and fluttering blades |
| `life.js` | Canvas life: fish schools in the shallows (they outline the Blenny mark around a resting pointer), a manta, jellyfish and bioluminescent plankton in the deep, bubbles |
| `breach.js` | The surface breach that ends the ascent back to the top |
| `release.js` | Points the download links at the latest release's disk image |
| `audio.js` | Synthesised sound: depth-following ambience and small effects, off until the visitor turns it on |
| `dive.js` | Sinking menu bar icons, the depth gauge, the reveal session and the reef easter egg |
| `board.js` | Interactive Organize window demo: drag, context menu, Apply, Undo |
| `motion.js` | Headline and section entrance animations, magnetic buttons, headlines that waver like seen through water under the pointer |
| `sprite-blenny.js` | The rendered Blenny: base, blink and excited frames with vector pupils that follow the pointer |
| `glyphs.js` | Invented apps and their menu bar items (solid template glyphs, some with text), area names and the Blenny mark |
| `lost.js` | The 404 page's blenny |

## Content rules

- The depth scale follows the blenny's real habitat: combtooth blennies live
  in shallow, often intertidal water and become scarce with depth. Surface,
  Reef and Deep map to the app's areas: Surface (Always visible), Reef (Shown
  on reveal) and Deep (Always hidden).
- Product claims must match `README.md`, `PROJECT_BRIEF.md`, the release notes
  and the current release record. Update the site when those change,
  especially platform, tested build, limitations and install steps.
- Download links (`data-download`) point to the GitHub Releases page in the
  HTML. `release.js` asks the GitHub API for the latest release once per session
  and swaps in its `.dmg`, so new versions need no site change; if the lookup
  fails the Releases page still works. `_headers` allows `api.github.com` in
  `connect-src` for this. The links work only once the repository and the
  release are public, so deploy the site together with publication.
- Menu bar glyphs and app names in the demos are invented, and the same apps
  appear in the same order in the menu bar, the reef and the Organize demo.
  Avoid names close to real products. Do not show real
  third-party app icons or trademarks. The one exception is Usage4Claude, a
  sibling app by Blenny's own developer, which hides in the reef's highest
  crevice as an easter egg (`assets/img/usage4claude-128.png`).
- The menu bar's double arrow mirrors the app's own reveal arrow
  (`ManagementStatusPresentation`): `chevron.right.2` while collapsed,
  `chevron.left.2` while expanded.
- English is canonical for all tracked website content.
- Typography: Fraunces (display, with its SOFT and WONK axes turned up),
  Bricolage Grotesque (text) and Martian Mono (labels and the depth gauge), all
  from Google Fonts. The Organize demo and the menu bar keep the system font,
  because they imitate macOS.
- Sound is synthesised in the browser and stays off until the visitor turns it
  on from the menu bar's speaker, which suggests itself once per visitor.
- Keep per-frame rendering cheap: the caustics render at half resolution, at
  30 fps, and only while the sand is on screen. Effects that are not always
  needed (the headline ripple filter, the breach overlay) run only while
  they play.
- Sand art carries no painted light. Caustics are drawn by `caustics.js`, so the
  bank and the rock's heap share one moving pattern.
- Search and AI: `index.html` carries JSON-LD (`SoftwareApplication`, `WebSite`
  and an `FAQPage` copied word for word from the visible FAQ; regenerate it when
  the FAQ changes). `llms.txt` is a plain summary for AI assistants and must
  follow the same product claims as the page. `robots.txt` allows all crawlers;
  check that the Cloudflare zone does not block AI crawlers if that is still
  wanted.
- Plain static HTML, CSS and JavaScript. Add a build step or package manager
  only when a production need justifies it.

## Scene art

The hero rock, the cave interior, the three Blenny frames and the reef ledge are
generated illustrations based on the app icon. Masters live in `art/` (see
`art/README.md`);
the site ships WebP derivatives in `site/assets/img/scene/`, at two widths each.

Each scene is layered back to front: cave interior, Blenny (or landed Reef
icons), the overhang's shadow, then the rock image, whose hole is transparent so
its rim overlaps what sits inside.

To replace a piece of art:

1. `python3 tools/scene_assets.py clean SRC.png OUT.png [x0 y0 x1 y1]` to crop and
   clamp alpha, then `cwebp -q 88 -alpha_q 100 OUT.png -o NAME.webp` (plus a
   half-width copy for the `srcset`).
2. For a new reef ledge, run `python3 tools/scene_assets.py holes SRC.png` and
   copy the boxes into `LEDGE_HOLES` / `LEDGE_HOME` in `site/assets/js/dive.js`.
3. The hero rock also needs `rock-hero-sandmask.webp`: a white mask of its sand
   heap only (no rock, moss, barnacles or thin lit rims), at 1200 px wide, so
   the caustics fall on the heap and nowhere else.
4. App icons for the invented apps live in `site/assets/img/apps/` as 192 px
   WebP, cropped to the rounded square (masters in `art/icons/`).
   Their file names match `icon` in `site/assets/js/glyphs.js`.
5. Blenny frames must stay pixel-aligned and keep plain white eyes; if the eyes
   move, update `EYES` in `site/assets/js/sprite-blenny.js`.

## Social preview

`site/assets/img/social-card.jpg` (1200 × 630) is the page's `og:image`; the
GitHub repository uses a 1280 × 640 JPEG of the same card (under 1 MB). The
card is the illustrated background from `art/social/` with the
site's own type and menu bar laid over it:

```sh
node tools/social-card.mjs art/social/social-background-v1.png OUT_DIR
```

It lays the card out natively at 1280 × 640 and 1200 × 630, so neither size is
cropped, and renders both at 2x with Google Chrome; downscale them to 1x.

## Local preview

```sh
python3 -m http.server 4175 --directory Website/site
```

Then open `http://localhost:4175/`. Serve over HTTP because ES modules do not
load from `file://`. `_headers` is applied by Cloudflare only, not by this
server. The prototypes can be previewed the same way from `Website/`.

## Deploy

From this directory, with a Cloudflare account that owns the `fi5h.xyz` zone:

```sh
npx wrangler deploy
```

`wrangler.jsonc` binds the Worker to the `blenny.fi5h.xyz` custom domain,
serves `site/`, uses `404.html` for unknown paths and redirects to canonical
trailing-slash URLs. For Git-based deploys, set the project root directory to
`Website` and the deploy command to `npx wrangler deploy`.

Deploying publishes the site. Do it only with the owner's explicit
confirmation, like any other publication step.
