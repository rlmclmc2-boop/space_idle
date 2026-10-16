# 三种任务的定位读取演示

基准是“把相关原件整个送入上下文”的假设读取量，不声称旧流程实际如此执行。源文件大小是磁盘字节；新流程数字是本分支工具输出的 Unicode 字符数，两者不是同一单位，也不是计费 TOKEN。工具仍可能扫描或解析整个目标文件；减少的是返回给模型的内容。均未修改游戏内容或运行游戏测试。

| 任务 | 未切片原件的大小 | 实际定位命令与返回字符 | 何时扩展 |
|---|---:|---|---|
| 界面文案 `battle.finale_cleared` | `ui_text.json` 456960 字节 + `ui_text_contract.json` 207604 字节 | `json --path data/ui_text.json --where key=battle.finale_cleared --fields key,text,params` → 86 字符；`json --path data/ui_text_contract.json --key entries/battle.finale_cleared` → 19 字符 | 若绑定或特殊来源存疑，读 `docs/UI_TEXT.md` 命中行；只查目标 KEY |
| 装备表 `armour` | `equipment.xlsx` 9000 字节；仅投影问题才触及 `game_data.json` 6889097 字节 | `xlsx --path config_excel/equipment.xlsx --sheet equipment --find armour --columns 1 3 4` → 171 字符；`json --path data/game_data.json --key equipment.armour.0 --fields name,level,dmgtype` → 53 字符 | 字段定义存疑才读表头指定列；导入问题才定位 `tools/import_workbook.py` 的目标函数 |
| 局部战斗函数 `hit_enemy` | `game.gd` 236148 字节 + `BATTLE.md` 941 字节 | `grep --path scripts/game.gd --query "func hit_enemy"` → 162 字符，定位到 2580 行；`slice --path scripts/game.gd --start 2580 --count 12` → 833 字符 | 若修复需要调用链或共享效果边界，记下缺口后查直接调用者、`BATTLE.md` 对应条目和最小相关测试 |

以上命令均以 `python tools/read_budget.py` 开头，在 `space-battleship/` 执行。返回字符不含命令本身和平台自动注入上下文。默认 stdout 上限 1800 字符；超限给保存路径、总行数、字符数及续读入口。实际受影响正确性仍按 `docs/BATTLE.md`、`docs/TEST.md` 验证。
