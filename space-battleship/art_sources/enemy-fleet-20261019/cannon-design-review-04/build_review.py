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
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><title>宽扁旋转炮塔设计 04</title><style>
*{box-sizing:border-box}body{margin:0;background:#0c1823;color:#e3ebf1;font:14px "Noto Sans CJK SC",sans-serif}.board{width:1240px;padding:32px;margin:0 auto}header{border-bottom:1px solid #34424e;padding-bottom:16px;margin-bottom:20px}h1{font-size:27px;font-weight:600;letter-spacing:2px;margin:0 0 8px}.eyebrow{font-size:12px;letter-spacing:2px;color:#e9b078;margin-bottom:8px}p{color:#a8bac8;line-height:1.7;margin:4px 0}h2{font-size:17px;font-weight:500;margin:0 0 12px}h3{font-size:13px;margin:0;font-weight:500}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:10px}.card{border:1px solid #2a3e4d;background:#132331;text-align:center;height:205px}.card p{font-size:11px;margin:3px 0}.native{position:relative;height:162px;width:100%}.ship{position:absolute;left:50%;top:50%;width:0;height:0}.hull,.gun{position:absolute;max-width:none}.mount{position:absolute;width:0;height:0;transform-origin:0 0}.sub{font-size:12px;color:#a8bac8;margin-bottom:12px}.bottom{display:grid;grid-template-columns:1fr 340px;gap:24px;margin-top:24px;border-top:1px solid #34424e;padding-top:20px}.detail{background:#132331;border:1px solid #34424e;padding:16px;text-align:center}.detail img{width:280px;height:200px;object-fit:contain}.detail p{font-size:12px}.turns{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}.turn{text-align:center;background:#132331;border:1px solid #2a3e4d}.turn .native{height:200px}.turn h3{padding-bottom:12px}.foot{border-top:1px solid #34424e;margin-top:22px;padding-top:12px;font-size:12px;color:#9fadb8}
</style><div class="board"><header><div class="eyebrow">ART DIRECTION / DESIGN REVIEW ONLY</div><h1>宽扁旋转炮塔 · 04</h1><p>先看正常窗口体量：宽肩装甲主体占住承载面，短细炮管仅小幅突出。舰体和固定底座沿用原 PNG。</p></header><section class="normal-board"><h2>01 / 正常显示比例 · 八版整舰搭配</h2><div class="sub">舰体不放大，按已有实机体量和底座坐标静态叠放；请以 100% 查看。以下为设计示意，未接入游戏。</div><div class="grid">'''+''.join(cards)+'''</div></section><div class="bottom"><section><h2>02 / 正常比例转向 · 指挥 BOSS</h2><div class="turns">'''+''.join(turns)+'''</div><p class="sub" style="margin-top:12px">只有宽扁炮塔主体转动；固定底座与舰体不动。</p></section><section class="detail"><h2>03 / 装甲结构细节</h2><img src="cannon-design.png"><p>宽扁顶甲 / 厚实侧缘 / 收拢炮口<br>少量大块明暗形成结构，炮管为小型附属。</p></section></div><p class="foot">审美依据：15a102ac 已认可舰体原稿。静态设计拼装示意，非实机截图；生产资源、挂点、数值与编队未改。等待外观审阅。</p></div></html>'''
(HERE/'review.html').write_text(page)
(HERE/'review-measurements.json').write_text(json.dumps({'design_only':True,'screen_scale':meta['screen_scale'],'housing_to_well_ratio':meta['housing_to_well_ratio'],'cases':measure},indent=2)+'\n')
print('Static design board HTML ready')
# Matched normal-scale comparison; shared unchanged hulls and socket centres.
current_meta=meta.copy();current_w,current_h=W,H
old_meta=json.loads((HERE.parent/'cannon-design-review-03/design-meta.json').read_text())
pairs=[]
for case,label in [('command_boss','指挥 BOSS'),('reactive_elite','反应精英')]:
    meta=old_meta;W,H=Image.open(HERE.parent/'cannon-design-review-03/cannon-design.png').size
    before,_=assembly(case);before=before.replace('src="cannon-design.png"','src="../cannon-design-review-03/cannon-design.png"')
    meta=current_meta;W,H=current_w,current_h;after,_=assembly(case)
    pairs += [f'<div class="compare-card"><p>03 · 已否决 / {label}</p><div class="native">{before}</div></div>',f'<div class="compare-card"><p>04 · 宽扁主体 / {label}</p><div class="native">{after}</div></div>']
style=page[page.index('<style>'):page.index('</style>')+8]
comparison='<!doctype html><meta charset="utf-8">'+style+'''<style>.compare-board{width:760px;padding:28px}.compare-grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}.compare-card{background:#132331;border:1px solid #34424e;text-align:center;height:215px}.compare-card p{font-size:13px;padding-top:12px}.compare-card .native{height:170px}</style><div class="compare-board"><h1>先看正常尺寸</h1><p style="margin-bottom:20px">同一舰体、同一底座、同一窗口体量；静态设计示意，未接入游戏。</p><div class="compare-grid">'''+''.join(pairs)+'''</div><p class="foot">03：细长尖状炮身（已否决）。04：横向宽肩装甲主体，短炮管小幅突出。<br>请用100%查看；设计图片直接叠放，未改舰体与固定底座。</p></div>'''
(HERE/'normal-comparison.html').write_text(comparison)
