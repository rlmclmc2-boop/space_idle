# Current Status

Goal:
增加 QA 总表拆分/同步按钮与独立分表增量导入；保留已有玩法、美术和存档修改。

Done:
- 2026-09-14：工作区根接入 Git 与 SourceTree（本地条目“放置”），配置 GitHub origin；原始总表和游戏项目共同版本管理，忽略引擎、验证副本、缓存和玩家存档。
- 2026-09-14：完成所选总表（除总览）到 config_excel 的独立 XLSX 同步，新增同名更新/目录入口；保留单元格公式、缓存与格式。读取改为 SHA-256 变更检测，只解析变化分表、合并验证并原子提交 JSON/缓存；无变化不读取工作表/不改写 JSON，失败不标记已读。指定总表六份分表已生成；运行 JSON 与玩家存档未因本次测试改写。8项 Python 用例、14项隔离图形QA断言、全表CLI兼容测试通过，见 VALIDATION 分表增量配置。
- 2026-09-14：新增三张透明武器PNG，激光为青色光束、火炮为铜箍金属弹丸、导弹为白身红头尾翼与蓝紫推进焰；按武器键匹配敌我弹体并按保存方向旋转。隔离编辑器扫描及有图形专项绘制退出0，已检查三种武器双向/失锁截图；见 VALIDATION 武器美术。
- 2026-09-14：普通敌舰与BOSS的当前/最大生命统一截断至前两位有效数字，并使用K/M/B/T缩写；普通敌舰文字放在舰体右侧。实际生命和血条比例不变。隔离13组格式检查全通过、编辑器扫描退出0，已核查两类敌人截图；见 VALIDATION 敌人生命显示。
- 2026-09-14：资源栏新增总量/每秒切换，复用实际拾取事件统计现实时间60秒收入，默认总量。专项9项全通过、编辑器扫描退出0，已检查收益模式窗口截图，见 VALIDATION 资源收益切换。
- 2026-09-14：关卡旁显示已遭遇 BOSS 的现有描述，未遭遇显示“？？？”；遭遇即保存，死亡/重刷/重启保留，旧存档已通关关卡兼容。专项8项全通过、编辑器扫描退出0，已检查已知/未知两种窗口截图，见 VALIDATION 关卡旁 BOSS 信息。
- 2026-09-13：U-014 已解决，原测试硬编码旧护盾等待/恢复比例；改为按当前配置验证，隔离敌群干扰并补受击重置等待与恢复上限断言。游戏逻辑和数值未改。隔离有图形完整模拟103项全通过，编辑器扫描退出0，详见 VALIDATION 护盾回归修复。
- 2026-09-13：增加已通关循环关卡选择，开启立即进入指定关卡并持续重刷，目标保存且不受死亡退关影响；死亡跨关以上一关长度减剩余距离计算，第一关起点截断。用户确认落在上一关BOSS后方时在落点重放BOSS。隔离有图形18项回归全通过、编辑器扫描退出0，并检查窗口截图；详见 VALIDATION 指定循环关卡与跨关死亡回退。
- 2026-09-13：按最新指令在掉落计算完成后取整，自动拾取基于该整数独立取整；标签直接显示 amount，提示和入账复用同一结算量。更新3项相关回归，隔离运行3项全通过，编辑器扫描退出0，见 VALIDATION 自动拾取独立取整验证；替代此前合并取整规则。
- 2026-09-13：修正 main.gd 掉落标签直接显示中间小数的问题，仅在格式化时向上取整。隔离编辑器扫描退出0，无脚本解析错误；未重跑无关模拟，记录见 VALIDATION 掉落显示验证。
- 已更新 AGENTS 的最小测试规则；本次仅核对文档改动，未运行游戏测试。
- 2026-09-13：统一弹体更新供战斗/巡航/通关/后退复用，解除无效锁定后直线飞行，波次及BOSS死亡不清弹体；绘制使用保存方向。隔离有图形测试100项、99通过，本次弹体回归全部通过；仅既有 U-014 失败。
- 2026-09-13：拾取、起始资源、旧存档余额及最终升级成本统一向上取整；新增7项资源回归并更新旧期望。隔离模拟86项、85通过，资源检查全部通过；既有护盾失败见 U-014，证据见 VALIDATION 资源取整验证。
- 2026-09-13：核对 config!A8:C8，复用导入器仅新增运行 config.backRange；后退逻辑改读该字段，加入非负校验及非默认/零距离回归。导入测试通过，模拟79项中新增回归通过、1项失败见 U-014。
- 已建立入口、文件/规则/数据/实现地图及7个实际系统模块；未知与路线集中在TODO。
- 原表/JSON一致；257公式缓存核对、导入测试、71项游戏与11项QA集成通过；证据见VALIDATION。
- 2026-09-13：复用弹体清理与导弹换靶实现，更新武器模块及 U-006；新增6项回归，隔离副本运行77项检查、0失败，编辑器扫描及测试退出0。记录见VALIDATION本次武器验证。

In Progress:
- 无，本次修改与验证已完成。

Blocked:
- Git 首次远程推送被自动审批拦截，待用户确认上传源码、文档、美术与 Excel 至指定 GitHub 仓库。
- 本次无阻塞；其他设计裁决见 TODO P1。

Next:
1. 日常改独立分表后直接读取配置；改总表后先显式同步。首次读取会建立缓存，后续只解析修改过的文件。
2. 优先解决TODO P1原表/实现歧义；P2验证真实数值成长节奏。

Relevant Files:
- ../.gitignore；docs/INVENTORY.md；docs/STATUS.md
- scripts/config_panel.gd；tools/config_workbooks.py；tools/import_workbook.py；config_excel/；tests/test_config_workbooks.py；tests/test_config_panel.gd；tests/test_import.py；docs/DATA.md；docs/modules/ui.md
- assets/weapons/；scripts/main.gd；docs/modules/ui.md；docs/VALIDATION.md
- scripts/main.gd；tests/test_resource_display.gd；docs/modules/ui.md；docs/VALIDATION.md；docs/STATUS.md
- scripts/game.gd；scripts/main.gd；tests/test_boss_info.gd；docs/modules/ui.md；docs/VALIDATION.md；docs/STATUS.md
- tests/test_game.gd；docs/modules/ships.md；docs/TODO.md；docs/VALIDATION.md；docs/STATUS.md
- tests/test_loop_retreat.gd；scripts/game.gd；scripts/main.gd；docs/modules/map.md；docs/modules/ui.md；docs/TODO.md；docs/VALIDATION.md
- scripts/main.gd；docs/modules/weapons.md；docs/modules/combat.md
- docs/modules/economy.md；docs/modules/progression.md
- scripts/game.gd；tools/import_workbook.py；data/game_data.json；tests/test_game.gd；docs/DATA.md；docs/modules/map.md；docs/TODO.md；docs/VALIDATION.md
