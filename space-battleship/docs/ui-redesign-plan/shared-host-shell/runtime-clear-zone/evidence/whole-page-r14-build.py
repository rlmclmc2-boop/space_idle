"""Compose exact 041 equipment SVG states with the shared rail and a single dock support.

Static design only. Slot rows, controls, battle, and ship art are the original 041 SVG nodes.
"""
from pathlib import Path
import base64
import os
import subprocess
from lxml import etree

ROOT = Path(__file__).resolve().parents[6]
OUT = Path(__file__).resolve().parent
SOURCE = "04149eae7cb9120bcc4830ae3781e16fc16100d1"
BASE = "space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept"
NS = "http://www.w3.org/2000/svg"
STATES = (("29-compact-scene-early", 475), ("30-compact-scene-middle", 394),
          ("31-compact-scene-late", 344), ("32-compact-scene-bottom", 344))

def data(path):
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()

def render(name, _ship_y):
    original = subprocess.check_output(["git", "show", f"{SOURCE}:{BASE}/{name}.svg"], cwd=ROOT)
    root = etree.fromstring(original)
    module = root[1][2]
    defs = root[0]
    # Replace the old pale conceptual header with the existing public rail.
    rail = etree.Element(f"{{{NS}}}image", x="0", y="0", width="1440", height="900")
    rail.set("clip-path", "url(#header)")
    rail.set("href", data(OUT / "r13-public-reference-1440x900.png"))
    root[1].replace(root[1][0], rail)
    battle = etree.Element(f"{{{NS}}}image", x="0", y="0", width="1440", height="900")
    battle.set("clip-path", "url(#battle)")
    battle.set("href", data(OUT / "r13-public-reference-1440x900.png"))
    root[1].replace(root[1][1], battle)
    next(x for x in defs if x.get("id") == "module")[0].set("y", "65")
    next(x for x in defs if x.get("id") == "module")[0].set("height", "835")
    module[1].set("y", "65")
    module[1].set("height", "835")
    # One background source: the dock's actual support surface, not another sheet over it.
    next(x for x in defs if x.get("id") == "asset1").set("href", data(OUT / "hangar-cantilever-support-study.png"))
    if name.endswith("early"):
        module[1].set("viewBox", "430 0 700 845")
    # Remove the floating blue information card. Its ship identity is engraved
    # into the existing workbench heading, so ship + controls share one carrier.
    plate, title, subtitle = module[2:5]
    ship_name = title.text
    for item in (plate, title, subtitle):
        module.remove(item)
    # Replace, rather than overpaint, the two plain workbench backing rectangles.
    desk = module[-1]
    outer, inner = desk[0:2]
    x, y, w, h = [float(outer.get(k)) for k in ("x", "y", "width", "height")]
    # The original heading begins only 25px below the backing top; lift the
    # replacement's physical rim so Noto ink has real clearance inside it.
    y -= 14
    h += 14
    if h >= 400:
        h += 24  # keep the last identity-only row clear of the physical lower rim
    else:
        h += 35  # both early fee lines must stay above the short face's lower rim
    desk[2].set("x", "360")
    desk[2].text = ship_name + " · 工作台"
    desk[2].set("font-size", "18")
    asset = OUT / ("workbench-short-face-study.png" if h < 400 else "workbench-tall-face-study.png")
    image_w, image_h = ((1559, 1009) if h < 400 else (1194, 1317))
    crop = ("10 165 1540 715" if h < 400 else "18 75 1160 1165")
    face = etree.Element(f"{{{NS}}}svg", x=str(x), y=str(y), width=str(w), height=str(h), viewBox=crop,
                         preserveAspectRatio="none")
    face.append(etree.Element(f"{{{NS}}}image", x="0", y="0", width=str(image_w), height=str(image_h),
                              href=data(asset)))
    desk.replace(outer, face)
    desk.remove(inner)
    # Replace old alternating flat row slabs with the one continuous enamel
    # surface. Keep section bars, separators, text, icons and controls intact.
    for group in desk.iter():
        for row in list(group):
            if (etree.QName(row).localname == "rect" and row.get("x") == "350"
                    and row.get("width") == "440"
                    and row.get("fill") in ("#e0ebe3", "#e8e8dc")):
                group.remove(row)
    # The source's parked-scroll summary is still an identity cue, but its
    # separate horizontal slabs straddled the physical frame. Engrave the cue
    # directly in the same enamel face; leave all complete rows untouched.
    row_group = next(x for x in desk if x.get("clip-path") == "url(#row-viewport)")
    if name.endswith("late"):
        for child in list(row_group):
            if etree.QName(child).localname == "rect" and child.get("y") in ("803", "821"):
                row_group.remove(child)
            elif etree.QName(child).localname == "text" and child.get("y") == "816":
                row_group.remove(child)
            elif etree.QName(child).localname == "text" and child.get("y") == "835":
                child.text = "↓ 防御 3槽 · 防御1 装甲 Lv.1"
                child.set("y", "825")
                child.set("fill", "#315667")
    elif name.endswith("bottom"):
        for child in list(row_group):
            if etree.QName(child).localname == "rect" and child.get("y") == "314" and child.get("height") == "33":
                row_group.remove(child)
            elif etree.QName(child).localname == "text" and child.get("y") == "337":
                child.text = "↑ 武器3 · 舰炮 · Lv.1"
                child.set("y", "333")
                child.set("fill", "#315667")
    out = OUT / f"whole-page-r14-{name}.png"
    svg = OUT / f"whole-page-r14-{name}.svg"
    svg.write_bytes(etree.tostring(root, xml_declaration=True, encoding="utf-8"))
    subprocess.run(["inkscape", str(svg), "--export-filename", str(out)], check=True,
                   env={**os.environ, "FONTCONFIG_FILE": "/tmp/space-idle-fontconfig.xml"})
    return out

if __name__ == "__main__":
    for state, ship in STATES:
        print(render(state, ship))
