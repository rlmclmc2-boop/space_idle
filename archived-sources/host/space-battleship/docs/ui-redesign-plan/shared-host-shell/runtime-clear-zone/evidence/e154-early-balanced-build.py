"""Design-only e154 early carrier replacement with exact source nodes/public geometry."""
from pathlib import Path
import base64
import os
import subprocess
from lxml import etree

HERE = Path(__file__).resolve().parent
SOURCE = "e15484ceabfe953605eef132e71b6883a3590bf5:space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/42-coherent-early.svg"
NS = "http://www.w3.org/2000/svg"


def data_url(path):
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode("ascii")


root = etree.fromstring(subprocess.check_output(["git", "show", SOURCE]))
replaced = 0
for node in root.xpath('//*[local-name()="image"]'):
    if (node.get("x"), node.get("y"), node.get("width"), node.get("height")) == ("-27", "85", "843.2", "815"):
        node.set("href", data_url(HERE / "e154-early-balanced-carrier-study.png"))
        node.set("y", "50")
        node.set("height", "850")
        replaced += 1
assert replaced == 1, f"expected one original e154 carrier, got {replaced}"

defs = root.find(f"{{{NS}}}defs")
public = etree.SubElement(defs, f"{{{NS}}}clipPath", id="real-public")
etree.SubElement(public, f"{{{NS}}}rect", x="808", y="0", width="632", height="900")
real_screen = etree.SubElement(root, f"{{{NS}}}image", x="0", y="0", width="1440", height="900")
real_screen.set("href", data_url(HERE / "e8-combo-equipment-1440x900.png"))
real_screen.set("clip-path", "url(#real-public)")

svg = HERE / "e154-early-balanced-source.svg"
png = HERE / "e154-early-balanced-exact-1440x900.png"
svg.write_bytes(etree.tostring(root, xml_declaration=True, encoding="utf-8"))
subprocess.run(["inkscape", str(svg), "--export-filename", str(png)], check=True,
               env={**os.environ, "FONTCONFIG_FILE": "/tmp/space-idle-fontconfig.xml"})
print(png)
