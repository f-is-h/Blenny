# Menu bar template source

`BlennyMenuBarTemplate.svg` is the production 18-by-18-point template. Version
0.13.0 derives it from the owner-selected `BlennyMenuBarFaceSilhouette-A.svg`:
the face, transparent eye whites, pupils, cirri, and absence of a mouth are
preserved. A tighter square view box centers the silhouette at status-item size
without stretching it.

As established by the 0.2.0 optical-size correction, the production SVG uses
direct even-odd eye cutouts instead of an SVG mask. This avoids the mask's
subpixel rasterization at small AppKit sizes. AppKit loads the asset as a template
with no additional status-button scaling. Open Blenny reuses the same image at
16 points. The detailed design source remains separate from production rendering.
