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

# The actual furnace mouth is a compact vertical aperture at source x205–270,
# followed by the molten stream and tray. The black chassis and support rails
# adjacent to it are excluded before any animation is evaluated.
smelt_shape = Image.new("L", source.size)
draw = ImageDraw.Draw(smelt_shape)
draw.polygon([(205, 501), (257, 499), (271, 526), (262, 566), (247, 582), (219, 575), (205, 542)], fill=255)
draw.polygon([(242, 548), (281, 551), (325, 568), (329, 588), (278, 587), (242, 574)], fill=255)
smelt_shape = smelt_shape.filter(ImageFilter.GaussianBlur(1.5))

# The crystal motion belongs behind the cylinder glass. The exposed crystals,
# left conveyor, right column and pale lower pedestal remain painted foreground.
crystal_shape = Image.new("L", source.size)
draw = ImageDraw.Draw(crystal_shape)
draw.polygon([(993, 453), (1063, 453), (1064, 552), (1056, 566), (1002, 566), (994, 550)], fill=255)
crystal_shape = crystal_shape.filter(ImageFilter.GaussianBlur(1.5))

shield_shape = Image.new("L", source.size)
draw = ImageDraw.Draw(shield_shape)
draw.polygon([(1082, 70), (1186, 50), (1186, 287), (1090, 265), (1074, 227), (1077, 111)], fill=255)
shield_shape = shield_shape.filter(ImageFilter.GaussianBlur(2.0))

# The conduit's bright centerlines, traced on the source plate (source pixels).
def band(x, y, x0, x1, y0, slope, half_width):
    if x < x0 or x > x1:
        return 0.0
    return max(0.0, min(1.0, (half_width - abs(y - (y0 + slope * (x - x0)))) / 4.0))

src = source.load()
region = glass_shape.load()
furnace = smelt_shape.load()
crystal_window = crystal_shape.load()
shield_dome = shield_shape.load()
mask = Image.new("RGB", source.size)
dst = mask.load()
module_mask = Image.new("RGB", source.size)
module_dst = module_mask.load()
pipe_mask = Image.new("RGB", source.size)
pipe_dst = pipe_mask.load()
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
        molten = min((red - green - 13.0) / 48.0, (green - blue - 17.0) / 58.0, (red - 110.0) / 85.0) * furnace[x, y] / 255.0
        dst[x, y] = (round(255 * glass), round(255 * max(0.0, min(1.0, warm))), round(255 * max(0.0, min(1.0, molten))))

        violet = max(0.0, min(1.0, (blue - green - 22.0) / 65.0, (red - green - 4.0) / 56.0))
        blue_glass = max(0.0, min(1.0, (blue - red - 37.0) / 62.0))
        module_dst[x, y] = (round(255 * violet * crystal_window[x, y] / 255.0), round(255 * blue_glass * shield_dome[x, y] / 255.0), 0)

        colored_glass = max(0.0, min(1.0, max(blue - red - 30.0, red - green - 22.0, blue - green - 26.0) / 68.0))
        colored_glass *= max(0.0, min(1.0, (max(red, green, blue) - 132.0) / 72.0))
        upper = max(band(x, y, 320, 470, 212, 0.40, 17), band(x, y, 790, 951, 271, -0.38, 17))
        lower_iron = band(x, y, 310, 475, 545, -0.76, 15)
        lower_crystal = band(x, y, 770, 950, 418, 0.75, 15)
        pipe_dst[x, y] = (round(255 * blue_glass * upper), round(255 * colored_glass * lower_iron), round(255 * colored_glass * lower_crystal))

mask.save(ROOT / "effect-mask.png")
module_mask.save(ROOT / "module-mask.png")
pipe_mask.save(ROOT / "pipe-mask.png")
