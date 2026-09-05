"""Generate the dock ring texture.

When FarmMap moves the map content to the centre of the screen, the corner
needs to still look like a minimap so the minimap buttons have somewhere to
live. Blizzard's own ring belongs to the map, not to the cluster, so we draw
our own socket: a dark disc with a gold ring around it, matching the gold of
the FarmMap icon.

Drawn at 8x and downsampled, which is the cheapest way to get clean
antialiased curves out of Pillow.

    python tools/make_ring.py
"""
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "FarmMap", "Media", "farmmap-ring.tga")

SIZE = 128
SS = 8               # supersample factor
BIG = SIZE * SS

DISC = (10, 16, 26, 130)      # translucent dark socket
GOLD_OUT = (120, 88, 30, 255)
GOLD_MID = (198, 158, 74, 255)
GOLD_IN = (240, 214, 140, 255)


def main():
    im = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    pad = 6 * SS
    outer = BIG - pad
    band = 9 * SS  # ring thickness at final scale

    def circle(inset, fill=None, outline=None, width=0):
        box = (pad + inset, pad + inset, outer - inset, outer - inset)
        d.ellipse(box, fill=fill, outline=outline, width=width)

    # Socket first, so the ring sits on top of its edge.
    circle(band, fill=DISC)

    # Three concentric passes give the ring a little depth without a gradient.
    circle(0, outline=GOLD_OUT, width=band)
    circle(int(band * 0.28), outline=GOLD_MID, width=int(band * 0.5))
    circle(int(band * 0.72), outline=GOLD_IN, width=max(1, int(band * 0.16)))

    im = im.resize((SIZE, SIZE), Image.LANCZOS)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    im.save(OUT, format="TGA", compression=None)

    print("wrote %s" % OUT)
    print("  %dx%d, %d bytes" % (SIZE, SIZE, os.path.getsize(OUT)))
    print("  corner alpha %d, centre alpha %d, ring alpha %d"
          % (im.getpixel((1, 1))[3],
             im.getpixel((SIZE // 2, SIZE // 2))[3],
             im.getpixel((SIZE // 2, 8))[3]))


if __name__ == "__main__":
    main()
