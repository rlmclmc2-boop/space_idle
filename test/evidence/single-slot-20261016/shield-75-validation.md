# 盾容量 75%：短验收

- Excel `shield.para1`：500→750；`para2=0.3`、`para3=2`、`para4=0.2`、`dmgtype=1` 不变。`game_data.json` 投影仅对应盾说明和基础容量变化。
- `database.gd` 先按现有算法取得同级甲的战斗取整容量，再乘 Excel 中盾／甲基础值比；不在战斗中维护第二份影子生命。
- `python test/test_equipment_growth_import.py`：8 checks，0 failures。
- Godot `test/test_shield_capacity_ratio.gd`：16 checks，0 failures；覆盖等级 1/2/3/4/10/100/1000，含游戏读取路径与恢复参数检查。编辑器导入 exit 0。
- Godot 导入生成的描述符、`.godot`、用户缓存、`.import/.uid` 已在本工作树清理。
- 后续 18 点设计写于根目录 `FIRST_THREE_GROWTH_PROPOSAL.md`；敌人和反应炉建议未实施。
