# Project

- **CONFIRMED · 策划**：太空战舰，横版、即时、自动攻击的科幻飞行器游戏。来源：`../太空战舰.xlsx` 总览!A3:A10。
- **核心体验/目标**：推进、遭遇敌群、停船自动战斗、击落敌机；击败关底 BOSS 通关。循环规则归 [map](modules/map.md)。
- **DERIVED · 核心循环**：前进 → 战斗 → 拾取资源 → 装备升级 → 通关解锁/重复关卡，由总览!A4:A10、A28:A30 串联；不是新增规则。
- **CONFIRMED · 当前技术**：Godot 原生 GDScript；`project.godot` 声明版本 0.2.0、GL Compatibility，1440×810 逻辑视口；本地引擎版本经测试见 [VALIDATION](VALIDATION.md)。Python/openpyxl/lxml 用于配置拆分、导入和资料检查，游戏读取 JSON。
- **CONFIRMED · 平台范围**：已有 Windows `.cmd` 启动与 QA；其他发布平台状态见 TODO U-010。
- **系统地图**：[GAME_DESIGN](GAME_DESIGN.md)。**目录**：[INVENTORY](INVENTORY.md)。**实现**：[ARCHITECTURE](ARCHITECTURE.md)。进度只看 [STATUS](STATUS.md)。

术语：`armour`=玩家生命/装甲；`shield`=先于装甲吸收伤害的护盾；equipment 的 `level`=装备等级，level 表的 `id`=关卡编号；`mon`=敌机定义，`monGroup`=十格编队；`para*` 随装备类型解释，见 [DATA](DATA.md)。
