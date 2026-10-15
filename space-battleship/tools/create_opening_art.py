"""Original vector art. Rebuild with Python + installed Inkscape; no downloaded art.
World s increases with journey; each PNG includes the next viewport's overlap.
"""
from pathlib import Path
import random, math, subprocess
ROOT=Path(__file__).resolve().parents[1]
BG=ROOT/'assets/backgrounds/opening'
PRO=ROOT/'assets/ships/opening-prototypes'
DOC=ROOT/'docs/art/opening-three'

def svg(w,h,body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'
def render(path, body, width=None):
    path.write_text(body)
    args=['inkscape',str(path),'--export-type=png','--export-filename='+str(path.with_suffix('.png'))]
    if width: args+=['--export-width='+str(width)]
    subprocess.run(args,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)

# One coordinate system; never reseed at tile edges.
rng=random.Random(20261015)
world=[]
for i in range(260):
    x=rng.uniform(-100,672); s=rng.uniform(-1200,7500)
    world.append(f'<circle cx="{x:.2f}" cy="{-s:.2f}" r="{rng.uniform(.35,1.1):.2f}" fill="#6c8191" opacity=".23"/>')
# A continuous broken orbital ribbon remains on the margins, leaving the kill lane quiet.
world.append('<path d="M -110 1100 C 190 0,-175 -500,40 -1600 S 180 -2600,-60 -3300 S 120 -4300,500 -5050 S 800 -5900,540 -7400" fill="none" stroke="#1b303d" stroke-width="112"/>')
world.append('<path d="M -110 1100 C 190 0,-175 -500,40 -1600 S 180 -2600,-60 -3300 S 120 -4300,500 -5050 S 800 -5900,540 -7400" fill="none" stroke="#33434b" stroke-opacity=".55" stroke-width="3" stroke-dasharray="54 35"/>')
for i in range(54):
    s=rng.uniform(-900,6400); x=rng.choice([rng.uniform(-45,90),rng.uniform(490,650)])
    color='#26343e' if s<2112 else '#3b3032' if s<4224 else '#293c41'
    size=rng.uniform(12,48)
    world.append(f'<g transform="translate({x:.2f},{-s:.2f}) rotate({rng.uniform(-80,80):.1f})"><path d="M {-size} -12 L 0 {-size} L {size} -8 L {size*.6} {size} L {-size*.7} 20 Z" fill="{color}"/><path d="M {-size} -12 L 0 {-size} L {size} -8" fill="none" stroke="#53606a" stroke-opacity=".35" stroke-width="2"/></g>')
# Each encounter gets a landmark composed from the same ribs, plates and ring segments.
for stage,count in [(1,5),(2,6),(3,7)]:
    for point in range(count):
        s=(stage-1)*2112+(point+0.6)/count*2112
        x=-90 if point%2==0 else 660
        r=135+point*11
        world.append(f'<g transform="translate({x},{-s:.1f}) rotate({point*17})"><circle r="{r}" fill="none" stroke="#31434b" stroke-width="19" opacity=".68" stroke-dasharray="140 37 72 55"/><circle r="{r-18}" fill="none" stroke="#586068" stroke-width="2" opacity=".32"/><path d="M {-r} 0 L {r} 0 M 0 {-r} L 0 {r}" stroke="#35464d" stroke-width="7" opacity=".55"/></g>')
world=''.join(world)
for stage in range(1,4):
    top=stage*2112
    defs='<defs><linearGradient id="base" x2="1" y2="0"><stop stop-color="#101e2a"/><stop offset=".35" stop-color="#091421"/><stop offset=".65" stop-color="#091421"/><stop offset="1" stop-color="#111f2b"/></linearGradient></defs>'
    body=defs+'<rect width="572" height="3072" fill="url(#base)"/>'+f'<g transform="translate(0,{top})">{world}</g>'
    render(BG/f'stage_{stage:02d}.svg',svg(572,3072,body))
# Silhouette studies are proposals, deliberately not bound to collision geometry.
shapes={
 'needle': 'M 443 170 L 525 480 L 545 940 L 682 1280 L 640 1500 L 490 1370 L 443 1540 L 397 1370 L 247 1500 L 205 1280 L 341 940 L 361 480 Z',
 'anvil': 'M 340 210 L 547 210 L 590 470 L 703 650 L 703 1300 L 585 1510 L 510 1400 L 377 1400 L 302 1510 L 184 1300 L 184 650 L 297 470 Z',
 'crown': 'M 394 210 L 493 210 L 540 640 L 620 390 L 706 580 L 660 1120 L 570 1350 L 500 1500 L 387 1500 L 317 1350 L 227 1120 L 181 580 L 267 390 L 347 640 Z'
}
for name,path in shapes.items():
    body='<defs><linearGradient id="h"><stop stop-color="#303943"/><stop offset=".46" stop-color="#899195"/><stop offset=".5" stop-color="#535e66"/><stop offset="1" stop-color="#232c34"/></linearGradient></defs>'
    body+=f'<defs><clipPath id="hull"><path d="{path}"/></clipPath></defs><path d="{path}" fill="url(#h)" stroke="#151e27" stroke-width="18"/><g clip-path="url(#hull)">'
    body+='<path d="M 411 380 L 475 380 L 506 1220 L 443 1380 L 380 1220 Z" fill="#502c34" stroke="#a45e53" stroke-width="8"/>'
    for side in [-1,1]:
        for y in [720,870,1020,1170]:
            x=443+side*125
            body+=f'<path d="M {x} {y} l {side*65} 30 l 0 42 l {-side*65} -30 Z" fill="#202a32" stroke="#778087" stroke-width="4"/>'
        body+=f'<rect x="{443+side*85-17}" y="1360" width="34" height="80" rx="9" fill="#bf8151"/>'
    render(PRO/f'{name}.svg',svg(887,1774,body+'</g>'))
# Review sheet: real assets at readable and small scales, explicitly concept-only.
from PIL import Image,ImageDraw,ImageFont
fontpath='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
f=ImageFont.truetype(fontpath,22); small=ImageFont.truetype(fontpath,16)
board=Image.new('RGB',(1440,1020),'#0b1420'); d=ImageDraw.Draw(board)
d.text((40,28),'BROKEN ORBIT / OPENING THREE — ORIGINAL ART STUDY',font=f,fill='#d9e3e4')
for i,name in enumerate(shapes):
    im=Image.open(PRO/f'{name}.png').convert('RGBA'); im.thumbnail((250,500))
    board.paste(im,(60+i*300,110),im)
    d.text((70+i*300,620),name.upper(),font=f,fill='#dcad81')
    im=Image.open(PRO/f'{name}.png').convert('RGBA'); im.thumbnail((45,90)); board.paste(im,(80+i*300,675),im)
    d.text((70+i*300,790),['forked / light hull','slab / heavy hull','open crown / shield'][i],font=small,fill='#98aab8')
d.text((40,920),'Silhouette proposals only. No combat stats, roster or hit geometry changed.',font=small,fill='#91a8b9')
for i in range(3):
    im=Image.open(BG/f'stage_{i+1:02d}.png').crop((0,900,572,1860)); im.thumbnail((144,480)); board.paste(im,(960+i*153,120))
d.text((965,650),'1 → 2 → 3 / quiet center lane',font=small,fill='#98aab8')
board.save(DOC/'first-review.png')
# Ten-part composition study uses one line, with future seven explicitly unproduced.
body='<rect width="2000" height="460" fill="#0b1420"/><path d="M 0 350 C 300 390 390 50 650 180 S 980 440 1170 210 S 1550 80 2000 270" fill="none" stroke="#2c434f" stroke-width="75"/><path d="M 0 350 C 300 390 390 50 650 180 S 980 440 1170 210 S 1550 80 2000 270" fill="none" stroke="#8a6d60" stroke-width="3" stroke-dasharray="12 15"/>'
names=['OUTER WAKE','RUST BELT','RING GATE','DARK RIBS','VEIL','FOUNDRY','SPLIT MOON','TIDAL ARC','INNER CROWN','HORIZON']
for i,name in enumerate(names):
    body+=f'<path d="M {i*200} 75 V 400" stroke="#273743"/><text x="{i*200+14}" y="35" fill="#d3dce0" font-size="18" font-family="sans-serif">{i+1:02d} {name}</text><text x="{i*200+14}" y="430" fill="#98aab8" font-size="13" font-family="sans-serif">'+('PRODUCED SEGMENT' if i<3 else 'CONTINUITY RESERVE')+'</text>'
body+='<text x="24" y="67" fill="#c59372" font-family="sans-serif" font-size="16">JOURNEY →  /  in battle: forward = up</text>'
render(DOC/'ten-stage-composition.svg',svg(2000,460,body))
print('Generated 3 overlapping scenery segments, 3 prototype hulls, 2 review sheets.')
