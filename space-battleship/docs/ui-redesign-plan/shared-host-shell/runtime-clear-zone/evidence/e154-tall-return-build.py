"""Static 44/45 design: replace only e154 tall carrier and restore real public rail."""
from pathlib import Path
import base64
import os
import subprocess
from lxml import etree

HERE = Path(__file__).resolve().parent
PREFIX = "e15484ceabfe953605eef132e71b6883a3590bf5:space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/"
NS = "http://www.w3.org/2000/svg"


def data_url(path):
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode("ascii")


def build(name, source):
    root = etree.fromstring(subprocess.check_output(["git", "show", PREFIX + source]))
    count = 0
    for node in root.xpath('//*[local-name()="image"]'):
        if (node.get("x"), node.get("y"), node.get("width"), node.get("height")) == ("-27", "85", "843.2", "815"):
            node.set("href", data_url(HERE / "e154-tall-return-carrier-study.png"))
            # This art returns its right face earlier than the original asset;
            # an in-module wider projection keeps all original row controls clear.
            node.set("width", "880")
            count += 1
    assert count == 1, f"expected one tall carrier in {source}, got {count}"
    defs = root.find(f"{{{NS}}}defs")
    public = etree.SubElement(defs, f"{{{NS}}}clipPath", id="real-public")
    etree.SubElement(public, f"{{{NS}}}rect", x="808", y="0", width="632", height="900")
    screen = etree.SubElement(root, f"{{{NS}}}image", x="0", y="0", width="1440", height="900")
    screen.set("href", data_url(HERE / "e8-combo-equipment-1440x900.png"))
    screen.set("clip-path", "url(#real-public)")
    svg = HERE / f"e154-tall-return-{name}-source.svg"
    png = HERE / f"e154-tall-return-{name}-1440x900.png"
    svg.write_bytes(etree.tostring(root, xml_declaration=True, encoding="utf-8"))
    subprocess.run(["inkscape", str(svg), "--export-filename", str(png)], check=True,
                   env={**os.environ, "FONTCONFIG_FILE": "/tmp/space-idle-fontconfig.xml"})
    print(png)


if __name__ == "__main__":
    build("late-top", "44-coherent-late.svg")
    build("late-bottom", "45-coherent-bottom.svg")
