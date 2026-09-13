# Current Status

Goal:
完成炼铁炉60秒基数排除自身收益，并同步最新 description；保留顶部总收入与既有研发行为。

Done:
- 2026-09-14：炼铁炉生成与预计产量均排除自身入账，来源随样本保存；顶部每秒/总收入仍包含全部实际拾取。接入 description 的“不含自身”修饰并同步最新高科技表（含 para2=0.25）。专项12项、高科技40项、连续研发18项、配置14项全部通过；见 VALIDATION 炼铁炉排除自身收益与描述同步。
- 2026-09-14：高科技界面改读 description，paraN 与花括号四则表达式动态替换，支持当前等级/一分钟铁量及向上取整。完成后自动研发下一级，切换保留暂停项进度，在线/离线仅推进活动项；已兼容原存档及并发配置。连续专项18项、配置14项、高科技40项、卡槽29项通过，已检查截图；见 VALIDATION 高科技动态描述与连续研发。
- 2026-09-14：高科技隐藏未解锁项，预留6个固定槽并按整页扩展；拖标题到卡片交换、拖到空槽移入、区域外取消，支持预览/高亮和边缘滚动。顺序及空位自动保存，新解锁填空位；重建保留页签/滚动且不打断拖拽。卡槽29项与原高科技40项全部通过，已检查三张截图；见 VALIDATION 高科技卡槽换位。
- 2026-09-14：新增“高科技”页签，描述来自 hightech.des；接入三项效果、0级无上限研发、hightechLimit 并发限制、暂停/倍速及按 offlineMax（小时）限制的离线1倍推进。炼铁炉复用每秒统计原始值×60、点击领取/10秒消失；简并态装甲只增上限不补当前装甲。高科技40项、配置12项、资源显示9项、装备页签8项均通过，已验图并更新规则；见 VALIDATION 高科技。
- 2026-09-14：离线收益自动入账并保存，复用一分钟实际收入统计及现有原子存档；上限读取表中 offlineMax（小时），旧档无记录不补发。离线11项、配置7项、资源显示9项全部通过，编辑器扫描通过；见 VALIDATION 离线资源收益。
- 2026-09-14：BOSS死亡立即清空敌我在途弹体并停止当轮旧快照结算，普通敌舰死亡保持原行为。隔离专项8项通过，已检查死亡前后截图，确认弹体消失、通关解锁正常；下一关推进验证通过，见 VALIDATION BOSS死亡清弹。
- 2026-09-14：补完重复武器视觉验收，逐张检查三种武器起点/飞行共六张真实截图，覆盖普通舰与BOSS的2/3/6个同名武器；上下展开可辨，舰缘偏移符合用户要求，无需追加游戏代码修改。截图脚本与证据见 VALIDATION 重复武器发射位置。
- 2026-09-14：按用户纠正，change_state(TRAVEL) 将剩余冷却设为当前武器完整CD（发射进度归零），前进不倒计时，下次遭遇等待完整间隔。替代先前立即开火实现；专项22项通过，见 VALIDATION 前进重置冷却。
- 2026-09-14：同船同名武器按 equipment 顺序沿舰体上下对称等距发射，普通舰/BOSS按显示尺寸展开，单个武器保持原位；复用 fire，不改数量、冷却和伤害。隔离专项185项通过，编辑器导入退出0，见 VALIDATION 重复武器发射位置。
- 2026-09-14：下方新增“武器 / 防御”页签，首屏为武器；三种攻击装备使用34×20图标及216×112卡片，装甲/护盾保留在防御页。分类集中于 EQUIPMENT_PAGES，横向滚动支持后续扩展；升级/界面重建保留所选页签。隔离图形专项8项通过，已检查两页截图，见 VALIDATION 装备页签。
- 2026-09-14：修复资源显示测试副本的权限继承（125项成功、0失败）；运行器新建Windows副本后自动启用继承。截图工具已能读取原截图并确认顶部“铝”；新目录继承探针与Python语法检查通过。
- 2026-09-14：顶部两种资源名称改读 db.data.resources，去掉固定中英文名；当前运行配置为铁/铝。隔离资源显示9项通过，扫描退出0；见 VALIDATION 资源名称同步。
- 2026-09-14：主目录可见文件仅保留太空战舰.xlsx与启动.cmd；引擎迁至项目engine，旧测试源码迁至test，产物统一test/work。清理13个旧验证副本、历史截图、审计JSON及旧测试缓存，保留独立探针与正式存档。分表8项、导入检查、QA14项及无缓存根入口启动通过，见VALIDATION目录整理验证。
- 2026-09-14：QA 新增“删除存档”，删除 progress.json 后禁止旧场景回写并重载，恢复配置初始进度；QA 设置保留，删除失败显示错误且不重载。隔离图形专项7项通过并检查按钮布局，未删除正式存档。
- 2026-09-14：弹体显示统一缩至原宽高65%，通过 PROJECTILE_SCALE 集中控制并保留各武器基准尺寸及原始素材。复用隔离有图形绘制检查退出0，已检查缩小后截图，无脚本错误。
- 2026-09-14：修复新武器 PNG 未导入导致 main.gd 预加载失败的黑屏；../启动.cmd 自动等待无界面资源导入后启动。无缓存隔离副本通过真实 CMD 启动并截取正常战斗画面；正式项目资源缓存已补齐，未改运行配置或玩家存档。
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
- 2026-09-14：Git 首次推送已完成，main 跟踪 origin/main，同步无阻塞。
- 本次无阻塞；其他设计裁决见 TODO P1。

Next:
0. 重启后使用最新 description 及排除自身的炼铁基数；旧档来源不明样本保留总收入显示，但不参与炉子计算，最多60秒自然过期。本次无待确认规则。
1. 从工作区启动.cmd启动；后续测试只使用test/run.py及test/work，不在根目录生成验证副本。
2. 日常改独立分表后直接读取配置；改总表后先显式同步。首次读取会建立缓存，后续只解析修改过的文件。
3. 优先解决TODO P1原表/实现歧义；P2验证真实数值成长节奏。

Relevant Files:
- scripts/game.gd；tools/import_workbook.py；data/game_data.json；../test/test_furnace_income.gd；../test/test_hightech.gd；../test/test_hightech_continuous.gd；docs/modules/progression.md；docs/modules/ui.md；docs/VALIDATION.md
- scripts/game.gd；scripts/main.gd；tools/import_workbook.py；config_excel/hightech.xlsx；data/game_data.json；../test/test_hightech_continuous.gd；../test/test_hightech.gd；../test/test_config_workbooks.py；docs/modules/progression.md；docs/modules/ui.md；docs/DATA.md；docs/VALIDATION.md
- scripts/hightech_slot.gd；scripts/main.gd；scripts/game.gd；../test/test_hightech_slots.gd；docs/modules/ui.md；docs/VALIDATION.md
- scripts/game.gd；scripts/main.gd；tools/import_workbook.py；data/game_data.json；../test/test_hightech.gd；../test/test_config_workbooks.py；../test/test_resource_display.gd；docs/modules/progression.md；docs/modules/ui.md；docs/DATA.md；docs/VALIDATION.md
- scripts/game.gd；scripts/main.gd；data/game_data.json；tools/import_workbook.py；../test/test_offline_resources.gd；../test/test_offline_config.py；docs/modules/economy.md；docs/DATA.md
- scripts/game.gd；../test/test_boss_projectile_clear.gd；../test/test_game.gd；docs/modules/weapons.md；docs/VALIDATION.md
- ../test/capture_enemy_weapon_positions.gd；docs/VALIDATION.md（重复武器发射位置视觉证据）
- scripts/game.gd；../test/test_travel_cooldowns.gd；docs/modules/weapons.md；docs/VALIDATION.md
- scripts/game.gd；../test/test_enemy_weapon_positions.gd；docs/modules/weapons.md；docs/VALIDATION.md
- scripts/main.gd；../test/test_equipment_tabs.gd；docs/modules/ui.md；docs/VALIDATION.md
- ../启动.cmd；../test/；AGENTS.md；打开编辑器.cmd；docs/INVENTORY.md；docs/VALIDATION.md；tools/inspect_knowledge.py
- scripts/config_panel.gd；../test/test_delete_save.gd；docs/modules/ui.md；docs/VALIDATION.md
- ../启动.cmd；docs/modules/ui.md；docs/VALIDATION.md
- ../.gitignore；docs/INVENTORY.md；docs/STATUS.md
- scripts/config_panel.gd；tools/config_workbooks.py；tools/import_workbook.py；config_excel/；../test/test_config_workbooks.py；../test/test_config_panel.gd；../test/test_import.py；docs/DATA.md；docs/modules/ui.md
- assets/weapons/；scripts/main.gd；docs/modules/ui.md；docs/VALIDATION.md
- scripts/main.gd；../test/test_resource_display.gd；docs/modules/ui.md；docs/VALIDATION.md；docs/STATUS.md
- scripts/game.gd；scripts/main.gd；../test/test_boss_info.gd；docs/modules/ui.md；docs/VALIDATION.md；docs/STATUS.md
- ../test/test_game.gd；docs/modules/ships.md；docs/TODO.md；docs/VALIDATION.md；docs/STATUS.md
- ../test/test_loop_retreat.gd；scripts/game.gd；scripts/main.gd；docs/modules/map.md；docs/modules/ui.md；docs/TODO.md；docs/VALIDATION.md
- scripts/main.gd；docs/modules/weapons.md；docs/modules/combat.md
- docs/modules/economy.md；docs/modules/progression.md
- scripts/game.gd；tools/import_workbook.py；data/game_data.json；../test/test_game.gd；docs/DATA.md；docs/modules/map.md；docs/TODO.md；docs/VALIDATION.md
