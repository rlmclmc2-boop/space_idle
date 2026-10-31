"""Rebuild the eight B01 source plates from the e8 base and painted side studies.

Editor-only: requires Pillow and NumPy. Generated studies supply architecture only;
the established machines, reactor, control wells and masks remain from e8.
"""

from io import BytesIO
from pathlib import Path
import subprocess

import numpy as np
from PIL import Image


HERE = Path(__file__).resolve().parent
REPO = next(p for p in HERE.parents if (p / ".git").exists())
BASE = REPO / "space-battleship/assets/ui/reactor/b01"
BASELINE = "e8ec7c447d303e01773d31b8798d6ff630520229"
STUDIES = {
    "one": HERE / "endcap-source/one-study.png",
    "two": HERE / "endcap-source/two-study.png",
    "locked": HERE / "endcap-source/three-study.png",
    "four": HERE / "endcap-source/four-study.png",
}


def baseline_plate(path: Path) -> np.ndarray:
    relative = path.relative_to(REPO).as_posix()
    payload = subprocess.check_output(
        ["git", "show", f"{BASELINE}:{relative}"], cwd=REPO
    )
    with Image.open(BytesIO(payload)) as image:
        rgb = image.convert("RGB")
        if rgb.size == (1187, 1325):
            # The e8 two-idle source was a pixel shorter than its active partner.
            extra = Image.new("RGB", (1187, 1326))
            extra.paste(rgb, (0, 0))
            extra.paste(rgb.crop((0, 1324, 1187, 1325)), (0, 1325))
            rgb = extra
        assert rgb.size == (1187, 1326), path
        return np.asarray(rgb, dtype=np.float32)


def main() -> None:
    lower_side = np.asarray(
        Image.open(STUDIES["one"]).convert("RGB"), dtype=np.float32
    )
    y = np.arange(1326, dtype=np.float32)
    x = np.arange(1187, dtype=np.float32)[None, :]
    # Room returns are wide above the console and narrow into the existing
    # console side cheeks. The original controls and their dividers stay intact.
    width = np.where(
        y < 690,
        145.0,
        np.where(y > 790, 48.0, 145.0 - (y - 690.0) * 97.0 / 100.0),
    )
    left = np.clip((width[:, None] - x) / 20.0, 0, 1)
    right = np.clip((x - (1187 - width[:, None])) / 20.0, 0, 1)
    alpha = np.maximum(left, right)[:, :, None]

    for mode, study in STUDIES.items():
        stem = "" if mode == "four" else f"{mode}-"
        idle_path = BASE / f"{stem}idle-console.png"
        active_path = BASE / f"{stem}active-console.png"
        idle = baseline_plate(idle_path)
        active = baseline_plate(active_path)
        reference = np.asarray(Image.open(study).convert("RGB"), dtype=np.float32)
        assert reference.shape == idle.shape == active.shape
        # The generated multi-row sketches moved divider lines. Their lower
        # cheeks share the single-row study instead, while the original row
        # geometry remains untouched in the center and blend region.
        reference[790:] = lower_side[790:]
        for path, source, is_active in (
            (idle_path, idle, False),
            (active_path, active, True),
        ):
            edge = (
                np.clip(reference + (active - idle), 0, 255)
                if is_active
                else reference
            )
            composed = np.uint8(np.clip(np.round(source * (1 - alpha) + edge * alpha), 0, 255))
            assert np.array_equal(composed[:, 145:1042], np.uint8(source[:, 145:1042]))
            Image.fromarray(composed, "RGB").save(path)
            print(f"{path.name}: 1187x1326; center unchanged")


if __name__ == "__main__":
    main()
