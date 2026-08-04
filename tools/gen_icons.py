#!/usr/bin/env python3
"""Generate the placeholder toolbar icons (24 and 48 px PNGs).

Dependency-free: rasterizes simple vector shapes at 4x supersampling and
writes PNGs by hand. Rerun after tweaking a spec:

    python3 tools/gen_icons.py

Icons are intentionally simple flat glyphs; replace the PNGs with real
artwork any time — the plugins just load whatever is on disk.
"""

import math
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SS = 4  # supersample factor


# --- shape tests (unit-square coordinates, y down) -------------------------

def rounded_rect(x0, y0, x1, y1, r):
    def test(x, y):
        if not (x0 <= x <= x1 and y0 <= y <= y1):
            return False
        cx = min(max(x, x0 + r), x1 - r)
        cy = min(max(y, y0 + r), y1 - r)
        return (x - cx) ** 2 + (y - cy) ** 2 <= r * r or (
            x0 + r <= x <= x1 - r or y0 + r <= y <= y1 - r
        )
    return test


def rect(x0, y0, x1, y1):
    return lambda x, y: x0 <= x <= x1 and y0 <= y <= y1


def ring(cx, cy, radius, width):
    def test(x, y):
        d = math.hypot(x - cx, y - cy)
        return abs(d - radius) <= width / 2.0
    return test


def half_ring(cx, cy, radius, width, right):
    base = ring(cx, cy, radius, width)
    if right:
        return lambda x, y: x >= cx and base(x, y)
    return lambda x, y: x <= cx and base(x, y)


def triangle(p1, p2, p3):
    def sign(a, b, p):
        return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])

    def test(x, y):
        p = (x, y)
        d1, d2, d3 = sign(p1, p2, p), sign(p2, p3, p), sign(p3, p1, p)
        neg = d1 < 0 or d2 < 0 or d3 < 0
        pos = d1 > 0 or d2 > 0 or d3 > 0
        return not (neg and pos)
    return test


# --- palette ---------------------------------------------------------------

GREEN = (74, 140, 63, 255)
SLATE = (58, 110, 165, 255)
WHITE = (250, 250, 250, 255)
ORANGE = (232, 149, 60, 255)
TEAL = (77, 182, 172, 255)
TRACK = (186, 75, 60, 255)


def icon_field():
    """Green pitch inside a track-red rounded tile: oval + pitch lines."""
    return [
        (rounded_rect(0.02, 0.02, 0.98, 0.98, 0.18), TRACK),
        (rect(0.14, 0.24, 0.86, 0.76), GREEN),
        (rect(0.14, 0.24, 0.86, 0.30), WHITE),
        (rect(0.14, 0.70, 0.86, 0.76), WHITE),
        (rect(0.14, 0.24, 0.20, 0.76), WHITE),
        (rect(0.80, 0.24, 0.86, 0.76), WHITE),
        (rect(0.47, 0.24, 0.53, 0.76), WHITE),
        (ring(0.5, 0.5, 0.11, 0.06), WHITE),
    ]


def icon_import():
    """Arrow feeding a row of colored program blocks."""
    return [
        (rounded_rect(0.02, 0.02, 0.98, 0.98, 0.18), SLATE),
        (rect(0.44, 0.12, 0.56, 0.38), WHITE),
        (triangle((0.30, 0.36), (0.70, 0.36), (0.50, 0.56)), WHITE),
        (rect(0.14, 0.62, 0.44, 0.88), ORANGE),
        (rect(0.52, 0.62, 0.86, 0.88), TEAL),
    ]


def icon_export():
    """Program blocks emitting an arrow (comparison export)."""
    return [
        (rounded_rect(0.02, 0.02, 0.98, 0.98, 0.18), SLATE),
        (rect(0.14, 0.12, 0.44, 0.38), ORANGE),
        (rect(0.52, 0.12, 0.86, 0.38), TEAL),
        (rect(0.44, 0.50, 0.56, 0.70), WHITE),
        (triangle((0.30, 0.68), (0.70, 0.68), (0.50, 0.88)), WHITE),
    ]


ICONS = {
    os.path.join("plugins", "field_designer", "field_designer",
                 "resources", "icons", "field"): icon_field,
    os.path.join("plugins", "bsf_program_translator", "bsf_program_translator",
                 "resources", "icons", "import"): icon_import,
    os.path.join("plugins", "bsf_program_translator", "bsf_program_translator",
                 "resources", "icons", "export"): icon_export,
}


# --- rasterizer / png writer ----------------------------------------------

def render(shapes, size):
    big = size * SS
    px = [[(0, 0, 0, 0)] * big for _ in range(big)]
    for j in range(big):
        y = (j + 0.5) / big
        for i in range(big):
            x = (i + 0.5) / big
            for test, color in shapes:
                if callable(test) and test(x, y):
                    px[j][i] = color
    out = bytearray()
    for j in range(size):
        out.append(0)  # filter: none
        for i in range(size):
            r = g = b = a = 0
            for dj in range(SS):
                for di in range(SS):
                    pr, pg, pb, pa = px[j * SS + dj][i * SS + di]
                    r += pr * pa
                    g += pg * pa
                    b += pb * pa
                    a += pa
            n = SS * SS
            if a:
                out += bytes((r // a, g // a, b // a, a // n))
            else:
                out += b"\x00\x00\x00\x00"
    return bytes(out)


def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data +
            struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))


def write_png(path, size, raw):
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", ihdr))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def main():
    for base, spec in ICONS.items():
        shapes = spec()
        outdir = os.path.join(ROOT, os.path.dirname(base))
        os.makedirs(outdir, exist_ok=True)
        for size in (24, 48):
            path = os.path.join(ROOT, f"{base}_{size}.png")
            write_png(path, size, render(shapes, size))
            print("wrote", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
