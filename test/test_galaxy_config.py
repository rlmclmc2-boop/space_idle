"""Galaxy Excel descriptions, projection and invalid table coverage."""
from pathlib import Path
import copy,json,sys,unittest
import openpyxl
ROOT=Path(__file__).resolve().parents[1]/'space-battleship'
sys.path.insert(0,str(ROOT/'tools'))
from import_workbook import convert_sheet,read_rows,validate_projection

class GalaxyConfigTests(unittest.TestCase):
    def test_tables_and_projection(self):
        data=json.loads((ROOT/'data/game_data.json').read_text(encoding='utf-8'))
        for name in ('galaxy','galaxy_build','galaxy_config'):
            sheet=openpyxl.load_workbook(ROOT/'config_excel'/f'{name}.xlsx',data_only=True).active
            self.assertTrue(all(cell.value for cell in sheet[2]))
            self.assertTrue(all(cell.value for cell in sheet[3]))
            self.assertEqual(convert_sheet(name,read_rows(sheet)),data[name])
        validate_projection(data)
        self.assertEqual(data['unlock']['feature/galaxy']['level'],60)
        for field,value in [('map_w',0),('explore_work_total',0),('building_slot_count',0),('concurrent_upgrade_count',0),('upgrade_cost_lv2',0),('next_galaxy','missing'),('colony_grid_w',12)]:
            broken=copy.deepcopy(data)
            broken['galaxy']['galaxy_1'][field]=value
            with self.assertRaises(ValueError):validate_projection(broken)
        broken=copy.deepcopy(data)
        broken['galaxy_build']['colony_ring']['effect_type']='unknown'
        with self.assertRaises(ValueError):validate_projection(broken)
        rows=[{'key':'a'},{'key':'a'}]
        with self.assertRaises(ValueError):convert_sheet('galaxy',rows)

if __name__=='__main__':unittest.main()
