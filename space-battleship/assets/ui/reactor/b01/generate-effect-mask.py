"""Trace moving glass and the two glowing barrel channels in the B01 source plate."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).parent
source = Image.open(ROOT / "active-console.png").convert("RGB")
w, h = source.size

# Motion stays inside the luminous sphere. The polygon is the complete foreground
# metal belt plus a margin wider than the shader's maximum sample displacement.
glass_shape = Image.new("L", source.size)
draw = ImageDraw.Draw(glass_shape)
draw.ellipse((421, 184, 766, 479), fill=255)
draw.polygon([
    (363, 310), (440, 308), (510, 310), (675, 309), (750, 318), (818, 329),
    (818, 376), (750, 361), (676, 353), (510, 351), (440, 358), (363, 382),
], fill=0)
glass_shape = glass_shape.filter(ImageFilter.GaussianBlur(2.0))

src = source.load()
region = glass_shape.load()
mask = Image.new("RGB", source.size)
dst = mask.load()
for y in range(h):
    for x in range(w):
        red, green, blue = src[x, y]
        # Blue energy rather than silver/cyan painted hardware or white braces.
        glass = max(0.0, min(1.0, (blue - red - 34.0) / 55.0)) * region[x, y] / 255.0
        # Both visible barrel bores climb at this slope. Existing amber pixels
        # alone identify the emission surface; pale casing and lower supports fail.
        bore = x <= 227 and (
            abs(y - (103.0 + x * 0.31)) < 10.0 or
            abs(y - (124.0 + x * 0.31)) < 10.0
        )
        warm = min((red - green - 18.0) / 55.0, (green - blue - 21.0) / 65.0, (red - 95.0) / 95.0) if bore else 0.0
        dst[x, y] = (round(255 * glass), round(255 * max(0.0, min(1.0, warm))), 0)

mask.save(ROOT / "effect-mask.png")
