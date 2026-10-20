"""Static design board: browser image elements only; no game integration or pixel painting."""
from pathlib import Path
import json,re,html
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
meta=json.loads((HERE/'design-meta.json').read_text())
manifest=json.loads((ROOT/'assets/ships/enemy/elite_boss_20261020/manifest.json').read_text())
previous=json.loads((ROOT/'evidence/cannon-redesign-20261020/revision2/ranked.json').read_text())
snapshots={x['case']:x for x in previous['snapshots']}
names={'anchor':'锚定','reactive':'反应','shielded':'护盾','command':'指挥'}
W,H=Image.open(HERE/'cannon-design.png').size

def assembly(case,yaw=0,zoom=1):
    item=manifest['sprites'][case];snap=snapshots[case]
    src=ROOT/item['texture'].removeprefix('res://');im=Image.open(src);box=im.getbbox()
    # The previous main.tscn screenshot's presentation transform is approximately 0.7 CSS px/logical px.
    body=[float(v) for v in re.findall(r'[-\d.]+',snap['body'])][-2:]
    scale=body[0]*meta['screen_scale']/(box[2]-box[0])*zoom
    cx=(box[0]+box[2])/2;cy=(box[1]+box[3])/2
    parts=[f'<div class="ship" style="transform:rotate(180deg)"><img class="hull" src="../../../{item["texture"].removeprefix("res://")}" style="width:{im.width*scale}px;height:{im.height*scale}px;left:{-cx*scale}px;top:{-cy*scale}px">']
    smallest=min(s['socket_well_width_uv'] for s in item['sockets'])
    housing=smallest*im.width*scale*meta['housing_to_well_ratio']
    gs=housing/meta['housing_width_source_px']
    for s in item['sockets']:
        x,y=s['socket_centre_px'];px,py=meta['pivot_source_px']
        parts.append(f'<div class="mount" style="left:{(x-cx)*scale}px;top:{(y-cy)*scale}px;transform:rotate({yaw}deg)"><img class="gun" src="cannon-design.png" style="left:{-px*gs}px;top:{-py*gs}px;width:{W*gs}px;height:{H*gs}px"></div>')
    parts.append('</div>')
    return ''.join(parts),housing
cards=[];measure=[]
for rank in ['elite','boss']:
    for key in names:
        case=key+'_'+rank;body,width=assembly(case);label=names[key]+(' · 精英' if rank=='elite' else ' · BOSS')
        cards.append(f'<div class="card"><div class="native">{body}</div><h3>{label}</h3><p>{2 if rank=="elite" else 4} 炮 · 炮壳约 {width:.1f}px</p></div>')
        measure.append({'case':case,'housing_screen_pixels':width})
turns=[]
for yaw in [-35,0,35]:
    body,_=assembly('command_boss',yaw)
    turns.append(f'<div class="turn"><div class="native">{body}</div><h3>{yaw:+}°</h3></div>')
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><title>炮身设计提案 03</title><style>
*{box-sizing:border-box}body{margin:0;background:#0c1823;color:#e3ebf1;font:14px "Noto Sans CJK SC",sans-serif}.board{width:1240px;padding:32px;margin:0 auto}header{border-bottom:1px solid #34424e;padding-bottom:16px;margin-bottom:24px}h1{font-size:27px;font-weight:600;letter-spacing:2px;margin:0 0 8px}.eyebrow{font-size:12px;letter-spacing:2px;color:#e9b078;margin-bottom:8px}p{color:#a8bac8;line-height:1.7;margin:4px 0}h2{font-size:17px;font-weight:500;margin:0 0 14px}h3{font-size:13px;margin:0;font-weight:500}.main{display:grid;grid-template-columns:292px 1fr;gap:24px}.detail{border:1px solid #34424e;background:#132331;padding:20px;display:flex;flex-direction:column;align-items:center}.detail img{height:345px;width:240px;object-fit:contain}.detail h2{align-self:flex-start}.detail p{font-size:12px;margin-top:18px}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}.card{border:1px solid #2a3e4d;background:#132331;text-align:center;height:205px}.card p{font-size:11px;margin:3px 0}.native{position:relative;height:162px;width:100%}.ship{position:absolute;left:50%;top:50%;width:0;height:0}.hull,.gun{position:absolute;max-width:none}.mount{position:absolute;width:0;height:0;transform-origin:0 0}.sub{font-size:11px;letter-spacing:1px;color:#a8bac8;margin-bottom:12px}.bottom{display:grid;grid-template-columns:292px 1fr;gap:24px;margin-top:20px}.reference{border-top:1px solid #34424e;padding-top:14px}.reference img{width:270px;height:180px;object-fit:contain}.reference p{font-size:11px}.turnpanel{border-top:1px solid #34424e;padding-top:14px}.turns{display:grid;grid-template-columns:repeat(3,1fr);gap:20px}.turn{text-align:center;background:#132331;border:1px solid #2a3e4d}.turn .native{height:155px}.turn h3{padding-bottom:10px}.foot{border-top:1px solid #34424e;margin-top:22px;padding-top:12px;font-size:12px;color:#9fadb8}
</style><div class="board"><header><div class="eyebrow">ART DIRECTION / DESIGN REVIEW ONLY</div><h1>旋转炮身设计提案 · 03</h1><p>沿用原稿的斜面装甲与酒红机械层，让炮塔主体承担造型，外露炮管缩短、收细。仅作外观确认，尚未接入游戏。</p></header><div class="main"><section class="detail"><h2>炮身细节 · 放大审阅</h2><img src="cannon-design.png"><p>主体主导的楔形炮塔 / 阶梯装甲肩<br>短细炮管 / 明暗炮口 / 克制的琥珀指示<br>固定底座不包含在旋转贴图内</p></section><section><h2>嵌入原舰体 · 正常窗口体量</h2><div class="sub">以下舰体不放大，沿用现有 PNG 与 24 个固定底座坐标；浏览器请使用 100% 缩放。</div><div class="grid">'''+''.join(cards)+'''</div></section></div><div class="bottom"><section class="reference"><h2>审美依据 · 15a102ac</h2><img src="../integrated-turret-bases-approved-20261020.png"><p>使用已认可原稿的材质和构造语言。</p></section><section class="turnpanel"><h2>正常比例转向示意 · 指挥 BOSS</h2><div class="turns">'''+''.join(turns)+'''</div></section></div><p class="foot">静态设计拼装示意，非游戏截图。舰体和固定底座原 PNG 未改；只将新炮图按已有轴心作图片叠放。生产资源、挂点、数值、编队和存档未改。等待外观确认。</p></div></html>'''
(HERE/'review.html').write_text(page)
(HERE/'review-measurements.json').write_text(json.dumps({'design_only':True,'screen_scale':meta['screen_scale'],'housing_to_well_ratio':meta['housing_to_well_ratio'],'cases':measure},indent=2)+'\n')
print('Static design board HTML ready')
