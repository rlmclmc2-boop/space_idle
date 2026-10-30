#!/usr/bin/env python3
"""Static design plates only. No game imports, runtime, state or rules execution."""
import base64
import hashlib
import html
import json
import re
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[4]
ASSETS = PROJECT / 'assets'
CONTEXT = HERE.parent / 'upgrade-group-coherence/00-fresh-current.png'
INK = '#243d50'
TEAL = '#326272'
MUTED = '#657d82'
WARN = '#aa592c'
used = {}


def ref(path):
    path = Path(path)
    data = path.read_bytes()
    used[str(path.relative_to(PROJECT))] = hashlib.sha256(data).hexdigest()
    mime = 'image/svg+xml' if path.suffix == '.svg' else 'image/png'
    return 'data:' + mime + ';base64,' + base64.b64encode(data).decode()


def text(x, y, value, size=14, color=INK, weight=400, anchor='start'):
    return f'<text x="{x}" y="{y}" font-size="{size}" fill="{color}" font-weight="{weight}" text-anchor="{anchor}">{html.escape(str(value))}</text>'


def box(x, y, w, h, fill, stroke='none', r=5):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}"/>'


def image(path, x, y, w, h, bounds=None):
    path = Path(path)
    if bounds is None:
        if path.suffix == '.svg':
            bounds = (0, 0, 128, 128)
        else:
            with Image.open(path) as im:
                b = im.getbbox()
                bounds = (b[0], b[1], b[2]-b[0], b[3]-b[1])
    a, b, c, d = bounds
    clip = 'crop' + hashlib.sha256(f'{path}:{bounds}:{x}:{y}'.encode()).hexdigest()[:12]
    return f'<svg x="{x}" y="{y}" width="{w}" height="{h}" viewBox="{a} {b} {c} {d}" overflow="hidden" preserveAspectRatio="xMidYMid meet"><defs><clipPath id="{clip}"><rect x="{a}" y="{b}" width="{c}" height="{d}"/></clipPath></defs><g clip-path="url(#{clip})"><image href="{ref(path)}" width="{Image.open(path).width if path.suffix != ".svg" else 128}" height="{Image.open(path).height if path.suffix != ".svg" else 128}"/></g></svg>'


def resource(kind, x, y, size=16):
    cells = {'iron': ('resource-material-atlas.png', (62,129,602,475)),
             'matter': ('resource-material-supplement.png', (983,117,723,669))}
    filename, bounds = cells[kind]
    return image(ASSETS/'ui/public_shell'/filename, x, y, size, size, bounds)


EQUIPMENT = {
    'laser': ('脉冲炮', ASSETS/'weapons/fleet_20261019/laser.png', '350', '420', '1.5秒'),
    'missile': ('导弹', ASSETS/'weapons/fleet_20261019/missile.png', '170', '200', '2.4秒'),
    'cannon': ('舰炮', ASSETS/'weapons/fleet_20261019/cannon.png', '1,200', '1,400', '3.5秒'),
    'longLaser': ('长激光', ASSETS/'weapons/fleet_20261019/longLaser.png', '35', '45', '0.25秒'),
    'armour': ('装甲', ASSETS/'ui/equipment/cartoon_armour.svg', '1,000', '1,200', ''),
    'shield': ('护盾', ASSETS/'ui/equipment/cartoon_shield.svg', '750', '900', ''),
}


def button(x, y, width, caption, disabled=False):
    return box(x,y,width,30,'url(#disabled)' if disabled else 'url(#button)', '#92a4a4') + text(x+width/2,y+20,caption,14,'#eaf0e8' if not disabled else '#f0f0e8',500,'middle')


def row(y, category, index, key, state='normal', focus=False):
    name, path, current, after, interval = EQUIPMENT[key]
    level, mode, purchase, costs, reason = '1', '×1', '购买1级', [('iron','铁65')], ''
    disabled = False
    if state == 'poor': disabled, reason = True, '铁不足'
    if state == 'evolution':
        level,current,after,costs = '19','9,300','1.76万',[('iron','铁1,600'),('matter','简并物质10')]
    if state == 'ten':
        level,current,after,mode,purchase,costs = '29','9.28万','57.6万','×10','购买10级',[('iron','铁25.79万')]
        disabled,reason = True,'铁不足'
    if state == 'maxzero':
        level,current,after,mode,purchase,costs = '33','19.2万','—','MAX','可购0级',[]
        disabled,reason = True,'当前预算不可购'
    s = box(316,y,474,79,'#e8e8dc' if not focus else '#e0ebe3','#a3b2ae',4)
    if focus: s += box(316,y,4,79,'#397e82',r=0)
    s += image(path,323,y+12,33,42)
    s += text(365,y+21,('武器' if category=='weapon' else '防御')+str(index+1),13,MUTED)
    s += box(410,y+5,151,25,'#d6ded6','#a2b2aa',3)
    s += text(418,y+23,name,15,INK,500)+text(551,y+22,'⌄',17,TEAL,500,'middle')
    s += text(570,y+22,'Lv.'+level,13,MUTED)
    s += text(775,y+22,'ⓘ',14,MUTED,400,'end')
    s += text(365,y+43,'攻击力' if category=='weapon' else '容量',11,MUTED)
    s += text(415,y+44,current,16,INK,600)+text(484,y+44,'→',16,MUTED)+text(507,y+44,after,16,TEAL,600)
    s += text(365,y+65,'升级费',11,MUTED)
    cursor = 406
    for kind, value in costs:
        s += resource(kind,cursor,y+52,16)+text(cursor+19,y+65,value,12,INK)
        cursor += 102 if len(value)>5 else 72
    if not costs: s += text(407,y+65,'—',12,MUTED)
    s += button(605,y+36,54,mode)+button(667,y+36,114,purchase,disabled)
    if reason: s += text(778,y+75,reason,10,WARN,400,'end')
    return s


def plate(stage, popup=False):
    hull, title, height = {'early':('01-frigate','游隼侦察艇',150),
                           'middle':('03-cruiser','云鳐巡洋舰',260),
                           'late':('05-heavy-battleship','白鲸无畏舰',305)}[stage]
    weapons = {'early':['laser'],'middle':['laser','missile','laser'],
               'late':['laser','missile','cannon','longLaser','laser']}[stage]
    defence = ['armour'] if stage == 'early' else ['armour','shield'] if stage == 'middle' else ['armour','shield','shield']
    console_bottom = 148 + 2*(24+4) + 81*(len(weapons)+len(defence)) + 35
    s = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1440" height="900" viewBox="0 0 1440 900"><defs>'
    s += '<linearGradient id="face" x2="0" y2="1"><stop stop-color="#f1efdf"/><stop offset="1" stop-color="#d4d9d1"/></linearGradient><linearGradient id="button" x2="0" y2="1"><stop stop-color="#507786"/><stop offset="1" stop-color="#294957"/></linearGradient><linearGradient id="disabled" x2="0" y2="1"><stop stop-color="#9eaba9"/><stop offset="1" stop-color="#83928f"/></linearGradient>'
    s += '<clipPath id="header"><rect width="808" height="85"/></clipPath><clipPath id="battle"><rect x="808" width="632" height="900"/></clipPath><clipPath id="module"><rect y="85" width="808" height="815"/></clipPath><clipPath id="stage"><rect y="85" width="302" height="815"/></clipPath></defs><g font-family="Noto Sans CJK SC, sans-serif">'
    # Unchanged screenshot regions are context, not a new battle/nav proposal.
    for clip in ['header','battle']:
        s += f'<image href="{ref(CONTEXT)}" width="1440" height="900" clip-path="url(#{clip})"/>'
    s += '<g clip-path="url(#module)">'+box(0,85,808,815,'#324a57',r=0)
    s += f'<svg x="0" y="85" width="808" height="815" viewBox="0 0 1188 845" preserveAspectRatio="xMidYMid slice"><image href="{ref(ASSETS / "ui/equipment/hangar/hangar-console.png")}" width="1188" height="1324"/></svg>'
    s += box(16,104,269,72,'#274957', '#587882')+text(30,132,title,21,'#f2eedb',600)+text(30,157,f'武器 {len(weapons)}  ·  防御 {len(defence)}',14,'#c9ded9')
    s += image(ASSETS/f'ui/ships/fleet_20261019/{hull}.png',22,680-height,258,height)
    s += box(24,742,254,50,'#2e5059','#67878a')+text(39,763,'当前舰体',12,'#c4d8d4')+text(39,784,title,16,'#eeeeda',500)
    s += text(20,853,'结构候选 · 静态设计稿',13,'#f0e9d3',500)
    s += text(20,876,'舰船保留；操作在相邻逐槽工作台',11,'#d1ddd4')
    s += box(303,95,495,console_bottom-95,'#34525e','#8faaa9',9)+box(310,102,481,console_bottom-109,'url(#face)','#a3b3ab',7)
    s += text(326,128,'当前装备',21,INK,600)+text(442,126,'逐槽工作台',12,MUTED)
    s += button(683,108,96,'全部升级')
    y=148
    for cat, keys in [('weapon',weapons),('defence',defence)]:
        s += box(316,y,474,22,'#355c68',r=3)+text(327,y+16,('武器' if cat=='weapon' else '防御')+' · '+str(len(keys)),13,'#eef0df',500)
        y += 24
        for i,key in enumerate(keys):
            state='poor' if stage=='early' else 'normal'
            if stage=='middle' and cat=='weapon' and i==0: state='ten'
            if stage=='middle' and cat=='weapon' and i==2: state='maxzero'
            if stage=='late' and cat=='weapon' and i==0: state='evolution'
            s += row(y,cat,i,key,state,focus=(cat=='defence' and i==1 and popup))
            y += 81
        y += 4
    s += text(326,console_bottom-16,'槽名称／图标：就地候选入口',11,MUTED)
    if popup:
        # Anchored upward because defence2 is near the lower edge. Underlying rows do not move.
        py=514
        s += box(407,py,370,167,'#244450','#10303f',7)
        s += text(421,py+24,'防御2 · 同槽Lv.1',15,'#f4f0df',500)+text(760,py+24,'×',18,'#dce8df',400,'end')
        for k,yy,current in [('shield',py+35,True),('armour',py+94,False)]:
            name,path,value,_,_=EQUIPMENT[k]
            s += box(415,yy,354,54,'#e0e8de' if current else '#f1efdf','#aac1b8')
            s += image(path,424,yy+7,34,39)+text(469,yy+23,name,16,INK,500)
            s += text(469,yy+43,'容量 '+value,13,MUTED)
            s += text(752,yy+23,'✓ 现装' if current else '点选切换',13,TEAL,500,'end')
            s += text(752,yy+43,'比较 ⓘ',12,MUTED,400,'end')
    s += '</g></g></svg>'
    # Preserve embedded originals once per SVG, rather than repeating atlas bytes per row.
    embedded = {}
    definitions = []
    def deduplicate(match):
        url, w, h, extra = match.groups()
        key = (url, w, h)
        if key not in embedded:
            identity = 'asset' + str(len(embedded))
            embedded[key] = identity
            definitions.append(f'<image id="{identity}" href="{url}" width="{w}" height="{h}"/>')
        return f'<use href="#{embedded[key]}"{extra}/>'
    s = re.sub(r'<image href="(data:[^"]+)" width="(\d+)" height="(\d+)"([^>]*)/>',deduplicate,s)
    return s.replace('</defs>', ''.join(definitions)+'</defs>',1)


for name,stage,popup in [('01-early-two','early',False),('02-middle-five','middle',False),('03-late-eight','late',False),('04-local-dropdown','late',True)]:
    (HERE/(name+'.svg')).write_text(plate(stage,popup),encoding='utf-8')
(HERE/'reference-hashes.json').write_text(json.dumps(used,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
