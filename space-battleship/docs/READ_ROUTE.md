# 按任务定位

每个 `##` 是 `read_budget.py route --task` 的真实锚点。路径相对 `space-battleship/`；列出的文件、行或符号是白名单定位，不自动展开其中链接。先查文件名，再查目标符号，最后读有限片段。未命中时记录缺口及精确扩读范围。父专用 `PROJECT_CONSTRAINTS` 不在路由内。

## ui-text 界面文案

首读：`docs/UI_TEXT.md` 命中行；`data/ui_text.json` 目标 KEY；`data/ui_text_contract.json` 同 KEY。必要时：`scripts/ui_text.gd: t`；特殊来源看 `UI_TEXT.md` Exceptions 行；检查命令看 CHECK 行。

## equipment-data 装备表字段与导入

首读：`config_excel/equipment.xlsx` 指定 sheet/行/列；`tools/import_workbook.py` 目标字段符号。必要时：`docs/DECISIONS.md: D003`、`docs/ARCHITECTURE.md: DATA`；仅投影问题查 `data/game_data.json: equipment` 目标记录。

## combat-local 局部战斗修复

首读：`scripts/game.gd` 目标 `func` 与直接调用者；`docs/BATTLE.md` 相关条目。必要时：`docs/ARCHITECTURE.md: LOCATE`；既有行为按目标关键词定位 `docs/PROJECT.md` 段；测试选择看 `docs/TEST.md`。

## equipment-slot 装备槽状态

首读：`scripts/game.gd: module_entry/equip_slot/unequip_slot/switch_ship/upgrade_slot`。必要时：`docs/DECISIONS.md: D004` 和直接受影响 specialty test。

## save 保存与档案

首读：`scripts/game.gd: load_progress/save_progress`；`scripts/progress_writer.gd`。必要时：`docs/ARCHITECTURE.md: OWNER`、`docs/STATUS.md: U-008`、`docs/TEST.md` 命中段。

## ui-code 界面绘制与输入

首读：`scripts/main.gd` 的目标函数或具体 page 脚本。必要时：`docs/UI.md` 命中段；文案同时按 `ui-text` 路线。

## balance 数值与模拟

首读：目标 `config_excel/*.xlsx` 行；`scripts/balance_runner.gd` 或具体模拟器函数。必要时：`docs/BALANCE_LAB.md` 命中段；性能才读 `docs/BALANCE_PERFORMANCE.md`。

## specialty 美术、船员、银河、关卡编辑

首读：目标资产或脚本符号。必要时：对应 `docs/ART_GUIDELINES.md`、`CREW.md`、`GALAXY.md`、`LEVEL_EDITOR.md` 的命中段。

## decision 长期决定与开放问题

首读：`docs/knowledge/INDEX.md` 目标行。必要时：指向的 `docs/DECISIONS.md` 或 `STATUS.md` 单条，核对来源提交和适用范围。

## test 测试选择

首读：`docs/TEST.md` 相关条目。必要时：`../test/README.md` 的精确命令；不默认读测试目录。

## collaboration 协作规范维护

首读：`docs/READ_PROTOCOL.md` 命中节；`.agents/skills/token-opt/SKILL.md`、`ctx-compress/SKILL.md`、`doc-compact/SKILL.md` 中相关一项。核对路由、链接、重复及入口增长。文档改动不跑游戏测试。
