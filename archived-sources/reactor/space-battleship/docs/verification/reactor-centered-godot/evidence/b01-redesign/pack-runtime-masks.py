"""Rebuild the B01 runtime sampling masks without changing their pixel channels.

Editor-only. Requires Pillow/NumPy. Keep fix_alpha_border=false in the two
corresponding Godot .png.import files: alpha is data, not transparency.
"""

from pathlib import Path

import numpy as np
from PIL import Image


HERE = Path(__file__).resolve().parent
REPO = next(p for p in HERE.parents if (p / ".git").exists())
ASSETS = REPO / "space-battleship/assets/ui/reactor/b01"


def rgb(name: str) -> np.ndarray:
    with Image.open(ASSETS / name) as image:
        pixels = np.asarray(image.convert("RGB"))
    assert pixels.shape == (1326, 1187, 3), name
    return pixels


def main() -> None:
    pipe = rgb("pipe-mask.png")
    effect = rgb("effect-mask.png")
    module = rgb("module-mask.png")
    # RGBA channel order: pipe R/G/B + core-effect R.
    pipe_effect = np.dstack((pipe, effect[:, :, 0]))
    # RGBA channel order: module R/G + muzzle-effect G + molten-effect B.
    module_effect = np.dstack((module[:, :, :2], effect[:, :, 1:3]))
    for name, pixels in (
        ("pipe-effect-mask.png", pipe_effect),
        ("module-effect-mask.png", module_effect),
    ):
        Image.fromarray(pixels, "RGBA").save(ASSETS / name)
        print(f"{name}: {pixels.shape}; original channels unchanged")


if __name__ == "__main__":
    main()
