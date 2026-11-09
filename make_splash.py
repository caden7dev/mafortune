# make_splash.py  ->  pip install pillow
from PIL import Image, ImageDraw

SRC = "assets/icon/logoapp.jpg"        # ton logo carré d'origine
OUT = "assets/icon/splash_rond.png"

CANVAS = 1152     # taille totale
DIAM = 640        # diamètre du rond visible (reste dans la zone sûre)

img = Image.open(SRC).convert("RGBA")
side = min(img.size)
left, top = (img.width - side) // 2, (img.height - side) // 2
img = img.crop((left, top, left + side, top + side)).resize((DIAM, DIAM), Image.LANCZOS)

mask = Image.new("L", (DIAM, DIAM), 0)
ImageDraw.Draw(mask).ellipse((0, 0, DIAM - 1, DIAM - 1), fill=255)
img.putalpha(mask)

canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
canvas.paste(img, ((CANVAS - DIAM) // 2, (CANVAS - DIAM) // 2), img)
canvas.save(OUT)