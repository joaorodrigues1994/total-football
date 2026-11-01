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
WHITE_D = (178, 178, 192, 255)
MASK = (205, 205, 215, 255)
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
    light = tuple(min(255, v + 55) for v in main) + (255,)
    dark = tuple(max(0, v - 40) for v in main) + (255,)
    return main + (255,), light, dark


def legs(c, frame, moving, view):
    dx = [3, 0, -3, 0][frame % 4] if moving else (1 if frame % 2 == 0 else 1)
    lift_a = 1 if moving and frame % 4 == 1 else 0
    lift_b = 1 if moving and frame % 4 == 3 else 0
    if view == "side":
        for x, lift in ((12 + dx, lift_a), (12 - dx, lift_b)):
            c.rect(x, 16, x + 1, 19 - lift, WHITE if lift_a == lift else WHITE_D)
            c.rect(x, 20 - lift, x + 2, 21 - lift, SHOE)
    else:
        for x, lift in ((8, lift_a), (13, lift_b)):
            c.rect(x, 16, x + 2, 19 - lift, WHITE)
            c.rect(x, 20 - lift, x + 2, 21 - lift, SHOE)


def draw(view, frame, moving, main):
    m, light, dark = palette(main)
    c = Canvas()
    b = 1 if frame % 2 == 1 and (moving or True) and (moving or frame == 1) else 0
    legs(c, frame, moving, view)
    swing = [2, 0, -2, 0][frame % 4] if moving else 0
    if view == "side":
        c.rect(9, 9 - b, 15, 15 - b, m)
        c.rect(9, 15 - b, 15, 15 - b, dark)
        c.rect(11, 11 - b, 12, 13 - b, WHITE)
        c.rect(11 + swing, 10 - b, 12 + swing, 13 - b, light)
        c.rect(11 + swing, 14 - b, 12 + swing, 14 - b, SKIN)
        c.rect(9, 3 - b, 15, 8 - b, m)
        c.rect(9, 3 - b, 15, 3 - b, light)
        c.rect(13, 6 - b, 15, 8 - b, SKIN)
        c.rect(14, 7 - b, 16, 7 - b, MASK)
        c.rect(14, 9 - b, 16, 9 - b, MASK)
    else:
        c.rect(7, 9 - b, 16, 15 - b, m)
        c.rect(7, 15 - b, 16, 15 - b, dark)
        c.rect(5, 10 - b + (swing > 0), 6, 13 - b, light)
        c.rect(17, 10 - b + (swing < 0), 18, 13 - b, light)
        c.rect(5, 14 - b, 6, 14 - b, SKIN)
        c.rect(17, 14 - b, 18, 14 - b, SKIN)
        c.rect(8, 2 - b, 15, 8 - b, m)
        c.rect(8, 2 - b, 15, 2 - b, light)
        if view == "down":
            c.rect(10, 11 - b, 13, 12 - b, WHITE)
            c.rect(9, 6 - b, 14, 8 - b, SKIN)
            c.rect(9, 7 - b, 14, 7 - b, MASK)
            c.rect(9, 9 - b, 14, 9 - b, MASK)
            c.rect(11, 2 - b, 12, 5 - b, WHITE)
        else:
            c.rect(10, 11 - b, 13, 13 - b, WHITE)
            c.rect(11, 2 - b, 12, 5 - b, light)
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
