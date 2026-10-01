"""Enhancement authoring/import validation; never reads a player save."""
import copy,json,pathlib,sys
import openpyxl
ROOT=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'space-battleship/tools'))
from import_workbook import convert_sheet,read_rows,validate_projection
p=ROOT/'space-battleship';d=json.loads((p/'data/game_data.json').read_text())
b=openpyxl.load_workbook(p/'config_excel/enhance_config.xlsx',data_only=True,read_only=True)
rows=read_rows(b['enhance_config']);projection=convert_sheet('enhance_config',rows);b.close()
assert projection==d['enhance_config']
validate_projection(d)
assert len(rows)==65 and all(r['des'] and r['unit'] for r in rows)
invalid_cases=[('repeat_probability',2),('memory_interval',0),('cost_base',-1),('deferred_clear_probability',-1),('counter_log_base',1),('threshold_2',49),('cost_base',1.5),('cost_growth',1.5),('cost_growth',0),('cost_growth',-1),('cost_growth',True),('branch_threshold_2',9),('memory_b1_probability',2),('memory_b2_duration',0),('repeat_b2_repeats',1.5),('repeat_b1_targets',11),('critical_b2_duration',-1)]
for key,value in invalid_cases:
 broken=copy.deepcopy(d);broken['enhance_config'][key]['value']=value
 try:validate_projection(broken)
 except ValueError:pass
 else:raise AssertionError(key+' accepts invalid '+str(value))
alternative=copy.deepcopy(d)
for key,value in [('cost_base',7),('cost_growth',2),('threshold_1',10),('threshold_2',20),('threshold_3',30),('deferred_clear_probability',1),('memory_interval',.4),('deferred_duration',4)]:alternative['enhance_config'][key]['value']=value
validate_projection(alternative)
alternative['enhance_config']['cost_growth']['value']=1
validate_projection(alternative)
assert 'cost_exponent' not in d['enhance_config'] and d['enhance_config']['cost_growth']['value']==3
for name in ['crew_assignment','planet_buff']:
 b=openpyxl.load_workbook(p/f'config_excel/{name}.xlsx',data_only=True,read_only=True)
 assert convert_sheet(name,read_rows(b[name]))==d[name];b.close()
assert all(row['value']==1 for row in d['planet_buff'].values() if row['target']=='enhancement')
assert d['crew_assignment']['jewel_auto']['effectType']=='AUTO_COMBINE'
print(f'ENHANCE CONFIG: passed; {len(invalid_cases)} invalid inputs rejected; growth1/2 valid; 65 rows match workbook')
