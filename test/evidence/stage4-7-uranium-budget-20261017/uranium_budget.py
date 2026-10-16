from pathlib import Path
import json,math,sys
source=Path(sys.argv[1])
data=json.loads(source.read_text(encoding='utf8'))
assert data['config']['autoGenRes']=='30,2,5,40'
assert float(data['config']['autoCollectReduce'])==0.5
rows=[]
for index in range(7):
    level=data['levels'][index]
    enemy_uranium=0
    for encounter in level['groups']:
        group=data['groups'][str(int(encounter['id']))]
        for eid in group['slots']:
            if eid is None:continue
            for drop in data['enemies'][str(eid)]['drops']:
                if int(drop['resourceId'])==2:
                    enemy_uranium+=drop['amount']*drop['chance']
    amount=math.ceil(5*float(level['resRatio']))
    rows.append({'stage':index+1,'points':len(level['groups']),'res_ratio':level['resRatio'],'enemy_uranium_expected':enemy_uranium,'per_30s_manual':amount,'per_30s_auto':math.ceil(amount*.5)})
reactor9=sum(math.ceil(10*1.35**(n-1)) for n in range(1,9))
assert reactor9==290
scientist1_uranium=5
need=reactor9+scientist1_uranium
result={'source':'space-battleship/data/game_data.json','auto_gen_config':'30,2,5,40','auto_collect_reduce':.5,'stage_rows':rows,'one_spawn_each_stage':{'manual':sum(x['per_30s_manual'] for x in rows),'auto':sum(x['per_30s_auto'] for x in rows)},'reactor_level_1_to_9_uranium':reactor9,'one_scientist_uranium':scientist1_uranium,'two_ai_first_levels_tech_points':120,'total_uranium_need':need,'one_spawn_each_gap':{'manual':need-sum(x['per_30s_manual'] for x in rows),'auto':need-sum(x['per_30s_auto'] for x in rows)},'stage7_only_spawns_needed':{'manual':math.ceil(need/rows[-1]['per_30s_manual']),'auto':math.ceil(need/rows[-1]['per_30s_auto'])}}
print(json.dumps(result,ensure_ascii=False,indent=2))
