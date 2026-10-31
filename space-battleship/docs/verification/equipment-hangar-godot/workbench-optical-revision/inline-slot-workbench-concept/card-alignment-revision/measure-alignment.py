from pathlib import Path
import json,re,hashlib
from PIL import Image
p=Path('/tmp/space-idle-workbench-rebuild/alignment-native');ops=json.loads((p/'inline-native-operations.json').read_text())
cases={'natural early rectangular cards':'early','middle5 real state with true empty slots':'middle-empty','late true empty slots before loadout restoration':'late-empty','late only matter insufficient':'late-matter-poor','late actual longMAX':'long-max','late bottom complete boundary':'bottom'}
def rect(value):return [float(x) for x in re.findall(r'-?\d+(?:\.\d+)?',value)]
def ink(image,box):
 x0,y0,x1,y1=[int(v) for v in box];pixels=image.load();hits=[]
 for y in range(y0,y1):
  for x in range(x0,x1):
   r,g,b=pixels[x,y][:3]
   if r<110 and g<135 and b<150:hits.append((x,y))
 assert hits,box
 return [min(x for x,y in hits),min(y for x,y in hits),max(x for x,y in hits)+1,max(y for x,y in hits)+1]
rows=[]
for case in ops['records']:
 if case['case'] not in cases:continue
 file=p/('inline-native-'+cases[case['case']]+'.png');im=Image.open(file).convert('RGB')
 for c in case['cards']:
  if c.get('empty'):continue
  card=rect(c['rect']);name=rect(c['name_rect']);attribute=rect(c['attribute_rect']);fee=rect(c['fee_title_rect']);qty=rect(c['quantity_rect'])
  name_ink=ink(im,[name[0]+8,name[1]+3,name[0]+150,name[1]+name[3]-2])
  attribute_ink=ink(im,[attribute[0],attribute[1],min(qty[0]-10,attribute[0]+attribute[2]),attribute[1]+attribute[3]])
  fee_ink=ink(im,[fee[0],fee[1],fee[0]+fee[2],fee[1]+fee[3]])
  gap=attribute_ink[1]-(name[1]+name[3]);bottom=card[1]+card[3]-1-fee_ink[3]
  assert gap>=6,(file,c['slot'],gap)
  assert bottom>=4,(file,c['slot'],bottom)
  assert max(name_ink[0],attribute_ink[0],fee_ink[0])-min(name_ink[0],attribute_ink[0],fee_ink[0])<=1,(file,c['slot'],name_ink,attribute_ink,fee_ink)
  rows.append({'file':file.name,'slot':c['slot'],'name':c['name'],'name_ink':name_ink,'attribute_ink':attribute_ink,'fee_title_ink':fee_ink,'name_frame_to_attribute_ink_px':gap,'fee_ink_to_card_bottom_px':bottom,'name_attribute_fee_left_spread_px':max(name_ink[0],attribute_ink[0],fee_ink[0])-min(name_ink[0],attribute_ink[0],fee_ink[0]),'image_sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
result={'scope':'Pixel ink threshold support on complete original screenshots, not a substitute for original-size visual review','method':'Dark text pixels r<110,g<135,b<150 within recorded name/property/fee-title regions; icon and action column excluded. Main screenshot unedited.','rows':rows,'minimum_name_frame_to_attribute_ink_px':min(r['name_frame_to_attribute_ink_px'] for r in rows),'minimum_fee_ink_to_card_bottom_px':min(r['fee_ink_to_card_bottom_px'] for r in rows),'maximum_text_left_spread_px':max(r['name_attribute_fee_left_spread_px'] for r in rows)}
(p/'glyph-spacing.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print({k:v for k,v in result.items() if k not in ['rows','method','scope']},'cards',len(rows))
