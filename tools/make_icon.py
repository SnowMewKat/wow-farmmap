"""Convert the FarmMap icon art into a texture WoW can load.

The client cannot read PNG. It reads BLP and TGA, and wants power-of-two
dimensions. The source art is an opaque medallion on a black field, so the
black has to become transparency or the minimap button shows a black square.

Keying every dark pixel would punch holes in the artwork's own black outlines,
so instead we flood fill inwards from the four corners: only black that is
connected to the edge becomes transparent.

    pip install pillow
    python tools/make_icon.py <source.png>
"""
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "FarmMap", "Media", "farmmap-icon.tga")

SIZE = 64          # final texture, power of two
SENTINEL = (255, 0, 255)
THRESHOLD = 60     # how close to the corner colour still counts as background


def main(src_path):
    src = Image.open(src_path).convert("RGB")

    # 1. Mark edge-connected background with a colour the art does not contain.
    marked = src.copy()
    w, h = marked.size
    for corner in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        ImageDraw.floodfill(marked, corner, SENTINEL, thresh=THRESHOLD)

    # 2. Anything still holding the sentinel is background.
    alpha = Image.new("L", (w, h), 255)
    marked_px = marked.load()
    alpha_px = alpha.load()
    for y in range(h):
        for x in range(w):
            if marked_px[x, y] == SENTINEL:
                alpha_px[x, y] = 0

    out = src.copy()
    out.putalpha(alpha)

    # 3. Trim the empty margin so the medallion fills the texture.
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)

    # 4. Square it off, then downscale. LANCZOS gives us clean antialiased edges.
    side = max(out.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(out, ((side - out.size[0]) // 2, (side - out.size[1]) // 2))
    square = square.resize((SIZE, SIZE), Image.LANCZOS)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    # WoW wants uncompressed 32 bit TGA.
    square.save(OUT, format="TGA", compression=None)

    opaque = sum(1 for p in square.getdata() if p[3] > 0)
    total = SIZE * SIZE
    print("wrote %s" % OUT)
    print("  %dx%d, %d bytes" % (SIZE, SIZE, os.path.getsize(OUT)))
    print("  %.0f%% of pixels opaque (corners should be clear)" % (100.0 * opaque / total))
    print("  corner alpha: %d, centre alpha: %d"
          % (square.getpixel((1, 1))[3], square.getpixel((SIZE // 2, SIZE // 2))[3]))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1])
