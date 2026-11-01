"""Architectural silhouette study for the orbital structure.

The drawing is deliberately separate from the runtime meshes. It fixes the
relative occupied spans, voids and major load paths before another GLB export.
"""
from base64 import b64encode
from math import cos, sin, radians
from pathlib import Path

HERE = Path(__file__).resolve().parent
TEXTURE = HERE.parents[1] / "assets/planets/painted-v4/surface.png"
OUT = HERE / "silhouette-v19.svg"
CX, CY, RX, RY = 800, 463, 377, 291


def p(deg, scale=1):
    a = radians(deg)
    return f"{CX + RX * scale * cos(a):.1f},{CY + RY * scale * sin(a):.1f}"


def band(a, b, inner, outer, color, stroke="#122838", width=4):
    # Explicitly sample both edges so tapered spans can later be reconstructed.
    steps = max(10, int(abs(b-a) / 2))
    points = [p(a + (b-a)*i/steps, outer) for i in range(steps+1)]
    points += [p(a + (b-a)*i/steps, inner) for i in range(steps, -1, -1)]
    return f'<polygon points="{" ".join(points)}" fill="{color}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round"/>'


parts = [f'''<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900" viewBox="0 0 1600 900">
<defs>
  <radialGradient id="space"><stop stop-color="#142d3d"/><stop offset="1" stop-color="#07131e"/></radialGradient>
  <linearGradient id="armor" x2=".7" y2="1"><stop stop-color="#eee0bc"/><stop offset=".5" stop-color="#a9b6b1"/><stop offset="1" stop-color="#547181"/></linearGradient>
  <linearGradient id="globe" x2=".7" y2="1"><stop stop-color="#b8d8d4" stop-opacity=".1"/><stop offset="1" stop-color="#051a2d" stop-opacity=".55"/></linearGradient>
  <clipPath id="planet"><circle cx="800" cy="463" r="222"/></clipPath>
</defs>
<rect width="1600" height="900" fill="url(#space)"/>
<text x="62" y="73" fill="#cdd6cd" font-family="sans-serif" font-size="25" letter-spacing="3">ORBITAL CRESCENT / V19 SILHOUETTE STUDY</text>
<text x="64" y="107" fill="#799bac" font-family="sans-serif" font-size="15">One inhabited upper arc · an industrial extension · an open dock branch · two breathing spans</text>
''']

# The rear structure has a long occupied crescent. The front is carried by
# short integrated industrial and dock sections with pronounced open space.
parts += [band(152, 205, .987, 1.013, "#263e4d", width=3),
          band(331, 394, .987, 1.013, "#263e4d", width=3),
          band(67, 109, .987, 1.013, "#263e4d", width=3)]
for a in (167, 187, 351, 373, 81, 95):
    parts.append(band(a-.8, a+.8, .95, 1.05, "#587785", width=1))

# Continuous rear inhabited pressure crescent. Command is the large central
# bay; the furnace is a smaller end chamber in the same load-bearing body.
parts += [band(205, 330, .90, 1.12, "#102936", width=7),
          band(207, 286, .93, 1.105, "url(#armor)", width=5),
          band(288, 329, .925, 1.10, "#82979a", width=5),
          band(211, 286, 1.015, 1.105, "#d7d2b6", width=2),
          band(292, 325, 1.012, 1.102, "#cdc19d", width=2)]
for a, b in ((215,232),(237,253),(259,283),(293,308),(312,326)):
    parts.append(band(a,b,.94,.985,"#294659",width=2))
for a in (235,257,285,310):
    parts.append(band(a-1.3,a+1.3,.89,1.14,"#233f4e",width=1))

planet = b64encode(TEXTURE.read_bytes()).decode("ascii")
parts.append(f'<image href="data:image/png;base64,{planet}" x="578" y="241" width="444" height="444" clip-path="url(#planet)" preserveAspectRatio="xMidYMid slice"/>')
parts.append('<circle cx="800" cy="463" r="222" fill="url(#globe)" stroke="#345a68" stroke-width="2"/>')

# The near industrial bay occupies a long but narrower tangent; the furnace
# vent is not repeated as a second oversized node.
parts += [band(12, 65, .925, 1.105, "#142f3d", width=6),
          band(16, 61, .945, 1.095, "url(#armor)", width=4),
          band(19, 59, 1.015, 1.095, "#d9d0b6", width=2),
          band(21, 57, .955,.987,"#1b3948",width=2),
          band(29, 49, .83, .92, "#172e3a", width=4),
          band(30, 48, .845, .90, "#748d94", width=2)]
for a in (24, 36, 48, 58):
    parts.append(band(a-.9,a+.9,.93,1.115,"#1a3a49",width=1))

# The dock grows from its short occupied ring root and branches into two
# outboard arms. Its center stays open; that negative shape is its identity.
parts += [band(109, 151, .93, 1.09, "#142f3d", width=6),
          band(111, 149, .965, 1.085, "#a8b7b1", width=4),
          band(113, 147, 1.025, 1.085, "#e3d8b6", width=2),
          band(119, 142, 1.09, 1.25, "#173544", width=5),
          band(120, 124, 1.13, 1.42, "#c2c5ad", width=4),
          band(138, 142, 1.13, 1.42, "#c2c5ad", width=4)]
parts += ['<path d="M 555,690 L 541,733 L 512,752 M 632,754 L 614,788 L 573,796" fill="none" stroke="#daf1dc" stroke-width="13" stroke-linecap="square"/>',
          '<path d="M 531,744 L 577,766 L 615,781" fill="none" stroke="#356474" stroke-width="5"/>']

# Distinctive command hub, attached to the occupied upper arc. Its mass is
# offset toward the inhabited arc, with a single heavy stem.
parts += ['<path d="M 630,202 L 668,151 L 771,158 L 814,208 L 773,243 L 657,239 Z" fill="#173240" stroke="#0b2230" stroke-width="8"/>',
          '<path d="M 654,200 L 682,162 L 764,168 L 790,204 L 762,222 L 669,220 Z" fill="#dcd8bf" stroke="#203b4a" stroke-width="5"/>',
          '<path d="M 691,178 L 749,181 L 771,202 L 676,203 Z" fill="#375c6d"/>',
          '<path d="M 695,201 L 753,204" stroke="#77bfc7" stroke-width="6"/>',
          '<path d="M 715,155 L 723,118 L 739,155" fill="#9eb7b2" stroke="#1b3949" stroke-width="4"/>']

# The refinery is an end-of-crescent hot process throat, visually joined to
# the upper structural run.
parts += ['<path d="M 1025,225 L 1077,243 L 1113,297 L 1081,316 L 1019,281 Z" fill="#1b3846" stroke="#0b2230" stroke-width="6"/>',
          '<path d="M 1039,233 L 1072,247 L 1095,286 L 1071,295 L 1032,267 Z" fill="#c7b99a" stroke="#294553" stroke-width="4"/>',
          '<path d="M 1053,249 L 1072,256 L 1083,278 L 1064,276 Z" fill="#d67b45"/>']

# Readable manufacturing mouth underneath the near arc, deliberately much
# subordinate to the inhabited crescent.
parts += ['<path d="M 1096,628 L 1148,649 L 1139,691 L 1079,683 L 1030,637 Z" fill="#112b38" stroke="#203e4a" stroke-width="6"/>',
          '<path d="M 1042,634 L 1094,638 L 1137,656 L 1128,669 L 1085,655 L 1040,650 Z" fill="#e0d9bb"/>',
          '<path d="M 1061,664 L 1111,678" stroke="#69adb7" stroke-width="6"/>']

parts += ['<text x="735" y="128" fill="#dbe7df" font-family="sans-serif" font-size="15">COMMAND / HABITAT CRESCENT</text>',
          '<text x="1136" y="282" fill="#dbc09c" font-family="sans-serif" font-size="15">HEAT THROAT</text>',
          '<text x="1160" y="682" fill="#dbe7df" font-family="sans-serif" font-size="15">FABRICATION BAY</text>',
          '<text x="356" y="798" fill="#dbe7df" font-family="sans-serif" font-size="15">OPEN DOCK BRANCH</text>',
          '<text x="64" y="852" fill="#7899a4" font-family="sans-serif" font-size="14">Occupied ring spans: upper 125°, manufacture 53°, dock 42°. Transit gaps vary 42°–63°.</text>',
          '</svg>']
OUT.write_text('\n'.join(parts))
print(OUT)
