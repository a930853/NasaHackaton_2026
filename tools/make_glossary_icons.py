"""Dibuja los 18 iconos de pixel art del libro de palabras (32x32, borde negro) en game/Images/Glossary/<id>.png.

    python tools/make_glossary_icons.py [carpeta_de_vista_previa]

Hay un icono por término de game/Data/glossary.json (el nombre del fichero es el id del término). Si se añade un
término, se añade aquí su función de dibujo y se vuelve a ejecutar. Con un argumento guarda también una hoja
de contacto ampliada para revisar los dibujos.
"""
import math
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "Images" / "Glossary"
N = 32

BLACK = (12, 10, 22, 255)
WHITE = (244, 247, 252, 255)
LIGHT = (200, 208, 224, 255)
GRAY = (140, 148, 166, 255)
DARK = (84, 90, 108, 255)
YELLOW = (255, 214, 64, 255)
GOLD = (255, 170, 30, 255)
ORANGE = (238, 120, 50, 255)
RED = (222, 60, 60, 255)
SAND = (218, 150, 90, 255)
BROWN = (160, 90, 52, 255)
DBROWN = (112, 62, 38, 255)
BLUE = (70, 160, 255, 255)
LBLUE = (170, 220, 255, 255)
DBLUE = (40, 80, 170, 255)
GREEN = (80, 200, 100, 255)
DGREEN = (40, 140, 70, 255)


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        self.px = self.img.load()

    def put(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < N and 0 <= y < N:
            self.px[x, y] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.put(x, y, c)

    def disc(self, cx, cy, r, c):
        for y in range(N):
            for x in range(N):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.3:
                    self.put(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(N):
            for x in range(N):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c, width=1):
        steps = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(steps + 1):
            t = i / steps
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for dx in range(width):
                for dy in range(width):
                    self.put(x + dx, y + dy, c)

    def poly(self, points, c):
        ys = [p[1] for p in points]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            for i in range(len(points)):
                (xa, ya), (xb, yb) = points[i], points[(i + 1) % len(points)]
                if (ya <= y < yb) or (yb <= y < ya):
                    xs.append(xa + (y - ya) * (xb - xa) / (yb - ya))
            xs.sort()
            for k in range(0, len(xs) - 1, 2):
                for x in range(int(math.ceil(xs[k])), int(math.floor(xs[k + 1])) + 1):
                    self.put(x, y, c)

    def outline(self, color=BLACK):
        solid = [(x, y) for y in range(N) for x in range(N) if self.px[x, y][3]]
        for (x, y) in solid:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < N and 0 <= ny < N and self.px[nx, ny][3] == 0:
                    self.px[nx, ny] = color


def sun(c, cx, cy, r, rays=True):
    if rays:
        for k in range(8):
            a = k * math.pi / 4
            c.line(cx + math.cos(a) * (r + 1), cy + math.sin(a) * (r + 1), cx + math.cos(a) * (r + 3), cy + math.sin(a) * (r + 3), GOLD, 1)
    c.disc(cx, cy, r, YELLOW)
    c.disc(cx - 1, cy - 1, r * 0.55, (255, 245, 170, 255))


def bowl(c, cx, cy, rx, ry, rim, inner):
    c.ellipse(cx, cy, rx, ry, rim)
    c.ellipse(cx, cy + 1, rx - 2, ry - 1.5, inner)


def wheel(c, cx, cy, r=3):
    c.disc(cx, cy, r, DARK)
    c.disc(cx, cy, 1, LIGHT)


# ------------------------------------------------------------------ un dibujo por término

def sol(c):
    sun(c, 16, 16, 8)


def moxie(c):
    c.rect(5, 11, 19, 25, GRAY)
    c.rect(5, 11, 19, 13, LIGHT)
    c.rect(8, 15, 15, 20, DBLUE)
    c.rect(9, 16, 12, 17, LBLUE)
    c.rect(7, 22, 17, 23, DARK)
    c.rect(19, 15, 25, 17, GRAY)                        # tubo de salida
    for (x, y, r) in ((27, 12, 2.2), (29, 7, 1.6), (25, 6, 1.2)):
        c.disc(x, y, r, LBLUE)                           # burbujas de oxígeno
    c.rect(6, 26, 8, 28, DARK)
    c.rect(16, 26, 18, 28, DARK)


def electrolisis_co2(c):
    for x, col in ((7, RED), (16, DARK), (25, RED)):     # O - C - O
        c.disc(x, 8, 4, col)
    c.disc(5.5, 6.5, 1.3, (255, 150, 150, 255))
    c.disc(23.5, 6.5, 1.3, (255, 150, 150, 255))
    c.rect(15, 14, 17, 20, WHITE)                        # flecha hacia abajo
    c.poly([(12, 19), (20, 19), (16, 24)], WHITE)
    for x in (10, 22):                                   # O2
        c.disc(x, 27, 3.6, BLUE)
        c.disc(x - 1, 26, 1.1, LBLUE)


def crater_jezero(c):
    c.rect(0, 20, 31, 31, BROWN)
    bowl(c, 16, 19, 14, 8, SAND, DBROWN)
    c.ellipse(16, 20, 9, 4.5, BLUE)
    c.ellipse(14, 19, 4, 2, LBLUE)
    c.line(21, 22, 26, 25, LBLUE, 1)                    # delta del río
    c.line(22, 23, 27, 23, LBLUE, 1)


def crater_gale(c):
    c.rect(0, 20, 31, 31, BROWN)
    bowl(c, 16, 19, 14, 8, SAND, DBROWN)
    c.poly([(16, 6), (9, 21), (23, 21)], SAND)
    c.poly([(16, 6), (16, 21), (23, 21)], BROWN)
    c.line(12, 14, 20, 14, DBROWN, 1)                   # capas de roca
    c.line(10, 18, 22, 18, DBROWN, 1)


def regolito(c):
    c.rect(0, 22, 31, 29, DBROWN)
    for (x, y, r, col) in ((8, 20, 4, BROWN), (16, 17, 5, SAND), (24, 20, 4, BROWN), (13, 21, 3, DBROWN), (20, 22, 2.4, SAND)):
        c.disc(x, y, r, col)
    for (x, y) in ((3, 14), (6, 11), (28, 13), (26, 9), (11, 9), (21, 11), (30, 18), (2, 19)):
        c.put(x, y, SAND)                                # granos de polvo
    c.disc(15, 15, 1.5, (240, 190, 140, 255))


def cme(c):
    sun(c, 7, 25, 5, rays=False)
    for (x, y, r, col) in ((13, 20, 4, ORANGE), (18, 15, 5.5, ORANGE), (24, 9, 7, ORANGE)):
        c.disc(x, y, r, col)
    for (x, y, r) in ((13, 20, 2, ), (18, 15, 3, ), (24, 9, 4, )):
        c.disc(x, y, r, GOLD)
    c.disc(7, 25, 3, (255, 245, 170, 255))


def fulguracion_solar(c):
    sun(c, 12, 20, 8, rays=False)
    c.disc(10, 18, 3.5, (255, 245, 170, 255))
    c.poly([(24, 1), (16, 14), (22, 14), (14, 29), (29, 11), (23, 11), (28, 1)], YELLOW)
    c.poly([(24, 3), (18, 13), (24, 13), (17, 25)], WHITE)


def probioticos(c):
    for (x0, x1, y) in ((5, 19, 8), (12, 26, 16), (4, 18, 24)):
        c.rect(x0, y - 3, x1, y + 3, GREEN)
        c.disc(x0, y, 3.5, GREEN)
        c.disc(x1, y, 3.5, GREEN)
        c.rect(x0 + 2, y - 2, x1 - 4, y - 2, (170, 240, 180, 255))
        for dx in (4, 9):
            c.put(x0 + dx, y + 1, DGREEN)
    c.put(28, 6, YELLOW)
    c.put(27, 7, YELLOW)
    c.put(29, 7, YELLOW)
    c.put(28, 8, YELLOW)


def radiacion_cosmica(c):
    c.disc(16, 36, 13, BROWN)                            # un planeta asoma por abajo
    c.disc(16, 36, 11, SAND)
    for x in (6, 12, 18, 24):
        y0 = 1 + (x % 5)
        c.line(x + 4, y0, x - 2, y0 + 12, LBLUE, 1)        # estela
        c.disc(x - 2, y0 + 12, 1.6, WHITE)                 # partícula
    c.line(27, 3, 22, 13, LBLUE, 1)
    c.disc(22, 13, 1.4, WHITE)


def osdr(c):
    for y in (21, 14, 7):
        c.rect(6, y, 25, y + 6, BLUE)
        c.ellipse(15.5, y, 10, 3, LBLUE)
        c.ellipse(15.5, y + 6, 10, 3, BLUE)
        c.rect(6, y, 6, y + 6, BLUE)
    for y in (24, 17, 10):
        c.put(21, y, YELLOW)
        c.put(23, y, GREEN)
    c.put(27, 4, YELLOW)
    c.put(26, 5, YELLOW)
    c.put(28, 5, YELLOW)
    c.put(27, 6, YELLOW)


def perseverance(c):
    c.rect(5, 14, 24, 21, WHITE)
    c.rect(5, 19, 24, 21, LIGHT)
    c.rect(22, 5, 23, 14, GRAY)                         # mástil
    c.rect(20, 3, 27, 7, DARK)
    c.rect(25, 4, 26, 5, LBLUE)
    c.rect(24, 17, 30, 18, GRAY)                        # brazo
    c.rect(29, 18, 30, 21, GRAY)
    for x in (7, 14, 21):
        wheel(c, x, 25)
    c.rect(7, 22, 21, 23, DARK)
    c.rect(8, 15, 12, 17, GOLD)                         # generador


def opportunity(c):
    c.rect(2, 8, 29, 13, DBLUE)                         # panel solar con cuadrícula
    for x in range(5, 29, 4):
        c.line(x, 8, x, 13, BLUE, 1)
    c.line(2, 10, 29, 10, BLUE, 1)
    c.rect(9, 14, 22, 20, LIGHT)
    c.rect(9, 18, 22, 20, GRAY)
    c.rect(15, 5, 16, 8, GRAY)
    c.rect(14, 3, 17, 5, DARK)
    for x in (9, 15, 21):
        wheel(c, x, 25, 3)
    c.rect(9, 21, 21, 22, DARK)


def tormenta_polvo(c):
    for k, (y0, col) in enumerate(((7, SAND), (14, ORANGE), (21, BROWN), (27, SAND))):
        for x in range(0, 32):
            y = y0 + 2.2 * math.sin(x / 3.2 + k * 1.6)
            c.rect(x, y - 1.5, x, y + 1.5, col)
    for (x, y) in ((4, 4), (14, 10), (24, 5), (8, 18), (28, 23), (18, 29), (3, 25)):
        c.disc(x, y, 1.4, LIGHT)


def sismometro_seis(c):
    c.rect(0, 27, 31, 31, DBROWN)
    c.disc(16, 24, 9, GRAY)
    c.rect(6, 24, 26, 28, DARK)
    c.disc(13, 19, 3.2, LIGHT)
    c.rect(14, 12, 18, 14, DARK)
    pts = [(0, 30), (6, 30), (8, 26), (11, 33), (14, 28), (17, 31), (19, 29), (22, 30), (31, 30)]
    for (xa, ya), (xb, yb) in zip(pts, pts[1:]):
        c.line(xa, ya, xb, yb, YELLOW, 1)
    for r in (4, 7):                                    # ondas
        c.line(16 - r - 6, 12, 16 - r - 8, 16, LBLUE, 1)
        c.line(16 + r + 6, 12, 16 + r + 8, 16, LBLUE, 1)


def insight(c):
    c.rect(11, 17, 21, 21, GRAY)
    c.rect(11, 17, 21, 18, LIGHT)
    c.disc(6, 11, 6, GOLD)                              # paneles solares circulares
    c.disc(6, 11, 4.5, DBLUE)
    c.disc(26, 11, 6, GOLD)
    c.disc(26, 11, 4.5, DBLUE)
    c.line(6, 17, 11, 18, DARK, 1)
    c.line(26, 17, 21, 18, DARK, 1)
    c.disc(16, 15, 3, LIGHT)                            # cúpula del sismómetro
    c.line(12, 21, 8, 28, DARK, 1)                      # patas
    c.line(20, 21, 24, 28, DARK, 1)
    c.rect(6, 28, 10, 29, DARK)
    c.rect(22, 28, 26, 29, DARK)


def martemoto(c):
    c.rect(0, 16, 31, 31, BROWN)
    c.rect(0, 16, 31, 18, SAND)
    pts = [(14, 16), (17, 20), (13, 24), (18, 28), (15, 32)]
    for (xa, ya), (xb, yb) in zip(pts, pts[1:]):
        c.line(xa, ya, xb, yb, BLACK, 2)
    for (x, y) in ((4, 12), (7, 8), (26, 11), (23, 7)):  # rocas que saltan
        c.disc(x, y, 2, DBROWN)
    for y in (22, 26):                                   # líneas de temblor
        c.line(2, y, 6, y, BLACK, 1)
        c.line(26, y, 30, y, BLACK, 1)


def minutos_luz(c):
    c.disc(5, 22, 5, BLUE)
    c.disc(4, 23, 2.6, GREEN)
    c.disc(27, 22, 5, ORANGE)
    c.disc(26, 21, 1.6, GOLD)
    for x in (11, 15, 19, 23):                           # señal de radio en camino
        c.rect(x, 22, x + 1, 22, WHITE)
    c.disc(17, 22, 1.8, YELLOW)
    c.disc(16, 8, 6, WHITE)                              # reloj
    c.disc(16, 8, 4.4, LIGHT)
    c.line(16, 8, 16, 5, BLACK, 1)
    c.line(16, 8, 19, 9, BLACK, 1)


ICONS = {
    "sol": sol, "moxie": moxie, "electrolisis_co2": electrolisis_co2, "crater_jezero": crater_jezero,
    "crater_gale": crater_gale, "regolito": regolito, "cme": cme, "fulguracion_solar": fulguracion_solar,
    "probioticos": probioticos, "radiacion_cosmica": radiacion_cosmica, "osdr": osdr,
    "perseverance": perseverance, "opportunity": opportunity, "tormenta_polvo": tormenta_polvo,
    "sismometro_seis": sismometro_seis, "insight": insight, "martemoto": martemoto, "minutos_luz": minutos_luz,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    icons = []
    for name, draw in ICONS.items():
        canvas = Canvas()
        draw(canvas)
        canvas.outline()
        canvas.img.save(OUT / (name + ".png"))
        icons.append(canvas.img)
    print("Escritos %d iconos en %s" % (len(icons), OUT))
    if len(sys.argv) > 1:
        scale, cols = 5, 6
        rows = (len(icons) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * (N * scale + 8) + 8, rows * (N * scale + 8) + 8), (22, 30, 60, 255))
        for i, icon in enumerate(icons):
            big = icon.resize((N * scale, N * scale), Image.NEAREST)
            sheet.paste(big, (8 + (i % cols) * (N * scale + 8), 8 + (i // cols) * (N * scale + 8)), big)
        sheet.save(Path(sys.argv[1]) / "glossary_sheet.png")


if __name__ == "__main__":
    main()
