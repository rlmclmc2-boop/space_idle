from pathlib import Path
import json,math,subprocess
repo=Path(__file__).resolve().parents[3]
project=repo/'space-battleship'
base=json.loads(subprocess.check_output(['git','show','c66190090c3bded4e09beb347acad59e589910c2:space-battleship/data/game_data.json'],cwd=repo))
new=json.loads((project/'data/game_data.json').read_text(encoding='utf8'))
def points(data,stage):
 level=data['levels'][stage-1]
 previous=1.0 if stage==1 else float(data['levels'][stage-2]['resRatio'])
 result=[]
 for index,encounter in enumerate(level['groups']):
  ratio=previous+(float(level['resRatio'])-previous)*(index/max(1,len(level['groups'])-1))
  amounts={'iron_manual':0,'iron_auto':0,'uranium_manual':0,'uranium_auto':0}
  for eid in data['groups'][str(int(encounter['id']))]['slots']:
   if eid is None:continue
   for drop in data['enemies'][str(eid)]['drops']:
    if float(drop['chance'])!=1:continue
    paid=math.ceil(float(drop['amount'])*ratio)
    name='iron' if int(drop['resourceId'])==1 else 'uranium'
    amounts[name+'_manual']+=paid
    amounts[name+'_auto']+=math.ceil(paid*.5)
  result.append({'point':index+1,'ratio':round(ratio,4),**amounts})
 return result
rows={}
for stage in range(4,8):
 old,new_rows=points(base,stage),points(new,stage)
 rows[str(stage)]={'main':old,'candidate':new_rows,'totals':{k:{'main':sum(x[k] for x in old),'candidate':sum(x[k] for x in new_rows)} for k in ('iron_manual','iron_auto','uranium_manual','uranium_auto')}}
print(json.dumps(rows,ensure_ascii=False,indent=2))
