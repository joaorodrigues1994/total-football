"""Gera os spritesheets base dos jogadores (24x24) em PNG puro, sem dependencias.
Linhas: idle_side, run_side, idle_down, run_down, idle_up, run_up. 4 colunas (idle usa 2).
Os PNGs gerados sao a base para refinar no LibreSprite."""
import struct
import sys
import zlib

S = 24
OUT = (16, 16, 24, 255)
SKIN = (224, 160, 112, 255)
WHITE = (236, 236, 240, 255)
GRAY = (170, 172, 186, 255)
GRAY_D = (124, 126, 142, 255)
MASK_D = (72, 72, 86, 255)
SHOE = (34, 34, 44, 255)

TEAMS = {"a": (31, 78, 140), "b": (140, 31, 42)}


class Canvas:
    def __init__(self):
        self.p = [[None] * S for _ in range(S)]

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if 0 <= x < S and 0 <= y < S:
                    self.p[y][x] = c

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(S):
            for x in range(S):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                    self.p[y][x] = c

    def outline(self):
        src = [row[:] for row in self.p]
        for y in range(S):
            for x in range(S):
                if src[y][x] is None:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < S and 0 <= ny < S and src[ny][nx] is not None:
                            self.p[y][x] = OUT
                            break


def palette(main):
    light = tuple(min(255, v + 70) for v in main) + (255,)
    dark = tuple(max(0, v - 40) for v in main) + (255,)
    return main + (255,), light, dark


def legs(c, frame, moving, view, b):
    dx = [3, 0, -3, 0][frame % 4] if moving else 1
    lift_a = 1 if moving and frame % 4 == 1 else 0
    lift_b = 1 if moving and frame % 4 == 3 else 0
    if view == "side":
        spots = ((12 + dx, lift_a), (12 - dx, lift_b))
    else:
        spots = ((8, lift_a), (13, lift_b))
    for x, lift in spots:
        w = 2 if view == "side" else 3
        c.rect(x, 15 - b, x + w - 1, 18 - lift, GRAY)
        c.rect(x, 18 - lift, x, 18 - lift, GRAY_D)
        c.rect(x, 19 - lift, x + w - 1, 20 - lift, WHITE)
        c.rect(x, 21 - lift, x + w, 21 - lift, SHOE)


def draw(view, frame, moving, main):
    m, light, dark = palette(main)
    c = Canvas()
    b = 1 if frame % 2 == 1 else 0
    legs(c, frame, moving, view, b)
    swing = [1, 0, -1, 0][frame % 4] if moving else 0
    if view == "side":
        c.rect(8, 10 - b, 15, 15 - b, m)
        c.rect(8, 15 - b, 15, 15 - b, dark)
        c.rect(10, 12 - b, 12, 13 - b, WHITE)
        c.rect(10 + swing * 2, 11 - b, 11 + swing * 2, 12 - b, m)
        c.rect(10 + swing * 2, 13 - b, 11 + swing * 2, 14 - b, SKIN)
        c.ellipse(13, 6 - b, 5, 4.5, m)
        c.rect(10, 3 - b, 12, 3 - b, light)
        c.rect(9, 4 - b, 9, 4 - b, light)
        c.rect(15, 7 - b, 16, 8 - b, SKIN)
        c.rect(16, 7 - b, 17, 10 - b, MASK_D)
        c.rect(12, 7 - b, 12, 8 - b, dark)
    else:
        c.rect(6, 10 - b, 17, 14 - b, m)
        for x, y in ((6, 10), (17, 10)):
            c.p[y - b][x] = None
        c.rect(6, 14 - b, 17, 14 - b, dark)
        l, r = (1 if swing > 0 else 0), (1 if swing < 0 else 0)
        c.rect(4, 11 - b + l, 5, 12 - b + l, m)
        c.rect(4, 13 - b + l, 5, 15 - b + l, SKIN)
        c.rect(18, 11 - b + r, 19, 12 - b + r, m)
        c.rect(18, 13 - b + r, 19, 15 - b + r, SKIN)
        c.ellipse(11.5, 6 - b, 5.5, 4.5, m)
        c.rect(8, 3 - b, 10, 3 - b, light)
        c.rect(7, 4 - b, 7, 4 - b, light)
        c.rect(11, 2 - b, 12, 5 - b, WHITE)
        if view == "down":
            c.rect(8, 7 - b, 15, 8 - b, SKIN)
            c.rect(7, 9 - b, 16, 9 - b, MASK_D)
            c.rect(11, 7 - b, 12, 9 - b, MASK_D)
            c.rect(9, 8 - b, 9, 8 - b, OUT)
            c.rect(14, 8 - b, 14, 8 - b, OUT)
            c.rect(9, 11 - b, 14, 12 - b, WHITE)
        else:
            c.rect(9, 11 - b, 14, 13 - b, WHITE)
            c.rect(11, 11 - b, 12, 13 - b, dark)
    c.outline()
    return c


def write_png(path, pixels, w, h):
    raw = b"".join(b"\x00" + b"".join(bytes(p or (0, 0, 0, 0)) for p in row) for row in pixels)

    def chunk(t, d):
        body = t + d
        return struct.pack(">I", len(d)) + body + struct.pack(">I", zlib.crc32(body))

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))


def main():
    rows = [("side", False, 2), ("side", True, 4), ("down", False, 2),
            ("down", True, 4), ("up", False, 2), ("up", True, 4)]
    for team, color in TEAMS.items():
        w, h = S * 4, S * len(rows)
        sheet = [[None] * w for _ in range(h)]
        for r, (view, moving, n) in enumerate(rows):
            for f in range(n):
                cv = draw(view, f, moving, color)
                for y in range(S):
                    for x in range(S):
                        sheet[r * S + y][f * S + x] = cv.p[y][x]
        write_png(f"assets/sprites/player_team_{team}.png", sheet, w, h)
        print("ok", team)


if __name__ == "__main__":
    sys.exit(main())
