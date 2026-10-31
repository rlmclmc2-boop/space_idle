"""Separate baked device illumination from the mechanical source surfaces.

Run from any directory: python assets/ui/reactor/b01/split_work_surfaces.py
The *-lit-source.png files are immutable input renders. Work PNGs contain only
the colored emissive pixels; Godot applies Owner load to them at runtime.
"""
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parent
BOUNDS = {
    "weapons": (0.00, 0.17, 0.29, 0.48),
    "defence": (0.43, 0.06, 1.00, 0.84),
    "smelting": (0.34, 0.38, 0.80, 0.88),
    "condensation": (0.34, 0.12, 0.87, 0.90),
}


def build(kind: str) -> None:
    source = Image.open(ROOT / f"modular-{kind}-lit-source.png").convert("RGBA")
    pixels = np.asarray(source, dtype=np.float32) / 255.0
    h, w = pixels.shape[:2]
    y, x = np.mgrid[:h, :w]
    u = (x + 0.5) / w
    v = (y + 0.5) / h
    r, g, b, alpha = (pixels[:, :, i] for i in range(4))

    if kind == "defence":
        # The blue shield field is inside its real circular rim. Metal and
        # glass outside the dish retain their source colors and highlights.
        region = np.clip((1.0 - np.sqrt(((u - .77) / .30) ** 2 + ((v - .43) / .45) ** 2)) * 9.0, 0, 1)
        chroma = np.clip((b - r * 1.06) * 5.0, 0, 1) * np.clip((b - g * .91) * 5.0, 0, 1)
        strength = .98
    elif kind == "smelting":
        # Only the furnace throat and the molten channel, not the amber
        # fasteners and pipework on the machine's outer body.
        throat = np.clip((1.0 - np.sqrt(((u - .53) / .20) ** 2 + ((v - .61) / .30) ** 2)) * 7.0, 0, 1)
        region = throat
        chroma = np.clip((r - b * 1.15) * 5.0, 0, 1) * np.clip((r - g * .88) * 5.0, 0, 1)
        strength = .97
    elif kind == "condensation":
        # Glass shell and metal cage remain; violet crystal emissive faces
        # and their immediate reflections move to the load-driven surface.
        chamber = np.clip((1.0 - np.sqrt(((u - .60) / .30) ** 2 + ((v - .52) / .49) ** 2)) * 8.0, 0, 1)
        region = chamber
        chroma = np.clip((b - g * 1.04) * 5.0, 0, 1) * np.clip((r - g * 1.01) * 4.0, 0, 1)
        strength = .98
    else:
        # Gun metal stays warm; only the muzzle's inner amber charge is
        # removed from the idle surface.
        muzzle = np.maximum(
            np.clip((1.0 - np.sqrt(((u - .075) / .09) ** 2 + ((v - .275) / .07) ** 2)) * 5.0, 0, 1),
            np.clip((1.0 - np.sqrt(((u - .105) / .09) ** 2 + ((v - .39) / .07) ** 2)) * 5.0, 0, 1),
        )
        region = muzzle
        chroma = np.clip((r - b * 1.5) * 2.7, 0, 1) * np.clip((r - g * 1.08) * 3.5, 0, 1)
        strength = .80

    x0, y0, x1, y1 = BOUNDS[kind]
    bounds_mask = (u >= x0) & (u <= x1) & (v >= y0) & (v <= y1)
    mask = np.clip(region * chroma * strength * bounds_mask * alpha, 0, 1)

    # Preserve local shape, texture and silhouette in the idle layer. A
    # restrained neutral response reads as unpowered glass/hot metal.
    luma = r * .23 + g * .68 + b * .09
    if kind == "defence":
        neutral = np.stack((luma * .48, luma * .60, luma * .67), axis=-1)
    elif kind == "condensation":
        neutral = np.stack((luma * .55, luma * .50, luma * .61), axis=-1)
    else:
        neutral = np.stack((luma * .61, luma * .56, luma * .51), axis=-1)
    base = pixels.copy()
    base[:, :, :3] = pixels[:, :, :3] * (1 - mask[:, :, None]) + neutral * mask[:, :, None]

    # The original lit color is the emissive material map, with per-pixel
    # alpha following the removed field. No full plate or text is sampled.
    emission = np.zeros_like(pixels)
    emission[:, :, :3] = pixels[:, :, :3]
    emission[:, :, 3] = mask
    crop = (int(np.floor(x0 * w)), int(np.floor(y0 * h)), int(np.ceil(x1 * w)), int(np.ceil(y1 * h)))
    Image.fromarray(np.uint8(np.clip(base * 255, 0, 255))).save(ROOT / f"modular-{kind}.png")
    Image.fromarray(np.uint8(np.clip(emission * 255, 0, 255))).crop(crop).save(ROOT / f"modular-{kind}-work.png")
    print(kind, "work pixels", int((mask > .05).sum()), "crop", crop)


for module in BOUNDS:
    build(module)


def build_core() -> None:
    """Move the globe's blue plasma into the existing core event viewport."""
    source = Image.open(ROOT / "modular-core-lit-source.png").convert("RGBA")
    pixels = np.asarray(source, dtype=np.float32) / 255.0
    h, w = pixels.shape[:2]
    y, x = np.mgrid[:h, :w]
    u = (x + .5) / w
    v = (y + .5) / h
    r, g, b, alpha = (pixels[:, :, i] for i in range(4))
    globe = np.clip((1.0 - np.sqrt(((u - .50) / .39) ** 2 + ((v - .515) / .26) ** 2)) * 9.0, 0, 1)
    blue = np.clip((b - r * 1.05) * 4.2, 0, 1) * np.clip((b - g * .94) * 4.2, 0, 1)
    mask = np.clip(globe * blue * .83 * alpha, 0, 1)
    luma = r * .23 + g * .68 + b * .09
    neutral = np.stack((luma * .47, luma * .55, luma * .62), axis=-1)
    base = pixels.copy()
    base[:, :, :3] = pixels[:, :, :3] * (1 - mask[:, :, None]) + neutral * mask[:, :, None]
    emission = np.zeros_like(pixels)
    emission[:, :, :3] = pixels[:, :, :3]
    emission[:, :, 3] = mask
    # The runtime core field occupies stage (283,95)..(527,315), which maps
    # to these source pixels under the existing 1187x1326 -> 808x835 scale.
    crop = (31, 151, 389, 500)
    Image.fromarray(np.uint8(np.clip(base * 255, 0, 255))).save(ROOT / "modular-core.png")
    Image.fromarray(np.uint8(np.clip(emission * 255, 0, 255))).crop(crop).save(ROOT / "modular-core-work.png")
    print("core", "work pixels", int((mask > .05).sum()), "crop", crop)


build_core()
