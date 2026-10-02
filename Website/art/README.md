# Website art sources

The production sources for the website's illustrated art, in the same role as
`Assets/` for the app: the site ships smaller, cropped derivatives of these
files from `site/assets/img/`, and nothing here is deployed. Explorations and
superseded drafts stay in the local, untracked `Design/WebSite/` workspace.

| Source | Derivatives in `site/assets/img/` |
| --- | --- |
| `rock/rock-v2-sand-v2.png` | `scene/rock-hero-1200.webp`, `scene/rock-hero-2400.webp` (cropped to 2400 × 1502), `scene/rock-hero-sandmask.webp` |
| `rock/cave-interior-v1.png` | `scene/cave.webp` |
| `rock/reef-ledge-10-holes-v2.png` | `scene/reef-ledge-1600.webp`, `scene/reef-ledge-3200.webp` |
| `blenny/blenny-{base,blink,excited}-v3.png` | `scene/blenny-{base,blink,excited}-{840,1680}.webp` (pixel-aligned frames) |
| `sand/sand-seafloor-v2.png` | `scene/sand-2000.webp`, `scene/sand-4000.webp` |
| `icons/*.png` | `apps/*.webp`, 192 px, cropped to the rounded square |
| `social/social-background-v1.png` | the background of `social-card.jpg` (see `tools/social-card.mjs`) |
| `social/blenny-github-social-1280x640.jpg` | the GitHub repository's social preview (uploaded by hand) |

All art is generated illustration made for Blenny, based on the app icon. The
invented app icons do not represent real products. See `../README.md` for the
export commands.
