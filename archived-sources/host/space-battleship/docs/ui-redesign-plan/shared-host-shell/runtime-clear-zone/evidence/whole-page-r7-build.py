"""Render a source-bound whole-page equipment organization study.

This reads the fixed a1 static SVG designs from Git. It changes only the visible
hangar treatment and the existing ship-identity plate. It does not generate game
runtime assets or alter the slot controls, ship illustration, or battle picture.
"""

from pathlib import Path
import subprocess
import base64
import os
import tempfile
from lxml import etree


ROOT = Path(__file__).resolve().parents[6]
OUT = Path(__file__).resolve().parent
SOURCE = "a1a13a9902ef2b8cc7ce743bcc6b57d3862861c6"
BASE = (
    "space-battleship/docs/verification/equipment-hangar-godot/"
    "workbench-optical-revision/inline-slot-workbench-concept"
)
NS = "http://www.w3.org/2000/svg"


def source(name):
    return subprocess.check_output(
        ["git", "show", f"{SOURCE}:{BASE}/{name}.svg"], cwd=ROOT
    )


def make(name, ship_y):
    root = etree.fromstring(source(name))
    # Replace the obsolete beige design placeholder with the actual current
    # public equipment rail, preserving its exact 808x85 pixels and controls.
    rail = OUT / "eea-combo-equipment-1440x900.png"
    header_use = root[1][0]
    header = etree.Element(f"{{{NS}}}image")
    header.set("x", "0")
    header.set("y", "0")
    header.set("width", "1440")
    header.set("height", "900")
    header.set("clip-path", "url(#header)")
    header.set("href", "data:image/png;base64," + base64.b64encode(rail.read_bytes()).decode())
    root[1].replace(header_use, header)
    module = root[1][2]
    background = module[1]
    card, title, subtitle = module[2:5]

    # Regrade the *source hangar image* that remains visible around the ship.
    # This is one stage-image treatment, rather than an extra overlay panel.
    defs = root[0]
    color = etree.SubElement(defs, f"{{{NS}}}filter")
    color.set("id", "hangar-r6-grade")
    color.set("x", "0")
    color.set("y", "0")
    color.set("width", "1")
    color.set("height", "1")
    sat = etree.SubElement(color, f"{{{NS}}}feColorMatrix")
    sat.set("type", "saturate")
    sat.set("values", "0.58")
    transfer = etree.SubElement(color, f"{{{NS}}}feComponentTransfer")
    for tag, slope, intercept in (("feFuncR", "0.35", "0.012"),
                                  ("feFuncG", "0.47", "0.020"),
                                  ("feFuncB", "0.61", "0.038")):
        channel = etree.SubElement(transfer, f"{{{NS}}}{tag}")
        channel.set("type", "linear")
        channel.set("slope", slope)
        channel.set("intercept", intercept)
    background.set("filter", "url(#hangar-r6-grade)")

    # Keep the identity plate itself. Put it directly above the ship's visible
    # nose so early and late views read as a single ship/operation composition.
    top = ship_y - 83
    card.set("y", str(top))
    title.set("y", str(top + 28))
    subtitle.set("y", str(top + 53))
    card.set("fill", "#173240")
    card.set("stroke", "#76979d")

    # Grade the existing structural and operation surfaces by role. Keep the
    # original row capacity, controls and exact table geometry intact.
    desk = module[7]
    outer, inner = desk[0:2]
    outer.set("fill", "#223d4b")
    outer.set("stroke", "#91aeb1")
    inner.set("stroke", "#839e9d")
    face = next(x for x in defs if x.get("id") == "face")
    face[0].set("stop-color", "#e7ebe2")
    face[1].set("stop-color", "#cbd7d0")

    png = OUT / f"whole-page-r7-{name}.png"
    with tempfile.TemporaryDirectory(prefix="whole-page-r7-") as temp:
        svg = Path(temp) / f"{name}.svg"
        svg.write_bytes(etree.tostring(root, xml_declaration=True, encoding="UTF-8"))
        subprocess.run(
            ["inkscape", str(svg), "--export-filename", str(png)],
            check=True,
            env={**os.environ, "FONTCONFIG_FILE": "/tmp/space-idle-fontconfig.xml"},
        )
    return png


if __name__ == "__main__":
    for state, ship_y in (("01-early-two", 475), ("02-middle-five", 394),
                          ("03-late-eight", 344), ("08-late-scroll-bottom", 344)):
        print(make(state, ship_y))
