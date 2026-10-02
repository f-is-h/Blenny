#!/usr/bin/env python3
"""Prepare generated scene art for the website. Standard library only.

  scene_assets.py clean SRC.png DST.png [x0 y0 x1 y1]
      Crop an RGBA PNG and clamp its alpha: >= 240 becomes opaque, < 16 becomes
      transparent. Image generators tend to leave bodies at alpha ~252 and faint
      specks around the edges. Encode the result with cwebp afterwards.

  scene_assets.py holes SRC.png
      List the enclosed transparent holes of an RGBA PNG (bounding boxes in
      image pixels). Use it to update LEDGE_HOLES in site/assets/js/dive.js
      whenever reef-ledge art is regenerated.
"""
import struct, sys, zlib
from collections import deque


def load(path):
    data = open(path, 'rb').read()
    pos, idat = 8, b''
    while pos < len(data):
        length, = struct.unpack('>I', data[pos:pos + 4])
        kind, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b'IHDR':
            w, h, depth, colour, _, _, interlace = struct.unpack('>IIBBBBB', body)
            if (depth, colour, interlace) != (8, 6, 0):
                sys.exit('Expected a non-interlaced 8-bit RGBA PNG')
        elif kind == b'IDAT':
            idat += body
    raw, bpp = zlib.decompress(idat), 4
    stride = w * bpp
    out, prev, i = bytearray(h * stride), bytearray(stride), 0
    for y in range(h):
        f = raw[i]; i += 1
        line = bytearray(raw[i:i + stride]); i += stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + ((a + b) >> 1)) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return w, h, out


def save(path, w, h, px):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw += px[y * w * 4:(y + 1) * w * 4]
    def chunk(kind, body):
        return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
                + chunk(b'IDAT', zlib.compress(bytes(raw), 6)) + chunk(b'IEND', b''))


def clean(src, dst, box=None):
    w, h, px = load(src)
    x0, y0, x1, y1 = box or (0, 0, w, h)
    cw, ch = x1 - x0, y1 - y0
    out = bytearray(cw * ch * 4)
    for y in range(ch):
        row = px[((y + y0) * w + x0) * 4:((y + y0) * w + x1) * 4]
        for i in range(3, len(row), 4):
            row[i] = 255 if row[i] >= 240 else 0 if row[i] < 16 else row[i]
        out[y * cw * 4:(y + 1) * cw * 4] = row
    save(dst, cw, ch, out)
    print(f'{dst}: {cw}x{ch}')


def holes(src, step=4):
    w, h, px = load(src)
    gw, gh = w // step, h // step
    clear = [[px[((y * step) * w + x * step) * 4 + 3] < 24 for x in range(gw)] for y in range(gh)]
    seen = [[False] * gw for _ in range(gh)]
    found = []
    for sy in range(gh):
        for sx in range(gw):
            if not clear[sy][sx] or seen[sy][sx]:
                continue
            queue, cells, touches_edge = deque([(sx, sy)]), [], False
            seen[sy][sx] = True
            while queue:
                x, y = queue.popleft()
                cells.append((x, y))
                touches_edge |= x in (0, gw - 1) or y in (0, gh - 1)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < gw and 0 <= ny < gh and clear[ny][nx] and not seen[ny][nx]:
                        seen[ny][nx] = True
                        queue.append((nx, ny))
            if not touches_edge and len(cells) > 20:
                xs = [c[0] * step for c in cells]
                ys = [c[1] * step for c in cells]
                found.append((min(xs), min(ys), max(xs), max(ys)))
    print(f'{src}: {w}x{h}, {len(found)} enclosed holes')
    for box in sorted(found, key=lambda b: (b[1], b[0])):
        print(f'  [{box[0]}, {box[1]}, {box[2]}, {box[3]}]  size {box[2] - box[0]}x{box[3] - box[1]}')


if __name__ == '__main__':
    if len(sys.argv) >= 4 and sys.argv[1] == 'clean':
        clean(sys.argv[2], sys.argv[3], tuple(map(int, sys.argv[4:8])) if len(sys.argv) == 8 else None)
    elif len(sys.argv) == 3 and sys.argv[1] == 'holes':
        holes(sys.argv[2])
    else:
        sys.exit(__doc__)
