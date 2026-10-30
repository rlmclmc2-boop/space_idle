"""Reproducible *design* assembly from fixed 1440x900 evidence and owner art.

The shared top/nav/battle pixels are copied from the fixed real screens. The
edited source material enters only the module region; it is not runtime art.
"""
from pathlib import Path
import base64
import os
import subprocess
from lxml import etree

HERE = Path(__file__).resolve().parent
NS = "http://www.w3.org/2000/svg"
EQUIPMENT = "e15484ceabfe953605eef132e71b6883a3590bf5"
EQUIPMENT_DIR = "space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept"
REACTOR = {
    "one": ("e8-controlled-combo-1-active.png", "b01-r3-one-source-study.png"),
    "two": ("e8-controlled-combo-2-active.png", "b01-r3-two-source-study.png"),
    "three": ("e8-controlled-combo-3-active.png", "b01-r3-three-source-study.png"),
    "four": ("e8-combo-reactor-max-1440x900.png", "b01-endcap-r2-full-source-study.png"),
}
EQUIPMENT_PLATES = {
    "early": "42-coherent-early.png",
    "middle": "43-coherent-middle.png",
    "late": "44-coherent-late.png",
    "bottom": "45-coherent-bottom.png",
}


def href(data):
    return "data:image/png;base64," + base64.b64encode(data).decode("ascii")


def local(name):
    return href((HERE / name).read_bytes())


def owner(name):
    blob = subprocess.check_output(["git", "show", f"{EQUIPMENT}:{EQUIPMENT_DIR}/{name}"])
    return href(blob)


def add_image(parent, source, x=0, y=0, width=1440, height=900, clip=None, mask=None, stretch=False):
    node = etree.SubElement(parent, f"{{{NS}}}image", href=source, x=str(x), y=str(y), width=str(width), height=str(height))
    if stretch:
        node.set("preserveAspectRatio", "none")
    if clip:
        node.set("clip-path", f"url(#{clip})")
    if mask:
        node.set("mask", f"url(#{mask})")
    return node


def base_svg():
    root = etree.Element(f"{{{NS}}}svg", nsmap={None: NS}, width="1440", height="900", viewBox="0 0 1440 900")
    defs = etree.SubElement(root, f"{{{NS}}}defs")
    for name, rect in {
        "reactor": (0, 65, 808, 835),
        "equipment": (0, 85, 808, 815),
        "equipment-header": (0, 0, 808, 85),
        "public": (808, 0, 632, 900),
        "reactor-top": (0, 0, 808, 65),
    }.items():
        clip = etree.SubElement(defs, f"{{{NS}}}clipPath", id=name)
        etree.SubElement(clip, f"{{{NS}}}rect", x=str(rect[0]), y=str(rect[1]), width=str(rect[2]), height=str(rect[3]))
    filt = etree.SubElement(defs, f"{{{NS}}}filter", id="blend", x="-5%", y="-5%", width="110%", height="110%")
    etree.SubElement(filt, f"{{{NS}}}feGaussianBlur", stdDeviation="8")
    mask = etree.SubElement(defs, f"{{{NS}}}mask", id="reactor-center", maskUnits="userSpaceOnUse", x="0", y="65", width="808", height="835")
    path = etree.SubElement(mask, f"{{{NS}}}path", d="M 95,65 L 720,65 L 720,525 L 780,600 L 780,900 L 30,900 L 30,600 L 95,525 Z", fill="white")
    path.set("filter", "url(#blend)")
    return root


def export(root, stem):
    svg = HERE / f"{stem}.svg"
    png = HERE / f"{stem}.png"
    svg.write_bytes(etree.tostring(root, xml_declaration=True, encoding="utf-8"))
    subprocess.run(["inkscape", str(svg), "--export-filename", str(png)], check=True,
                   env={**os.environ, "FONTCONFIG_FILE": "/tmp/space-idle-fontconfig.xml"})
    return png


def reactor(name, screen, edge_art):
    root = base_svg()
    current = local(screen)
    # Exact source screen underneath retains the original selected nav and battle.
    add_image(root, current)
    add_image(root, local(edge_art), 0, 65, 808, 835, clip="reactor", stretch=True)
    # Keep actual source machine and full interactive desk pixels; architectural
    # returns remain visible across both upper room and lower console cheeks.
    add_image(root, current, mask="reactor-center")
    add_image(root, current, clip="reactor-top")
    return export(root, f"b01-r3-exact-{name}")


def equipment(name, plate):
    root = base_svg()
    real_public = local("e8-combo-equipment-1440x900.png")
    current = owner(plate)
    add_image(root, real_public)
    add_image(root, current, clip="equipment")
    add_image(root, current, clip="equipment-header")
    add_image(root, real_public, clip="public")
    # This is an exact-context *comparison*. The owner plate's wall/desk still
    # hard-stops at x808 and needs an owner-source material revision.
    return export(root, f"e154-source-context-{name}")


if __name__ == "__main__":
    for name, (screen, edge_art) in REACTOR.items():
        print(reactor(name, screen, edge_art))
    for name, plate in EQUIPMENT_PLATES.items():
        print(equipment(name, plate))
