"""Source-bound B01 endcap design preview; not a runtime texture or shader.

It retains every pixel of the fixed shared 1440x900 screenshot except the
outer 60px of the B01 stage, which take a feathered architectural edge study.
The eight 1187x1326 source plates/masks and active center must be revised by
the reactor owner before any implementation; this design does not change them.
"""
from pathlib import Path
import base64
import os
import subprocess
from lxml import etree

OUT = Path(__file__).resolve().parent
SOURCES = {
    "one": "e8-controlled-combo-1-active.png",
    "two": "e8-controlled-combo-2-active.png",
    "three": "e8-controlled-combo-3-active.png",
    "four": "e8-combo-reactor-max-1440x900.png",
}
NS = "http://www.w3.org/2000/svg"

def href(path):
    return "data:image/png;base64," + base64.b64encode((OUT / path).read_bytes()).decode()

def render(name, base):
    root = etree.Element(f"{{{NS}}}svg", nsmap={None: NS}, width="1440", height="900", viewBox="0 0 1440 900")
    defs = etree.SubElement(root, f"{{{NS}}}defs")
    for direction, start, end in (("left", "0%", "100%"), ("right", "100%", "0%")):
        grad = etree.SubElement(defs, f"{{{NS}}}linearGradient", id=direction, x1=start, y1="0%", x2=end, y2="0%")
        etree.SubElement(grad, f"{{{NS}}}stop", offset="0%", **{"stop-color": "white"})
        etree.SubElement(grad, f"{{{NS}}}stop", offset="100%", **{"stop-color": "black"})
    mask = etree.SubElement(defs, f"{{{NS}}}mask", id="endcaps", maskUnits="userSpaceOnUse", x="0", y="65", width="808", height="460")
    etree.SubElement(mask, f"{{{NS}}}rect", x="0", y="65", width="60", height="460", fill="url(#left)")
    etree.SubElement(mask, f"{{{NS}}}rect", x="748", y="65", width="60", height="460", fill="url(#right)")
    etree.SubElement(root, f"{{{NS}}}image", x="0", y="0", width="1440", height="900", href=href(base))
    edge = etree.SubElement(root, f"{{{NS}}}image", x="0", y="65", width="808", height="835",
                            href=href("b01-structural-endcap-study.png"))
    edge.set("mask", "url(#endcaps)")
    svg = OUT / f"b01-endcap-r1-{name}.svg"
    png = OUT / f"b01-endcap-r1-{name}.png"
    svg.write_bytes(etree.tostring(root, xml_declaration=True, encoding="utf-8"))
    subprocess.run(["inkscape", str(svg), "--export-filename", str(png)], check=True,
                   env={**os.environ, "FONTCONFIG_FILE": "/tmp/space-idle-fontconfig.xml"})
    return png

if __name__ == "__main__":
    for key, file in SOURCES.items():
        print(render(key, file))
