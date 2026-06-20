#!/usr/bin/env python3
"""Generate a crisp pixel-art river background matching Alea orb/pillar style."""

from __future__ import annotations

from PIL import Image

# Logical canvas: each logical pixel is later upscaled by `SCALE`.
# Higher logical resolution -> less "chunky" look.
BASE_W, BASE_H = 320, 180
W, H = 480, 270
SCALE = 4
OUT = "assets/textures/river_pixel.png"

# Scale helpers from the original 320x180 design space
sx_f = float(W) / float(BASE_W)
sy_f = float(H) / float(BASE_H)

def rx(v: int) -> int:
    return int(round(float(v) * sx_f))

def ry(v: int) -> int:
    return int(round(float(v) * sy_f))

# Limited sunset palette — solid bands, no photo noise
C = {
    "sky_deep": (38, 58, 98),
    "sky_mid": (72, 108, 138),
    "sky_teal": (118, 158, 178),
    "sky_peach": (228, 148, 118),
    "sky_glow": (248, 178, 108),
    "cloud_hi": (255, 236, 214),
    "cloud_lo": (232, 168, 148),
    "star": (220, 230, 255),
    "sun": (255, 244, 168),
    "sun_core": (255, 255, 210),
    "mtn_far": (48, 62, 96),
    "mtn_near": (32, 44, 72),
    "tree": (22, 32, 52),
    "water_dark": (28, 42, 72),
    "water_mid": (42, 62, 98),
    "water_light": (58, 82, 118),
    "reflect": (255, 196, 112),
    "reflect_hi": (255, 228, 158),
    "boat": (240, 240, 248),
    "stone_hi": (168, 164, 158),
    "stone": (132, 128, 122),
    "stone_lo": (96, 92, 88),
    "stone_line": (64, 60, 56),
}


def put(img: Image.Image, x: int, y: int, color: tuple[int, int, int]) -> None:
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), color)


def fill_rect(
    img: Image.Image,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    color: tuple[int, int, int],
) -> None:
    for y in range(max(0, y0), min(H, y1)):
        for x in range(max(0, x0), min(W, x1)):
            img.putpixel((x, y), color)


def sky_band_color(y: int) -> tuple[int, int, int]:
    horizon = ry(102)
    y18 = ry(18)
    y38 = ry(38)
    y58 = ry(58)
    if y < y18:
        return C["sky_deep"]
    if y < y38:
        return C["sky_mid"]
    if y < y58:
        return C["sky_teal"]
    if y < horizon - ry(8):
        return C["sky_peach"]
    if y < horizon + ry(6):
        return C["sky_glow"]
    return C["sky_peach"]


def draw_sky(img: Image.Image) -> None:
    for y in range(H):
        col = sky_band_color(y)
        fill_rect(img, 0, y, W, y + 1, col)
    # sparse stars
    stars = [
        (rx(28), ry(12)),
        (rx(52), ry(22)),
        (rx(88), ry(8)),
        (rx(140), ry(18)),
        (rx(210), ry(10)),
        (rx(270), ry(16)),
        (rx(300), ry(26)),
    ]
    for px, py in stars:
        put(img, px, py, C["star"])
        put(img, px + 1, py, C["star"])


def draw_cloud(img: Image.Image, cx: int, cy: int, w: int, h: int) -> None:
    for dy in range(-h, h + 1):
        for dx in range(-w, w + 1):
            if (dx * dx) / (w * w + 0.1) + (dy * dy) / (h * h + 0.1) <= 1.0:
                shade = C["cloud_hi"] if dy <= 0 else C["cloud_lo"]
                put(img, cx + dx, cy + dy, shade)


def draw_clouds(img: Image.Image) -> None:
    draw_cloud(img, rx(52), ry(52), rx(26), ry(10))
    draw_cloud(img, rx(78), ry(48), rx(18), ry(8))
    draw_cloud(img, rx(248), ry(56), rx(24), ry(9))
    draw_cloud(img, rx(272), ry(50), rx(16), ry(7))
    draw_cloud(img, rx(160), ry(44), rx(20), ry(8))


def draw_mountains(img: Image.Image) -> None:
    horizon = ry(102)
    far = [
        (0, horizon),
        (rx(40), horizon - ry(10)),
        (rx(78), horizon - ry(6)),
        (rx(120), horizon - ry(14)),
        (rx(168), horizon - ry(8)),
        (rx(210), horizon - ry(16)),
        (rx(252), horizon - ry(7)),
        (rx(290), horizon - ry(12)),
        (W, horizon - ry(5)),
        (W, horizon + ry(1)),
        (0, horizon + ry(1)),
    ]
    near = [
        (0, horizon + ry(2)),
        (rx(55), horizon - ry(4)),
        (rx(105), horizon + ry(1)),
        (rx(155), horizon - ry(6)),
        (rx(205), horizon + ry(2)),
        (rx(255), horizon - ry(3)),
        (W, horizon + ry(1)),
        (W, horizon + ry(10)),
        (0, horizon + ry(10)),
    ]

    def poly(points: list[tuple[int, int]], color: tuple[int, int, int]) -> None:
        min_y = min(p[1] for p in points)
        max_y = max(p[1] for p in points)
        for y in range(min_y, max_y + 1):
            xs: list[int] = []
            n = len(points)
            for i in range(n):
                x1, y1 = points[i]
                x2, y2 = points[(i + 1) % n]
                if y1 == y2:
                    if y == y1:
                        xs.extend([x1, x2])
                    continue
                if (y >= min(y1, y2)) and (y < max(y1, y2)):
                    t = (y - y1) / (y2 - y1)
                    xs.append(int(x1 + t * (x2 - x1)))
            if len(xs) >= 2:
                fill_rect(img, min(xs), y, max(xs) + 1, y + 1, color)

    poly(far, C["mtn_far"])
    poly(near, C["mtn_near"])


def draw_trees(img: Image.Image) -> None:
    base_y = ry(112)

    def pine(x: int, h: int) -> None:
        for row in range(h):
            half = max(1, (h - row) // 3)
            y = base_y - row
            fill_rect(img, x - half, y, x + half + 1, y + 1, C["tree"])

    for x, h in [
        (rx(18), ry(22)),
        (rx(32), ry(18)),
        (rx(288), ry(20)),
        (rx(302), ry(16)),
        (rx(268), ry(14)),
    ]:
        pine(x, h)


def draw_sun(img: Image.Image, horizon: int) -> None:
    cx, cy, r = W // 2, horizon, ry(13)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            d2 = dx * dx + dy * dy
            if d2 <= r * r:
                col = C["sun_core"] if d2 <= (r * 0.42) ** 2 else C["sun"]
                put(img, cx + dx, cy + dy, col)


def draw_water(img: Image.Image, horizon: int) -> None:
    top = horizon + ry(2)
    cx = W // 2
    for y in range(top, H - ry(44)):
        t = (y - top) / max(1, H - 44 - top)
        base = C["water_dark"]
        if t < 0.35:
            base = C["water_mid"]
        elif t < 0.7:
            base = C["water_light"]
        if y % 3 == 0:
            base = tuple(max(0, c - 8) for c in base)
        fill_rect(img, 0, y, W, y + 1, base)

        reflect_half = max(2, int(rx(20) - (y - top) * 0.14))
        for x in range(cx - reflect_half, cx + reflect_half + 1):
            dist = abs(x - cx)
            if dist <= 1 and (y - top) % 2 == 0:
                put(img, x, y, C["reflect_hi"])
            elif (y - top) % 3 != 1:
                put(img, x, y, C["reflect"])

    for bx, by in [
        (rx(72), horizon + ry(18)),
        (rx(248), horizon + ry(22)),
        (rx(268), horizon + ry(26)),
    ]:
        fill_rect(img, bx, by, bx + rx(5), by + ry(2), C["boat"])
        put(img, bx + rx(2), by - ry(3), C["boat"])
        put(img, bx + rx(2), by - ry(4), C["boat"])


def draw_stone_dock(img: Image.Image) -> None:
    top = H - ry(44)
    fill_rect(img, 0, top, W, H, C["stone"])
    tile = max(1, ry(8))
    for ty in range(top, H, tile):
        for tx in range(0, W, tile):
            shade = C["stone_hi"] if (tx // tile + ty // tile) % 2 == 0 else C["stone_lo"]
            fill_rect(img, tx + 1, ty + 1, tx + tile - 1, ty + tile - 1, shade)
            fill_rect(img, tx, ty, tx + tile, ty + 1, C["stone_line"])
            fill_rect(img, tx, ty, tx + 1, ty + tile, C["stone_line"])


def main() -> None:
    horizon = ry(102)
    img = Image.new("RGB", (W, H), C["sky_deep"])
    draw_sky(img)
    draw_clouds(img)
    draw_sun(img, horizon)
    draw_mountains(img)
    draw_trees(img)
    draw_water(img, horizon)
    draw_stone_dock(img)

    out_w, out_h = W * SCALE, H * SCALE
    final = img.resize((out_w, out_h), Image.NEAREST)
    final.save(OUT, optimize=True)
    print(f"Wrote {OUT} ({out_w}x{out_h}) from {W}x{H} @ {SCALE}x")


if __name__ == "__main__":
    main()
