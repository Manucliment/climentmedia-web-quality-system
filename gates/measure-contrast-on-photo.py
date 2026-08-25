#!/usr/bin/env python3
"""Contraste del texto del hero sobre la FOTO, medido de la captura real.

Un texto sobre imagen no se puede comprobar con getComputedStyle: el fondo no es
un color, es cada pixel de la foto ya compuesta con el degradado. Aqui se lee la
region donde va el texto en la captura -que es el resultado real- y se mide el
PEOR pixel, no la media: WCAG se cumple o no en el sitio mas claro.

Sin Pillow ni numpy en el servidor: se decodifica el PNG a crudo con ffmpeg.
"""
import subprocess
import sys
from pathlib import Path

PNG = Path(sys.argv[1])
# Region del texto del hero en la captura de 1280x900 (x0,y0,x1,y1)
X0, Y0, X1, Y1 = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
TEXTO = sys.argv[6] if len(sys.argv) > 6 else "255,255,255"

w, h = X1 - X0, Y1 - Y0
crudo = subprocess.run(
    ["ffmpeg", "-nostdin", "-v", "error", "-i", str(PNG),
     "-vf", f"crop={w}:{h}:{X0}:{Y0}", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
    capture_output=True).stdout

if len(crudo) < w * h * 3:
    sys.exit(f"no se pudo decodificar {PNG}")


def lum(r, g, b):
    def f(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


fg = lum(*[int(x) for x in TEXTO.split(",")])
peor = None
suma = 0
n = 0
for i in range(0, w * h * 3, 3):
    l = lum(crudo[i], crudo[i + 1], crudo[i + 2])
    suma += l
    n += 1
    # el peor caso para texto claro es el pixel de fondo MAS claro
    if peor is None or l > peor:
        peor = l

def ratio(a, b):
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)

media = suma / n
print(f"  region      : {w}x{h} px en ({X0},{Y0})")
print(f"  texto       : rgb({TEXTO})")
print(f"  fondo medio : ratio {ratio(fg, media):.2f}")
print(f"  fondo PEOR  : ratio {ratio(fg, peor):.2f}   <- el que manda")
r = ratio(fg, peor)
# ⚠️ El minimo SE PASA POR ARGUMENTO. La primera version lo fijaba en 3.0 y
# cantaba "PASA" tambien para el ojal, que es texto pequeno y necesita 4.5:
# daba 3.53 y lo dio por bueno. Un medidor con el umbral equivocado no es un
# medidor, es una excusa.
minimo = float(sys.argv[7]) if len(sys.argv) > 7 else 4.5
tipo = "texto grande" if minimo <= 3.0 else "texto normal"
print(f"  minimo AA ({tipo}) {minimo:.2f}  ->  {'PASA' if r >= minimo else 'SUSPENDE'}")
sys.exit(0 if r >= minimo else 1)
