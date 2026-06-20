#!/usr/bin/env python3
"""Clean up river_pixel.png: snap palette + nearest upscale (no blur)."""

from __future__ import annotations

from PIL import Image

SRC = "assets/textures/river_pixel.png"
OUT = SRC
LOGICAL_W, LOGICAL_H = 480, 270
OUT_W, OUT_H = 1920, 1080
PALETTE_COLORS = 52


def main() -> None:
    img = Image.open(SRC).convert("RGB")
    base = img.resize((LOGICAL_W, LOGICAL_H), Image.NEAREST)
    base = base.quantize(
        colors=PALETTE_COLORS,
        method=Image.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    final = base.resize((OUT_W, OUT_H), Image.NEAREST)
    final.save(OUT, optimize=True)
    print(f"Crisped {OUT}: {LOGICAL_W}x{LOGICAL_H} -> {OUT_W}x{OUT_H}")


if __name__ == "__main__":
    main()
