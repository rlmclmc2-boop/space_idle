"""Crop Blender pipe renders by the same contract used for Godot placement."""
import json
import os
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parent
BUILD=Path(os.environ.get("REACTOR_BUILD_DIR","/tmp/reactor-r6-build"))
contract=json.loads((ROOT/"reactor_ports.json").read_text())
canvas_size=tuple(contract["source_size"])
for name,spec in contract["devices"].items():
    end=spec["device_port"]
    for layer in ("shell","front","insert"):
        x,y,w,h=spec[f"pipe_{layer}_rect"]
        assert x<=end[0]<x+w and y<=end[1]<y+h,(name,layer,"endpoint outside crop")
        if layer == "shell":
            inserted=[end[i]+spec["axis_to_device"][i]*spec["insert_depth"] for i in range(2)]
            assert x<=inserted[0]<x+w and y<=inserted[1]<y+h,(name,"inserted section outside crop")
        source=Image.open(BUILD/f"modular-pipe-{name}-{layer}-full.png").convert("RGBA")
        assert source.size==canvas_size
        cropped=source.crop((x,y,x+w,y+h))
        assert cropped.getbbox() is not None
        ex,ey=round(end[0]-x),round(end[1]-y)
        vicinity=cropped.getchannel("A").crop((max(0,ex-8),max(0,ey-8),min(w,ex+9),min(h,ey+9)))
        assert vicinity.getbbox() is not None,(name,layer,"no visible endpoint")
        cropped.save(ROOT/f"modular-pipe-{name}-{layer}.png")
        print(name,layer,"alpha",cropped.getbbox(),"endpoint",(ex,ey))
