"""Render three public-shell concepts; module and battle interiors are illustrative."""
from pathlib import Path
import math
import random
import html

ROOT = Path(__file__).parent
W, H = 1440, 900
FONT = 'Noto Sans CJK SC, Noto Sans SC, sans-serif'


def rect(x, y, w, h, fill, rx=0, stroke='none', sw=1, opacity=1):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" opacity="{opacity}"/>'


def line(x1, y1, x2, y2, color, sw=1, opacity=1):
    return f'<path d="M{x1},{y1} L{x2},{y2}" fill="none" stroke="{color}" stroke-width="{sw}" opacity="{opacity}"/>'


def txt(x, y, content, size=16, fill='#e7eee8', weight=400, anchor='start', spacing=0):
    return f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" letter-spacing="{spacing}" fill="{fill}" text-anchor="{anchor}">{html.escape(content)}</text>'


def defs():
    return '''<defs>
    <linearGradient id="space" x1="0" x2="1" y1="0" y2="1"><stop stop-color="#091929"/><stop offset=".52" stop-color="#183854"/><stop offset="1" stop-color="#071624"/></linearGradient>
    <linearGradient id="bay" x1="0" x2="0" y1="0" y2="1"><stop stop-color="#203a49"/><stop offset=".42" stop-color="#375363"/><stop offset="1" stop-color="#102638"/></linearGradient>
    <linearGradient id="armour" x1="0" x2="1" y1="0" y2="1"><stop stop-color="#fff8dc"/><stop offset=".42" stop-color="#d9d5bb"/><stop offset="1" stop-color="#8fa3a1"/></linearGradient>
    <linearGradient id="core" x1="0" x2="1" y1="0" y2="1"><stop stop-color="#d5ffff"/><stop offset=".42" stop-color="#45d6e2"/><stop offset="1" stop-color="#08657f"/></linearGradient>
    <linearGradient id="ink" x1="0" x2="0" y1="0" y2="1"><stop stop-color="#284a59"/><stop offset="1" stop-color="#102b3b"/></linearGradient>
    <linearGradient id="warm" x1="0" x2="0" y1="0" y2="1"><stop stop-color="#f6f0d9"/><stop offset="1" stop-color="#b8bba9"/></linearGradient>
    <linearGradient id="rail" x1="0" x2="1" y1="0" y2="0"><stop stop-color="#203f50"/><stop offset=".5" stop-color="#3d6874"/><stop offset="1" stop-color="#172f42"/></linearGradient>
    <radialGradient id="haze"><stop stop-color="#337ca0" stop-opacity=".32"/><stop offset="1" stop-color="#337ca0" stop-opacity="0"/></radialGradient>
    <pattern id="grid" width="44" height="44" patternUnits="userSpaceOnUse"><path d="M44 0H0V44" fill="none" stroke="#a6d1ce" stroke-opacity=".055"/></pattern>
    </defs>'''


def stars(x, y, w, h, seed):
    rng = random.Random(seed)
    out = [rect(x,y,w,h,'url(#space)'), rect(x,y,w,h,'url(#grid)')]
    out.append(f'<ellipse cx="{x+w*.55}" cy="{y+h*.46}" rx="{w*.55}" ry="{h*.52}" fill="url(#haze)"/>')
    for _ in range(90):
        px, py = x+rng.random()*w, y+rng.random()*h
        radius = .4+rng.random()*1.2
        out.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{radius:.1f}" fill="#d7e9ef" opacity="{.16+rng.random()*.55:.2f}"/>')
    return ''.join(out)


def craft(cx, cy, scale=1):
    return f'''<g transform="translate({cx} {cy}) scale({scale})">
    <path d="M0 -102 L24 -40 L42 24 L69 82 L43 78 L20 40 L18 97 L0 112 L-18 97 L-20 40 L-43 78 L-69 82 L-42 24 L-24 -40Z" fill="url(#armour)" stroke="#17394c" stroke-width="5"/>
    <path d="M0 -82 L15 -29 L21 33 L0 75 L-21 33 L-15 -29Z" fill="#143d53" stroke="#85b0ad" stroke-width="3"/>
    <path d="M0 -55 L10 -14 L0 8 L-10 -14Z" fill="url(#core)"/><path d="M-34 78 L-22 49 L-12 90Z M34 78 L22 49 L12 90Z" fill="#46c9dc"/>
    <circle cy="30" r="6" fill="#ffe2a3"/>
    </g>'''


def battle(x, y, w, h, seed=24, show_hud=True):
    out = [stars(x,y,w,h,seed)]
    # A quiet docking structure frames the battle without substituting for it.
    out += [f'<path d="M{x},{y+h*.59} L{x+58},{y+h*.68} L{x+72},{y+h} L{x},{y+h}Z" fill="#29495a" stroke="#6c8d90" stroke-width="2" opacity=".7"/>',
            f'<path d="M{x+w},{y+h*.59} L{x+w-58},{y+h*.68} L{x+w-72},{y+h} L{x+w},{y+h}Z" fill="#29495a" stroke="#6c8d90" stroke-width="2" opacity=".7"/>',
            line(x+10,y+h*.64,x+84,y+h*.74,'#b8ad88',2,.5),line(x+w-10,y+h*.64,x+w-84,y+h*.74,'#b8ad88',2,.5),
            craft(x+w*.54,y+h*.51,.68)]
    if show_hud:
        out += [rect(x+w-340,y+h-188,314,103,'#102c3b',8,'#6d9a9a',1.2,.9),
                txt(x+w-318,y+h-158,'舰船防御',15,'#e8e9d5',600),
                txt(x+w-318,y+h-133,'装甲  1,630 / 1,630',14,'#b8d8d7'),
                rect(x+w-318,y+h-119,269,7,'#284e60',3),rect(x+w-318,y+h-119,244,7,'#dbb87d',3),
                txt(x+w-318,y+h-88,'护盾  0 / 0',13,'#b8d8d7')]
    return ''.join(out)


def module(x, y, w, h, title='装备工作舱', show_title=True):
    out = [rect(x,y,w,h,'url(#bay)'),rect(x,y,w,h,'url(#grid)'),
           f'<ellipse cx="{x+w*.52}" cy="{y+h*.62}" rx="{w*.33}" ry="{h*.13}" fill="#0a2030" opacity=".65"/>',
           f'<ellipse cx="{x+w*.52}" cy="{y+h*.62}" rx="{w*.27}" ry="{h*.1}" fill="none" stroke="#d4bd91" stroke-width="9" opacity=".8"/>',
           f'<path d="M{x+32},{y+42} L{x+w*.37},{y+20} M{x+w-32},{y+42} L{x+w*.63},{y+20}" stroke="#d9d8c4" stroke-width="10" opacity=".5"/>',
           f'<path d="M{x+42},{y+h*.2} V{y+h*.7} M{x+w-42},{y+h*.2} V{y+h*.7}" stroke="#d6d2bd" stroke-width="12" opacity=".33"/>',
           craft(x+w*.52,y+h*.49,.58),
           rect(x+16,y+h-226,w-32,211,'url(#warm)',12,'#8eaaa7',2),
           rect(x+34,y+h-204,w*.46,42,'#24485a',6),txt(x+50,y+h-176,'武器 1 · 脉冲炮',17,'#f1efdf',600),
           txt(x+44,y+h-124,'当前攻击力',13,'#536e6b'),txt(x+44,y+h-83,'396',27,'#224b5c',650),
           txt(x+w*.33,y+h-87,'→',24,'#8c9e93'),txt(x+w*.40,y+h-83,'476',27,'#1b6470',650),
           rect(x+34,y+h-62,w*.55,36,'#235466',6),txt(x+34+w*.275,y+h-38,'购买 1 级',15,'#f4efda',600,'middle'),
           txt(x+w-36,y+h-25,'内部示意',11,'#637d79',400,'end')]
    if show_title:
        out += [rect(x+22,y+24,222,38,'#173b4b',7,'#7aa4a3',1,.86),txt(x+37,y+49,title,16,'#f1efdb',600)]
    return ''.join(out)


def button(x,y,w,h,label,active=False,light=False):
    bg = '#e9e6d3' if active and not light else '#266370' if active else '#173a4c' if not light else '#eee8d4'
    fg = '#193e4d' if active and not light or light else '#d4e6df'
    edge = '#f5e9bf' if active else '#537986' if not light else '#abb9aa'
    return rect(x,y,w,h,bg,7,edge,1.2)+txt(x+w/2,y+h/2+5,label,14,fg,600 if active else 450,'middle')


def concept_a():
    out=[defs(),module(0,65,808,835),battle(808,0,632,900,20)]
    # The battle wings use the same continuous environment field; they are no longer blank.
    out += [rect(0,0,808,65,'#173744'),rect(0,0,808,29,'#294c59'),line(0,29,808,29,'#7b9b9a',1,.48),
            line(0,64,808,64,'#e0d3aa',2),
            rect(11,5,99,20,'#e8e3cb',5),txt(60,20,'装备工作舱',12,'#234657',600,'middle'),
            txt(132,20,'铁',12,'#aac4bd'),txt(157,20,'26.4万',14,'#f1e8cd',600),
            txt(265,20,'铀',12,'#aac4bd'),txt(288,20,'1.8万',14,'#f1e8cd',600),
            txt(391,20,'时空微粒',12,'#aac4bd'),txt(477,20,'3,420',14,'#f1e8cd',600),
            line(249,7,249,25,'#7b9b9a',1,.45),line(371,7,371,25,'#7b9b9a',1,.45),
            button(655,4,44,23,'●',False),button(708,4,89,23,'资源',False)]
    names=['装备','反应炉','科研','强化','船员','星球','星系','超空间','更多']
    widths=[76,88,76,76,76,76,76,92,76]
    cx=12
    for i,(n,w) in enumerate(zip(names,widths)):
        out.append(button(cx,33,w,27,n,i==0));cx+=w+4
    # A thin continuity joint is structural, not a cover laid over either module.
    out += [rect(804,0,4,900,'#36596a'),line(806,65,806,900,'#d9cca6',1,.6),
            txt(832,29,'关卡 1  ·  航行',14,'#dfebdf',550),button(1296,12,87,29,'暂停')]
    return ''.join(out)


def concept_b():
    out=[defs(),module(0,84,820,816),battle(820,84,620,816,32)]
    out += [rect(0,0,1440,84,'#e9e7d7'),rect(0,0,1440,8,'#234858'),rect(0,47,1440,37,'#173e4d'),
            line(0,83,1440,83,'#c9b485',2),
            rect(18,14,173,29,'#244d5b',8),txt(104,35,'舰桥  /  航行甲板',16,'#f3edd8',650,'middle'),
            txt(223,35,'铁   26.4万',15,'#234a57',600),txt(382,35,'铀   1.8万',15,'#234a57',600),
            txt(534,35,'时空微粒   3,420',15,'#234a57',600),
            rect(1070,12,175,30,'#d9e2d5',7,'#aebeb3',1),txt(1157,33,'关卡 1  ·  航行',14,'#234a57',550,'middle'),
            button(1261,11,81,31,'资源',False,True),button(1351,11,72,31,'暂停',False,True)]
    names=['装备','反应炉','科研','强化','船员','星球','星系','超空间','更多']
    cx=18
    for i,n in enumerate(names):
        w=83 if n in ['反应炉','超空间'] else 72
        out.append(button(cx,52,w,27,n,i==0));cx+=w+6
    out += [line(819,84,819,900,'#e4d4a9',2,.8),rect(813,84,6,816,'url(#rail)',0,opacity=.9),
            txt(1430,71,'统一任务状态 / 全局行动',12,'#bcd6d0',400,'end')]
    return ''.join(out)


def concept_c():
    out=[defs(),module(90,0,718,900,show_title=False),battle(808,0,632,900,46)]
    out += [rect(0,0,90,900,'#142f40'),rect(0,0,90,900,'url(#grid)'),
            rect(86,0,4,900,'#d1bd96'),
            rect(112,13,574,42,'#203f4f',12,'#699290',1.2,.96),
            txt(132,41,'装备',17,'#f2ecd9',650),
            txt(234,41,'铁 26.4万',14,'#e2ead9'),txt(378,41,'铀 1.8万',14,'#e2ead9'),
            txt(510,41,'微粒 3,420',14,'#e2ead9'),
            button(700,12,85,40,'资源'),
            txt(45,32,'舰桥',14,'#e9e5d2',650,'middle')]
    names=['装','炉','研','强','员','星','系','跃','···']
    ys=[74,154,234,314,394,474,554,634,714]
    for i,(n,y) in enumerate(zip(names,ys)):
        out.append(rect(11,y,68,61,'#e7e2cd' if i==0 else '#23495a',12,'#d5bf92' if i==0 else '#527a82',1.3))
        out.append(txt(45,y+39,n,23,'#194555' if i==0 else '#d5e7df',600,'middle'))
    out += [line(808,0,808,900,'#c9b991',2,.9),
            rect(824,14,265,38,'#183747',10,'#618c91',1,.9),txt(844,39,'关卡 1  ·  航行',14,'#e8e8d4',600),
            button(1320,13,94,39,'暂停')]
    return ''.join(out)


for name, content in [('a-continuous-bridge',concept_a()),('b-full-width-deck',concept_b()),('c-command-spine',concept_c())]:
    (ROOT / (name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'+content+'</svg>')
