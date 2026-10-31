"""Align independent Blender renders to exact contract ports and crop them.

Run after generate_reactor_devices.py. The emitted device and work images use
the same source-space origin; no visual guess or plate mask sets an interface.
"""
import json
import os
from pathlib import Path

from PIL import Image


ROOT=Path(__file__).resolve().parent
BUILD=Path(os.environ.get("REACTOR_BUILD_DIR", "/tmp/reactor-r6-build"))
OUTPUT=Path(os.environ.get("REACTOR_OUTPUT_DIR", str(ROOT)))
OUTPUT.mkdir(parents=True,exist_ok=True)
contract=json.loads((ROOT/"reactor_ports.json").read_text())
w,h=contract["source_size"]

only=os.environ.get("REACTOR_ONLY")
for name,spec in contract["devices"].items():
    if only and name!=only:continue
    projection=json.loads((BUILD/f"r6-{name}-projection.json").read_text())
    px,py=projection["port_screen"]
    target=spec["device_port"]
    dx,dy=round(target[0]-px),round(target[1]-py)
    assert max(abs(target[0]-(px+dx)),abs(target[1]-(py+dy)))<=.5
    x,y,rw,rh=spec["rect"]
    wx,wy,ww,wh=spec["work_rect"]
    assert x<=target[0]<x+rw and y<=target[1]<y+rh
    assert x<=wx and y<=wy and wx+ww<=x+rw and wy+wh<=y+rh
    for suffix,rect in (("",(x,y,rw,rh)),("-work",(wx,wy,ww,wh))):
        source=BUILD/f"r6-{name}{suffix}-full.png"
        original=Image.open(source).convert("RGBA")
        assert original.size==(w,h)
        aligned=Image.new("RGBA",(w,h))
        aligned.alpha_composite(original,(dx,dy))
        cx,cy,cw,ch=rect
        crop=aligned.crop((cx,cy,cx+cw,cy+ch))
        assert crop.getbbox() is not None,(name,suffix)
        crop.save(OUTPUT/f"r6-{name}{suffix}.png")
        print(name,suffix or "base","alignment",(dx,dy),"crop",rect,"alpha",crop.getbbox())
