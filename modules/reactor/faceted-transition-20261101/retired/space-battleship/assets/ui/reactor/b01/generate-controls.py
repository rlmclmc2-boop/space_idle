"""Build the text-free, scale-specific B01 control glass and machined hardware."""
from pathlib import Path
from PIL import Image, ImageDraw
import math

OUT = Path(__file__).parent


def blend(a, b, t):
    return tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(4))


def vertical(size, stops, radius):
    w, h = size
    im = Image.new("RGBA", size)
    px = im.load()
    for y in range(h):
        p = y / max(h - 1, 1)
        for i in range(len(stops) - 1):
            if p <= stops[i + 1][0]:
                lo, hi = stops[i], stops[i + 1]
                color = blend(lo[1], hi[1], (p - lo[0]) / (hi[0] - lo[0]))
                break
        for x in range(w):
            px[x, y] = color
    mask = Image.new("L", size)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=255)
    im.putalpha(mask)
    return im


def frame(size, radius, inner, name):
    w, h = size
    im = Image.new("RGBA", size)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=(16, 27, 32, 224), outline=(12, 17, 19, 250), width=2)
    d.rounded_rectangle((2, 2, w - 3, h - 3), radius - 1, outline=(199, 158, 94, 220), width=1)
    d.rounded_rectangle((4, 4, w - 5, h - 5), max(radius - 3, 1), outline=(248, 222, 160, 153), width=1)
    d.rounded_rectangle((inner, inner, w - 1 - inner, h - 1 - inner), max(radius - inner, 1), fill=(0, 0, 0, 0))
    d.line((radius, 3, w - 1 - radius, 3), fill=(255, 236, 192, 168), width=1)
    d.line((radius, h - 3, w - 1 - radius, h - 3), fill=(6, 12, 18, 218), width=2)
    im.save(OUT / name)


frame((545, 31), 7, 5, "meter-frame.png")

# One continuous inset pane carries the slider, percentage and multiplier.
row = vertical((370, 41), [(0, (15, 42, 55, 190)), (0.17, (5, 22, 33, 236)), (0.64, (4, 18, 30, 247)), (1, (10, 28, 38, 220))], 7)
d = ImageDraw.Draw(row)
d.rounded_rectangle((0, 0, 369, 40), 7, outline=(141, 155, 148, 190), width=1)
d.line((9, 2, 361, 2), fill=(205, 179, 127, 110), width=1)
d.line((174, 7, 174, 33), fill=(111, 151, 164, 110), width=1)
d.line((274, 7, 274, 33), fill=(111, 151, 164, 110), width=1)
row.save(OUT / "row-instrument.png")

# A single rounded profile is shared by the dark channel, colored glass fill
# and surrounding machined shell. Their 148×13 opening matches PowerTrack.
s = 4
shell = vertical((170*s, 33*s), [
    (0, (214, 181, 119, 236)), (0.13, (115, 91, 61, 252)),
    (0.49, (27, 53, 63, 255)), (0.76, (16, 31, 41, 255)),
    (1, (105, 79, 49, 255)),
], 14*s)
d = ImageDraw.Draw(shell)
d.rounded_rectangle((1*s, 1*s, 169*s-1, 32*s), 13*s, outline=(236, 209, 153, 240), width=1*s)
d.rounded_rectangle((3*s, 3*s, 167*s-1, 30*s), 11*s, outline=(12, 22, 28, 245), width=2*s)
d.rounded_rectangle((10*s, 9*s, 160*s, 24*s), 7*s, fill=(0, 0, 0, 0))
d.arc((8*s, 7*s, 162*s, 26*s), 184, 356, fill=(221, 191, 132, 195), width=1*s)
shell.resize((170,33), Image.Resampling.LANCZOS).save(OUT / "slider-shell.png")

channel = vertical((148*s, 13*s), [
    (0, (3, 13, 21, 255)), (0.24, (8, 29, 40, 255)),
    (0.66, (7, 24, 34, 255)), (1, (1, 8, 15, 255)),
], 6*s)
d = ImageDraw.Draw(channel)
d.rounded_rectangle((0, 0, 148*s-1, 13*s-1), 6*s, outline=(63, 106, 120, 220), width=1*s)
channel.resize((148,13), Image.Resampling.LANCZOS).save(OUT / "slider-channel.png")

glow = vertical((148*s, 13*s), [
    (0, (245, 247, 241, 255)), (0.18, (255, 255, 255, 255)),
    (0.47, (239, 240, 231, 255)), (0.78, (190, 197, 197, 255)),
    (1, (113, 128, 138, 255)),
], 6*s)
glow.resize((148,13), Image.Resampling.LANCZOS).save(OUT / "slider-glass-fill.png")

s = 4
im = Image.new("RGBA", (31*s, 31*s))
d = ImageDraw.Draw(im)
box = (1*s, 1*s, 30*s, 30*s)
d.ellipse(box, fill=(20, 29, 34, 255), outline=(15, 15, 15, 255), width=2*s)
d.ellipse((3*s, 2*s, 28*s, 27*s), fill=(178, 148, 91, 255), outline=(255, 237, 185, 255), width=s)
d.ellipse((5*s, 4*s, 26*s, 25*s), fill=(29, 38, 44, 255), outline=(107, 75, 36, 255), width=s)
for y in range(7*s, 24*s):
    for x in range(7*s, 24*s):
        dx, dy = (x/s - 15), (y/s - 14)
        if dx*dx + dy*dy <= 8.8*8.8:
            light = max(0, min(1, 0.58 - dy/27 - dx/44 + 0.10*math.cos(dx/3)))
            im.putpixel((x,y), (round(153+95*light), round(127+100*light), round(75+115*light), 255))
d.ellipse((7*s, 6*s, 24*s, 23*s), outline=(255, 239, 199, 255), width=s)
d.arc((9*s, 8*s, 22*s, 21*s), 205, 327, fill=(255, 255, 236, 245), width=s)
im.resize((31,31), Image.Resampling.LANCZOS).save(OUT / "slider-knob.png")
