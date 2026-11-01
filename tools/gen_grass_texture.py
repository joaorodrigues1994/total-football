"""Gera a textura pontilhada da grama (64x64, ladrilhavel). Uso: python tools/gen_grass_texture.py"""
import random

from gen_player_sprites import write_png

N = 64
rnd = random.Random(7)
px = []
for _ in range(N):
    row = []
    for _ in range(N):
        v = rnd.random()
        if v < 0.22:
            row.append((0, 40, 0, 46))
        elif v < 0.36:
            row.append((200, 255, 160, 34))
        else:
            row.append(None)
    px.append(row)
write_png("assets/field/grass_noise.png", px, N, N)
print("ok")
