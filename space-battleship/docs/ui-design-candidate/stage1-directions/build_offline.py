"""Build the offline comparison package; requires fontTools. No runtime/game writes.
Run python docs/ui-design-candidate/stage1-directions/build_offline.py from the project.
The generated ZIP opens directly via file://; no server, fetch, CDN, or installation.
"""
from pathlib import Path
import base64,hashlib,io,json,re,tempfile,zipfile
from fontTools import subset
from fontTools.ttLib import TTFont
HERE=Path(__file__).resolve().parent
PROJECT=HERE.parents[2]
IMAGE_PATHS=[
 'assets/backgrounds/opening/stage_01.png',
 'assets/ships/enemy/fleet_20261019/scout.png',
 'assets/ships/enemy/fleet_20261019/anchor.png',
 'assets/ships/fleet_20261019/player/03-cruiser.png',
 'assets/ui/ships/fleet_20261019/03-cruiser.png',
 'assets/weapons/fleet_20261019/cannon.png',
 'assets/weapons/fleet_20261019/missile.png',
 'assets/weapons/fleet_20261019/longLaser.png',
 'assets/ai_tech_factory/workshop-background-v2.png',
 'assets/ai_tech_factory/weapon-accuracy-v2.png',
 'assets/ui/planet-globe.png'
]
def sha(data):return hashlib.sha256(data).hexdigest()
# Include all literals used by the reference, plus explanatory text; not full font sets.
text=''.join(p.read_text() for p in HERE.iterdir() if p.suffix in ['.html','.js','.css','.md'])
font_records=[]
def font_data(filename,family):
 source=PROJECT/'assets/fonts'/filename
 font=TTFont(source,recalcTimestamp=False)
 options=subset.Options();options.layout_features=['*']
 sub=subset.Subsetter(options=options);sub.populate(text=text);sub.subset(font)
 for record in font['name'].names:
  if record.nameID in [1,3,4,6,16]:record.string=family.encode(record.getEncoding())
 font.flavor='woff';stream=io.BytesIO();font.save(stream);data=stream.getvalue()
 font_records.append({'source':'assets/fonts/'+filename,'source_sha256':sha(source.read_bytes()),'embedding':'data:font/woff in directions.css','subset_family':family,'subset_sha256':sha(data),'subset_bytes':len(data)})
 return 'data:font/woff;base64,'+base64.b64encode(data).decode('ascii')
font_primary=font_data('NotoSansSC.ttf','SpaceIdleReferenceSC')
font_symbols=font_data('NotoSansSymbols2-Regular.ttf','SpaceIdleReferenceSymbols')
landing='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>离线 · 四方向比较</title><link rel="stylesheet" href="directions.css"><style>body{height:auto;padding:28px;line-height:1.9}header,section{max-width:1100px;margin:0 auto 24px}h1{font-size:26px}a{color:#a9ddc5}section.grid{display:grid;grid-template-columns:1fr 1fr;gap:20px}article{border:1px solid #6f9d8e;border-radius:10px;padding:20px}article p{margin:10px 0;font-size:13px}img{max-width:100%}.note{color:#c5d8c4;font-size:12px}nav{display:flex;gap:16px;flex-wrap:wrap}</style><header><h1>四方向离线HTML / SVG参考</h1><p>解压后直接打开此文件。仅空间/操作比较，未选方案、不足以批准美术、没有游戏或后台连接。</p><p>共用任务：观看→打开模块→W1购级两次→W2直接选导弹并换装→W3购级→返回W1；也可使用审阅工具切换预置状态。反应炉意图只改预览，不提交金额。</p><img src="overview.svg" alt="四种组织关系示意"></header><section class="grid">'''
for key,title,desc in [
 ('a','A 全景＋侧浮坞','模块按需浮出；不足反馈贴近购级操作。'),
 ('b','B 下沿工作台','操作横向铺于下沿，打开后观看区域缩小。'),
 ('c','C 舱室模式＋战况仪','工作时隐藏主战场，保留战况；一步切回完整观看。'),
 ('d','D 常驻双焦工作场','双焦区域常在；1440窗口默认开合战场中心横移约101px，并非位置保留。')]:
 landing+=f'<article><h2>{title}</h2><p>{desc}</p><nav><a href="preview.html?direction={key}">空闲 / 交互</a><a href="preview.html?direction={key}&state=reactor">反应炉</a><a href="preview.html?direction={key}&state=fleet">舰装</a><a href="preview.html?direction={key}&state=failure">不足</a></nav></article>'
landing+='''</section><section class="note"><p>反应炉默认层为意图/占比/效果排版样例，e24完整金额在“完整供能金额”中；效果例未由详情金额求值；这不规定分配粒度或新增映射。脉冲详情为飞行接触。所有金额/属性/回执固定，不是完整经济模拟。</p><p>只含必要图片、子集字体（内嵌CSS）及许可；不含游戏、证据截图或封存试验。详见offline-manifest.json与licenses。原工程源文件未被替换。</p></section></html>'''
# The offline landing has extra explanatory labels, already covered by the source docs.
with tempfile.TemporaryDirectory(prefix='space-idle-offline-') as tmp:
 root=Path(tmp);records=[]
 def add(path,data,source=None):
  dest=root/path;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
  row={'path':path,'bytes':len(data),'sha256':sha(data)}
  if source:row.update(source=source,source_sha256=sha((PROJECT/source).read_bytes()))
  records.append(row)
 for name in ['preview.html','directions.js','directions.css','overview.svg']:
  contents=(HERE/name).read_text().replace('../../../assets/','assets/')
  if name=='preview.html':contents=contents.replace('href="README.md"','href="index.html"')
  if name=='directions.css':
   contents=contents.replace("url('assets/fonts/NotoSansSC.ttf')",'url("'+font_primary+'")')
   contents=contents.replace('noto,sans-serif','noto,reference_symbols,sans-serif')
   contents+='\n@font-face{font-family:reference_symbols;src:url("'+font_symbols+'")}\n'
  add(name,contents.encode(),str((HERE/name).relative_to(PROJECT)))
 add('index.html',landing.encode())
 for path in IMAGE_PATHS:add(path,(PROJECT/path).read_bytes(),path)
 for source,target in [('assets/fonts/OFL.txt','licenses/NotoSansSC-OFL.txt'),('assets/fonts/NotoSansSymbols2-OFL.txt','licenses/NotoSansSymbols2-OFL.txt')]:add(target,(PROJECT/source).read_bytes(),source)
 readme='Stage 1 offline comparison. Extract and open index.html directly. No server or network needed. Only spatial/operation references; no art approval or game/API connection. Images copied unchanged from repository; font subsets embedded in CSS. No evidence screenshots, backend, saves or archived experiments.\n'
 add('README.txt',readme.encode())
 manifest={'identity':'offline HTML/SVG spatial and operation references only','files':records,'embedded_font_subsets':font_records,'excluded':['game implementation','saves','credentials','evidence screenshots','archived world experiment']}
 manifest_bytes=(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode();(root/'offline-manifest.json').write_bytes(manifest_bytes)
 with zipfile.ZipFile(HERE/'offline-reference.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
  for file in sorted(root.rglob('*')):
   if file.is_file():
    entry=zipfile.ZipInfo(file.relative_to(root).as_posix(),date_time=(2026,10,27,0,0,0));entry.compress_type=zipfile.ZIP_DEFLATED;entry.external_attr=0o644<<16;archive.writestr(entry,file.read_bytes())
 (HERE/'offline-manifest.json').write_bytes(manifest_bytes)
print(json.dumps({'zip_bytes':(HERE/'offline-reference.zip').stat().st_size,'files':len(records)+1,'image_files':len(IMAGE_PATHS),'font_subset_bytes':[x['subset_bytes'] for x in font_records]},ensure_ascii=False))
