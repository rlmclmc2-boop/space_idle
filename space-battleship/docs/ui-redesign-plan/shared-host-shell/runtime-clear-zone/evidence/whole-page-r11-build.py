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
    study = OUT / "hangar-single-support-study.png"
    next(x for x in root[0] if x.get("id") == "asset1").set("href", "data:image/png;base64," + base64.b64encode(study.read_bytes()).decode())
    module = root[1][2]
    background = module[1]
    card, title, subtitle = module[2:5]
    if name == "01-early-two":
        # Expose the dock's existing central landing disc under the small ship.
        # The old full-width crop centered that disc behind the workbench.
        background.set("viewBox", "430 0 700 845")

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

    if name in ("03-late-eight", "08-late-scroll-bottom"):
        # Show only complete slot rows at the top and bottom parked positions.
        # No half-visible row is presented as an actionable target. Intermediate
        # motion/focus behavior remains an explicit implementation handoff.
        viewport = next(x for x in root.iter() if x.get("id") == "row-viewport")
        viewport[0].set("height", "462")
        outer.set("height", "503")
        inner.set("height", "491")
        track = [x for x in desk if x.get("x") == "790" and x.get("width") == "6"]
        track[0].set("height", "462")
        track[0].set("fill", "#31505b")
        track[1].set("height", "291")
        track[1].set("y", "485" if name == "08-late-scroll-bottom" else "314")
        track[1].set("fill", "#cbb47f")
        track[1].set("width", "8")
        track[1].set("x", "789")
        if name == "08-late-scroll-bottom":
            row_group = next(x for x in desk if x.get("clip-path") == "url(#row-viewport)")
            moved = etree.Element(f"{{{NS}}}g")
            moved.set("transform", "translate(0,-83)")
            for child in list(row_group):
                moved.append(child)
            row_group.append(moved)
        # This is a read-only scroll cue, within the existing table header.
        hint = etree.Element(f"{{{NS}}}text")
        hint.set("x", "548")
        hint.set("y", "305")
        hint.set("font-family", "Noto Sans SC")
        hint.set("font-size", "14")
        hint.set("font-weight", "500")
        hint.set("fill", "#315768")
        hint.text = "↑ 返回武器" if name == "08-late-scroll-bottom" else "↓ 防御还有3槽"
        desk.insert(3, hint)

    png = OUT / f"whole-page-r11-{name}.png"
    with tempfile.TemporaryDirectory(prefix="whole-page-r11-") as temp:
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
