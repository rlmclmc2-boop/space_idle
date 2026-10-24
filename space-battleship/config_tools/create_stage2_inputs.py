"""Author stage-2 runtime Excel inputs; never called by the compiler/runtime."""
from pathlib import Path
import argparse,json
import openpyxl

ROOT=Path(__file__).resolve().parents[1]

def main():
    p=argparse.ArgumentParser();p.add_argument('--write',action='store_true',required=True);p.parse_args()
    schema=json.loads((ROOT/'config_tools/schema.json').read_text(encoding='utf-8'))
    production=json.loads((ROOT/'config_tools/production.json').read_text(encoding='utf-8'))
    production['entry']='GameSession'
    schema['runtimeTables']=['battle_rules','battle_geometry','initial_profile','level','monGroup','mon','equipment','res','ship','config','unlock','enemy_weapon_base','weapon_motion','enhance_config']
    schema['tables']['enhance_config']['requiredKeys']=['counter_log_base','bonus_round_scale']
    rules={'clear_wait_seconds':3,'maximum_travel_seconds':3,'retreat_seconds':1.2,'departure_seconds':1.6,
           'back_distance':200,'auto_collect_delay':5,'fragment_collect_delay':2,'auto_collect_reduce':0.5,
           'resistance':0.5,'jewel_probability':0.2,'maximum_speed':10,
           'timed_drop_interval':30,'timed_drop_amount':5,'timed_drop_speed':40,
           'minimum_retreat_seconds':0.001,'maximum_retreat_seconds':3}
    # Logical formation constants exported from enemy_formation.positions and
    # existing native player point. No scene/editor dependency in compilation.
    geometry={'center_x':286,'player_y':520,'single_row_y':140,'back_row_y':110,'middle_row_y':270,'front_row_y':350,
              'columns':5,'maximum_spacing':160,'formation_width':456,'target_slot_center':4.5,'timed_spawn_y':0}
    def table(columns,numeric,primary):
        return dict(columns=columns,primary=[primary],literalOnly=True,fields={c:dict(types=['number'] if c in numeric else ['string']) for c in columns})
    for name,values in [('battle_rules',rules),('battle_geometry',geometry)]:
        schema['tables'][name]=table(['key','value'],['value'],'key')
        schema['tables'][name]['requiredKeys']=list(values)
        schema['tables'][name]['fields']['key']['enum']=list(values)
        schema['tables'][name]['contracts']={key:{'value':{'min':0}} for key in values}
    for key in ['maximum_travel_seconds','retreat_seconds','maximum_speed','timed_drop_interval','timed_drop_speed','minimum_retreat_seconds','maximum_retreat_seconds']:
        schema['tables']['battle_rules']['contracts'][key]['value']['exclusiveMin']=0
    schema['tables']['battle_rules']['contracts']['maximum_speed']['value'].update(integer=True,min=1)
    for key in ['auto_collect_reduce','resistance','jewel_probability']:
        schema['tables']['battle_rules']['contracts'][key]['value']['max']=1
    for key in ['columns','maximum_spacing','formation_width']:
        schema['tables']['battle_geometry']['contracts'][key]['value']['exclusiveMin']=0
    schema['tables']['battle_geometry']['contracts']['columns']['value']['integer']=True
    columns=['id','initial_stage','ship_id','iron_id','uranium_id','fragment_id','chrono_id','initial_amount','initial_chrono','initial_slot_level','death_option']
    schema['tables']['initial_profile']=table(columns,['initial_stage','iron_id','uranium_id','initial_slot_level','death_option'],'id')
    schema['tables']['initial_profile']['fields']['initial_slot_level'].update(integer=True,min=1,max=1)
    for field in ['initial_stage','iron_id','uranium_id','death_option']:schema['tables']['initial_profile']['fields'][field]['integer']=True
    schema['tables']['initial_profile']['fields']['death_option'].update(min=0,max=2)
    for field in ['initial_amount','initial_chrono']:schema['tables']['initial_profile']['fields'][field]['literal']='amount_text'
    schema['tables']['initial_profile']['references']=[dict(field='initial_stage',table='level',target='id'),dict(field='ship_id',table='ship',target='name'),dict(field='iron_id',table='res',target='id'),dict(field='uranium_id',table='res',target='id')]
    session_columns=['case_id','duration','expected_auto','expected_manual','expected_stage','resource']
    schema['tables']['session_case']=table(session_columns,['duration','expected_stage','resource'],'case_id')
    schema['tables']['clock_case']=table(['case_id','mode','balance','speed','real_dt','expected_game','expected_balance'],['speed','real_dt','expected_game'],'case_id')
    schema['tables']['clock_case']['fields']['mode']['enum']=['exhaustion','pause','focus','budget']
    schema['tables']['journey_case']=table(['case_id','mode','duration','resource','expected_amount','death_option'],['duration','resource','death_option'],'case_id')
    schema['tables']['journey_case']['fields']['mode']['enum']=['garrison_timer','retreat']
    schema['tables']['income_case']=table(['case_id','resource','amount','production_base','sample_wall','sample_game','now_wall','now_game','expected_wall','expected_game','expected_production'],['resource','sample_wall','sample_game','now_wall','now_game'],'case_id')
    schema['tables']['ratio_case']=table(['case_id','field','entry_field','entry','end','point','mon_group','length','expected'],['point','length'],'case_id')
    schema['tables']['ratio_case']['fields']['field']['enum']=['atkRatio','lifeRatio','resRatio']
    schema['tables']['ratio_case']['fields']['entry_field']['enum']=['entryAtkRatio','entryLifeRatio','']
    for field in ['entry','end','expected']:schema['tables']['ratio_case']['fields'][field]['literal']='amount_text'
    schema['tables']['mon'].setdefault('structuredReferences',[])
    schema['tables']['mon']['structuredReferences']=[r for r in schema['tables']['mon']['structuredReferences'] if r['field']!='res']+[dict(field='res',table='res',target='id',kind='resource_drop')]
    for field in ['health','shield','dmgMultiple']:schema['tables']['mon']['fields'][field]['min']=0
    for field in ['length','atkRatio','lifeRatio','resRatio','jewelRatio','entryAtkRatio','entryLifeRatio']:schema['tables']['level']['fields'][field]['min']=0
    for table_name,fields in {'kernel_case':['damage','enemy_hp','enemy_shield','expected_hp','expected_shield'], 'wave_case':['player_hp','player_damage','enemy_hp','enemy_damage','drop_amount'], 'clock_case':['balance','expected_balance']}.items():
        for field in fields:schema['tables'][table_name]['fields'][field]['literal']='amount_text'
    for field in ['history_start','expected_attacks']:schema['tables']['kernel_case']['fields'][field]['literal']='int64_text'
    def write_sheet(book,name,cols,rows):
        if name in book:del book[name]
        s=book.create_sheet(name);s.append(cols);s.append(['runtime contract']*len(cols));s.append(['literal']*len(cols))
        for row in rows:s.append(row)
    for name,rows in [('battle_rules',list(rules.items())),('battle_geometry',list(geometry.items())),('initial_profile',[['default',1,'Frigate',1,2,'jewel','chrono','0','0',1,0]])]:
        path=ROOT/'config_excel'/(name+'.xlsx');book=openpyxl.Workbook();book.remove(book.active)
        write_sheet(book,name,schema['tables'][name]['columns'],rows);book.save(path)
        production['workbooks']=[e for e in production['workbooks'] if e['path']!='../config_excel/'+path.name]
        production['workbooks'].append(dict(path='../config_excel/'+path.name,classification='active',sheets=[dict(sheet=name,table=name)]))
    path=ROOT/'tests/excel/core_rules.xlsx';book=openpyxl.load_workbook(path)
    kernel=schema['tables']['kernel_case']
    old_columns=[cell.value for cell in book['kernel_case'][1]]
    kernel_rows=[dict(zip(old_columns,values)) for values in list(book['kernel_case'].values)[3:]]
    for field in ['history_level','history_growth','round_scale']:
        if field not in kernel['columns']:kernel['columns'].append(field)
        kernel['fields'][field]=dict(types=['number'],min=0)
    for row in kernel_rows:
        row.setdefault('history_level',0);row.setdefault('history_growth',0);row.setdefault('round_scale',100)
    zero=dict(next(row for row in kernel_rows if row['case_id']=='C12-cannon'),case_id='C00-zero',damage='0',enemy_shield='0',expected_hp='1000',expected_shield='0')
    ordinary=dict(zero,case_id='D01-history',damage='10',enemy_hp='100',expected_hp='87',history_start='1',expected_attacks='2',history_level=1,history_growth=1)
    large=dict(ordinary,case_id='D02-large-history',damage='1e500',enemy_hp='1e502',expected_hp='8.305e501',history_start='9007199254740993',expected_attacks='9007199254740994')
    for row in [zero,ordinary,large]:
        kernel_rows=[existing for existing in kernel_rows if existing['case_id']!=row['case_id']]+[row]
    write_sheet(book,'kernel_case',kernel['columns'],[[row[column] for column in kernel['columns']] for row in kernel_rows])
    test_rules=dict(rules,clear_wait_seconds=0.1,maximum_travel_seconds=0.2,retreat_seconds=0.1,departure_seconds=0,auto_collect_delay=0.2,fragment_collect_delay=0.1,jewel_probability=0)
    test_geometry=dict(geometry,center_x=0,player_y=100,single_row_y=0,back_row_y=0,middle_row_y=20,front_row_y=40)
    clock_rows=[['T01-session','exhaustion','0.25',2,1,1.25,'0'],['T02-session','pause','0.25',2,1,1.25,'0'],['T03-focus','focus','0.25',2,1,1.25,'0.25'],['T03-budget','budget','0.25',2,1,1.25,'0']]
    journey_rows=[['J01-garrison-timer','garrison_timer',45,72,'3',1],['J02-retreat','retreat',0.3,71,'0',0]]
    income_rows=[['E02-left',71,'60','30',0,0,60,60,'0','0','0'],['E02-inside',71,'60','30',0.5,0.5,60,60,'1','1','0.5'],
        ['E02-right',71,'60','30',60,60,60,60,'1','1','0.5'],['E02-future',71,'60','30',60.1,60.1,60,60,'0','0','0'],
        ['E02-clocks',71,'60','30',0,40,60,60,'0','1','0.5']]
    ratio_rows=[['V01-normal','atkRatio','entryAtkRatio','1','3',1,'{9201|0.2,9201|0.5,9201|0.9}',100,'2'],
        ['V02-large','atkRatio','entryAtkRatio','1e500','3e500',1,'{9201|0.2,9201|0.5,9201|0.9}',100,'2e500'],
        ['V03-decreasing','lifeRatio','entryLifeRatio','3e500','1e500',1,'{9201|0.2,9201|0.5,9201|0.9}',100,'2e500']]
    for name,rows in [('battle_rules',list(test_rules.items())),('battle_geometry',list(test_geometry.items())),('initial_profile',[['default',1,'fixture_ship',71,72,'jewel','chrono','0','0',1,0]]),('session_case',[['E01-session',20,'2','3',1,71]]),('clock_case',clock_rows)]:
        write_sheet(book,name,schema['tables'][name]['columns'],rows)
    write_sheet(book,'journey_case',schema['tables']['journey_case']['columns'],journey_rows)
    write_sheet(book,'income_case',schema['tables']['income_case']['columns'],income_rows)
    write_sheet(book,'ratio_case',schema['tables']['ratio_case']['columns'],ratio_rows)
    # Explicit seeds live in the same case table for every scenario family.
    existing={book['case'].cell(r,1).value for r in range(4,book['case'].max_row+1)}
    for key,duration in [('E01-session',20)]+[(row[0],row[4]) for row in clock_rows]+[(row[0],row[2]) for row in journey_rows]+[(row[0],0) for row in income_rows+ratio_rows]+[(row['case_id'],row['duration']) for row in [zero,ordinary,large]]:
        if key not in existing:book['case'].append([key,'core_rules',17,duration,'session_exact'])
    for name,rows in [('ship',[['fixture_ship','independent fixture',1,1,50,None,1,999]]),('config',[['startEquip','independent fixture','armour,laser']])]:
        write_sheet(book,name,schema['tables'][name]['columns'],rows)
    write_sheet(book,'enhance_config',schema['tables']['enhance_config']['columns'],[
        ['counter_log_base',10,'fixture','shared log base'],['bonus_round_scale',100,'fixture','shared precision']])
    write_sheet(book,'unlock',schema['tables']['unlock']['columns'],[
        ['armour','equipment','armour',0,'cleared','fixture','fixture'],['laser','equipment','laser',0,'cleared','fixture','fixture'],
        ['fixture_ship','ship','fixture_ship',0,'cleared','fixture','fixture'],['feature/jewels','feature','jewels',0,'reached','fixture','fixture']])
    motion={'player_projectile_pixels_per_unit':1,'enemy_projectile_pixels_per_unit':1,'chain_carrier_speed':720,
        'missile_ejection_gap':0.12,'missile_launch_speed':100,'missile_turn_rate':4,'missile_orphan_lifetime':30,
        'missile_ignition_at':0.22,'missile_seek_start':0.4,'missile_cruise_at':0.65,'missile_lifetime':4.5,
        'missile_brake_range':120,'missile_brake_angle':0.3,'missile_min_guided_speed':10,'missile_brake_factor':0.7,'missile_hit_radius':5}
    write_sheet(book,'weapon_motion',schema['tables']['weapon_motion']['columns'],[[key,value,'fixture','independent','runtime'] for key,value in motion.items()])
    # Explicit independent definitions; no production content fills missing rows.
    if not any(book['res'].cell(r,1).value==72 for r in range(4,book['res'].max_row+1)):book['res'].append([72,'test_uranium'])
    level=book['level'];headers=[c.value for c in level[1]]
    level.cell(4,headers.index('id')+1,1)
    level.cell(4,headers.index('monGroup')+1,'{9201|0.5,9201|0.9}')
    book.save(path)
    manifest=dict(schemaVersion=1,kind='test',entry='GameSession',inputRoot='.',workbooks=[dict(path=path.name,classification='active',sheets=[dict(sheet=s,table=s) for s in book.sheetnames])])
    (ROOT/'tests/excel/core_rules.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (ROOT/'config_tools/schema.json').write_text(json.dumps(schema,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (ROOT/'config_tools/production.json').write_text(json.dumps(production,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':main()
