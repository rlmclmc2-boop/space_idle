# Current Status

Goal:
实施获批重构 Phase 1～4，完成后提交 CHECKPOINT 1；Phase 5 必须单独确认。

Done:
- 2026-09-15：Phase 2完成，删除三份旧计时研发测试和无发射方research UI分支；有效覆盖已迁移，科学家63项/拖拽32项通过。保留状态枚举、旧字段及迁移，阶段记录见REFACTOR_PLAN第7节。
- 2026-09-15：Phase 1 行为基线完成，11个隔离专项通过；补有效历史覆盖并修正未安装装备的旧测试夹具，正确规则断言未改。记录与日志入口见 ../REFACTOR_PLAN.md 第7节。
- 2026-09-15：高科技大数预算采用公式批量升级并合并事件；公共大数显示采用科学计数法，修复整数溢出和无穷值循环。近似范围见progression，专项与科学家回归见VALIDATION。
- 2026-09-15：修复充能扣费只在5秒周期存档的问题；资源余额发生扣除后立即保存，保留原有整数分配、credit与进度结算。新增即时存档回归断言。
- 2026-09-15：伤害飘字按实际文字边界避让，向上分行、上方不足向右续列；同帧及连续命中均保留独立数字。隔离专项通过并已验图，见VALIDATION伤害数字避让。
- 2026-09-15：新增科学家批量生成×10/MAX、批量分配+10/MAX与平均分配全部；复用费用舍入和分配保存，研究点保留。38项专项通过，已验图；见VALIDATION科学家批量操作。
- 2026-09-15：武器/防御改为双区卡片，左侧名称等级/属性/状态，右侧费用与升级；冷却条独立到底部，空槽独立安装区，长文省略并支持悬停全文。隔离282项通过，两页满装截图已核查；不改装备规则和数值。
- 2026-09-15：敌舰固定1格，size只选择六档PNG及显示大小；镜像朝左，定位/索敌按单格，血条/编号/发射适配尺寸；编辑器移除size占格警告并允许大于10的正整数。专项检查和截图见VALIDATION。
- 2026-09-15：战舰更换移入独立页签，第二艘战舰解锁前隐藏且仅列出已解锁战舰；目标舰装备在确认换舰前配置，常规装备页仅允许给空槽新增。炮台模块采用独立2.5倍显示缩放，保持舰体占地与炮口规则。新增换舰页签专项通过，视觉截图已核查。
- 2026-09-15：para_6投影、正整数校验及缓存版本更新；武器/防御安装统一限制同种数量，选项标记已达上限并禁用，卸下释放名额。68项专项通过，Excel投影一致；旧档超限不自动拆除，禁止继续增加。
- 2026-09-15：已装备名称改为普通文字，不再显示禁用下拉箭头；空槽选择和卸下确认不变。25项回归通过，截图已核查。
- 2026-09-15：已占用槽禁止直接切换，新增确认卸下与全额升级资源退款；空槽保持空置，重新装备1级，同名实例等级独立。修复装备赋值使用失效数组引用的问题。隔离专项25项通过，确认弹窗及空槽截图已核查。
- 2026-09-15：ship.para_5 接入size与导入校验，更新缓存版本；舰船按占地等比缩放，五舰真实槽位坐标、去透明边距后的模块和炮口统一映射，修正发射粒子起点及震屏偏移。专项167项通过，Excel投影一致，五舰截图已核查，见VALIDATION舰船尺寸与槽位。
- 2026-09-15：接入 ship 分表与 5 艘我方舰船；舰船按解锁关卡开放，武器/防御槽可从已解锁装备自由配置，重复装备按槽位独立升级/冷却。换舰退还升级投入、槽位回到 Lv.1 并从第1关重启，保留通关/高科技/科学家等进度；运行时接入舰船 PNG 与三种槽位武器图标。专项 `test_ships.gd`、装备页和旅行冷却回归通过。
- 2026-09-15：复核发现首版槽位武器图标带有独立圆形底座，与舰船内凹圆槽重复；重新设计为无外环、横向侧视的嵌入式发射器/导弹舱/短炮管，并替换三张图标。透明 alpha、方形画布和三类武器辨识已复核。
- 2026-09-15：为激光、导弹、火炮新增三张圆形槽位武器模块图标，分别使用青色发射器、白红导弹舱、铜箍磁轨炮塔；统一透明方形源图，可按小/中/大型槽位缩放。保留原三张飞行弹体，不改运行时引用或数值。已检查三张图标尺寸与透明 alpha。
- 2026-09-15：复核发现 `enemy-super-8slot.png` 实际仅有 6 个可辨识槽位；重新生成并替换为上 4、下 4 的 8 槽版本，保持透明 PNG、1774×887 画布及敌方配色。已重新检查尺寸与透明 alpha。
- 2026-09-15：按统一侧视与透明 PNG 规范新增 5 种我方舰船（3/4/5/6/8 槽）和 6 种敌方舰船（1/1/2/4/6/8 槽），槽位按小/中/大型统一表现；补充舰船资产 README、美术规范和交接清单。仅新增素材与文档，未接入运行时。透明度、尺寸和槽位数量已自检。
- 2026-09-15：高科技改为科学家生成/分配及研究点升级；费用和收益公式读新config，升级读tpCost，旧并发/计时废弃。按用户确认迁移旧档高科技为0级，其他进度保留；新版分配/点数可持久化。验证见 VALIDATION 科学家研究点制。
- 2026-09-15：升级所需充能次数统一round(para_5×para_6^等级)，配置允许小数基数/成长，实际升级、离线边界与进度条共用整数结果；同步最新charge。成长20项、原充能53项、配置6用例全部通过，见VALIDATION充能升级次数四舍五入。
- 2026-09-15：高科技卡片左下改为研发进度条、百分比及已用/总时长，右侧保留操作按钮；暂停/切换保持进度，自动续研下一等级归零。复用现有进度条结构；专项12项、拖拽回归32项通过，已验图，见VALIDATION高科技研发进度条。
- 2026-09-15：循环替换为驻守：巡航到下一波后停留，清空敌人后按相邻遭遇距离/飞船速度计时原点刷新；跃迁独立进入已通关关卡。死亡设置支持取消、返回原点、退后就地驻守，位置/选择持久化。驻守28项、回退17项、立即过关7项全部通过，编辑器导入退出0，已验图；见VALIDATION驻守与跃迁。
- 2026-09-15：充能每秒消耗改为round(para_2×(1+para_7)^等级)，按用户最新要求四舍五入，扣费与UI共用入口；在线/离线按升级边界切换费率，保留整数分配与断料进度。仅同步最新charge投影；最终成长16项、原充能53项、配置5用例通过，见VALIDATION充能消耗等级成长。
- 2026-09-15：充能卡片改为本次充能/累计升级双进度条，顶部等级与状态、第二行效果，右侧消耗及启停按钮；暂停/断料保留显示进度。53项专项全部通过，已验图，无重叠，见VALIDATION充能进度条卡片。
- 2026-09-15：通关倒计时面板新增“立即过关”，点击跳过等待；与倒计时共用受状态保护的换关入口，保留解锁确认。专项7项全通过、编辑器导入退出0，已检查窗口截图，见VALIDATION立即过关按钮。
- 2026-09-15：AGENTS与UI规范新增“所有游戏页签未解锁前不展示”；武器/防御/高科技/充能统一按首项解锁显示，重新锁定回退到首个可见页。隔离专项14项全通过，已检查充能解锁前后截图，见VALIDATION页签解锁显示规范。
- 2026-09-15：修复两组过期测试：连续研发统一隔离参数、按当前unlock解锁、补收入来源；关卡编辑器显式设置测试公式链并检查公式保留。连续研发20项、编辑器7用例全部通过，U-015已解决；游戏实现和正式配置未改，见VALIDATION过期测试修复。
- 2026-09-15：新增攻击/防御/熔炼器充能页签、配置导入与存档。三项可同时运行、离线继续；整数资源不足先均分，余数按启动先后分配，断料/暂停/重启保留进度。熔炼器仅加成击杀掉落铁，描述按des动态百分比四舍五入。充能48项、配置5用例、增量导入14用例通过，已验图；旧测试配置问题见U-015，证据见VALIDATION充能页签。
- 2026-09-14：接入自动生成资源：按间隔从右侧随机高度生成，按当前关卡资源倍率取整，向左飞行；鼠标划过全额拾取，飞过飞船按自动拾取损耗结算，并补充配置校验与专项测试。
- 2026-09-14：修复少量敌人时导弹齐射视觉重叠：仍按 para1 发射全部导弹，目标不足循环复用，并以小幅上下错位显示；专项目标测试21项通过。
- 2026-09-14：所有 equipment（含装甲）均新增10连升级和MAX升级，沿用逐级成本汇总、资源校验与容量/生命保损逻辑；专项测试更新通过。
- 2026-09-14：QA增加「大重启」，保存后由独立辅助进程等待旧进程退出、资源导入、启动新游戏。真实隔离进程测试确认PID变化、新代码执行、用户目录及进度/QA设置保留；原QA14项回归通过。见 VALIDATION QA大重启。
- 2026-09-14：导弹恢复按 para1 始终发射全部数量，目标不足时循环复用；初始锁定与失锁重选均优先不同目标。目标抗性专项21项全部通过。
- 2026-09-14：武器与护盾新增10连升级和MAX升级；10连按连续10级总成本一次扣费，MAX按当前资源推进至可负担最高等级，装甲保留单次升级。新增批量升级专项9项全部通过；已有装备页签/完整模拟测试受同期显示格式与当前配置影响仍有既有失败。
- 2026-09-14：游戏内所有数值展示统一接入公共 K/M/B/T 格式化脚本，覆盖装备页、顶部生命/护盾、资源、掉落、伤害、费用、研发倒计时和高科技描述；实际数值、计算与存档不变。新增格式化回归断言。
- 2026-09-14：正电子聚焦装置覆盖全部玩家武器，简并态装甲覆盖生命/护盾上限，均改为幂次成长；模板支持幂及整数百分比（用户确认截断）。仅同步 hightech 运行段，保留其他配置与同期修改。46项高科技、20项连续研发、14项配置验证通过，已验图；见 VALIDATION 高科技复利与双防御。
- 2026-09-14：炼铁炉保存一分钟非自身铁收入峰值，收入过期不回落，等级仍参与乘算；兼容旧档。炼铁炉17项、高科技40项、连续研发18项通过，见 VALIDATION 炼铁炉历史峰值。
- 2026-09-14：玩家武器及导弹失锁重选优先不抵抗自身伤害类型的敌人，同组保持原顺序，全抵抗仍攻击；隔离专项20项通过，见 VALIDATION 抗性索敌。
- 2026-09-14：武器卡片右上角新增 CD 秒数，cd > 0 时显示，复用当前等级数据及界面重建；隔离装备页签8项检查通过，已检查三种武器截图，无重叠。证据见 VALIDATION 武器卡片CD。
- 2026-09-14：按用户确认将 mon.equipment 的 | 右值改为数量，导入展开独立条目、敌方固定基础武器行、编辑器按数量提示/校验；转换当前JSON并提升增量缓存版本。数量2用例、战斗193项、编辑器7用例、增量配置14用例全部通过；U-002/U-003已解决，证据见 VALIDATION 武器数量。
- 2026-09-14：只读核对 mon.equipment 导入、enemy_weapon 同级回退、敌方发射与命中减伤路径及当前运行 JSON；|2 按等级解析，缺敌方2级行时采用玩家2级行，每条目每轮一发。规则归 modules/weapons.md、modules/combat.md，既有语义冲突见 U-002/U-003；仅更新状态，未改代码/配置，未运行游戏测试。
- 2026-09-14：BOSS血条由重叠单框改为每实例独立卡片，仅展示当前最终遭遇的存活飞船，不按size/旧boss字段筛选。1–5艘单列、6–10艘双列，编号对应船体，死亡卡片移除且其他位置稳定；暂停提示避让。图形专项17项通过，已检查双船/十船/暂停截图，见 VALIDATION BOSS多船血条。
- 2026-09-14：BOSS战身份改按最后遭遇，全灭才通关；前置大型舰保留外观但不触发通关/发现/清弹。最后一场的小型舰也能通关，关卡信息及跨关后退重放统一按最终敌群；编辑器移除旧BOSS存在/提前通关警告。专项18项、清弹8项、信息8项、循环后退18项及编辑器后端7用例全部通过，见 VALIDATION 最后一场BOSS战。
- 2026-09-14：高科技页签在无已解锁卡片时隐藏，首项解锁后显示且保留当前页；全部重新锁定时从高科技返回武器页。隔离卡槽专项32项全通过，见 VALIDATION 高科技页签显示门槛。
- 2026-09-14：完成独立关卡编辑器及 QA 入口，支持三类配置增删改查/复制、十格编队、遭遇列表、引用保护、草稿校验、公式缓存重算、冲突检测、备份与批量回滚；保存分表并更新运行 JSON/增量指纹。后端6个用例、图形14项、QA回归14项全部通过，已验编队/关卡截图。正式配置与玩家存档未修改；使用说明见 LEVEL_EDITOR，证据见 VALIDATION 关卡编辑器。
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
- Phase 3：合并空槽创建、简化科学家按钮转发；不改旧levels/cooldowns与存档迁移。

Blocked:
- 本次无阻塞；U-015已解决。
- 2026-09-14：Git 首次推送已完成，main 跟踪 origin/main，同步无阻塞。
- 本次无阻塞；其他设计裁决见 TODO P1。

Next:
0. 按Phase 2→3→4验证推进；Phase 4后停止等待确认。以下旧任务记录不扩大本轮授权。
0. QA「大重启」加载大数性能修复，无需清档。
0. QA「大重启」加载伤害数字避让显示。
0. 重启查看科学家批量操作。
0. QA「大重启」加载武器/防御卡片新布局，无需删除存档。
0. QA「大重启」加载敌舰PNG及尺寸调整。
0. QA「大重启」加载同种装备上限；旧档超限装备可通过确认卸下退款。
0. QA「大重启」加载先卸下再装备交互，无需删除存档。
0. QA「大重启」加载舰船占地缩放与槽位修正，无需删除存档。
0. 重启加载科学家系统，旧高科技在读档时自动重置；无需删除整个存档。
0. QA「大重启」加载充能次数四舍五入规则；最新charge已同步。
0. QA「大重启」加载高科技研发进度条，无需重读配置。
0. QA「大重启」加载充能消耗成长；最新charge已同步，无需重读配置。
0. QA「大重启」加载充能双进度条卡片，无需重读配置。
0. QA「大重启」加载统一页签显示规则；充能首项解锁前不展示，无需重读配置。
0. 本次测试修复无待办；后续机制测试使用明确隔离参数，避免绑定不断变化的平衡数值。
0. 使用QA「大重启」或关闭后从启动.cmd启动以加载充能页签；charge已投影，无需用旧总表覆盖分表。
0. 重启游戏验证自动生成资源的右侧生成、飞行、鼠标拾取与飞船自动拾取。
0. 重启游戏查看所有 equipment 卡片的10连/MAX按钮。
0. 当前运行中的旧QA需先手动关闭游戏并从启动.cmd启动一次，随后即可点击「大重启」应用后续代码改动。
0. 重启游戏验证导弹数量不足目标时的齐射与换靶效果。
0. 重启游戏查看武器与护盾卡片的10连/MAX按钮及10级总消耗提示。
0. 重启游戏加载新版高科技效果和描述；运行 hightech 已同步，无需用旧总表覆盖分表。
0. 重启游戏加载抗性索敌规则，无需重新导入配置。
0. 重启游戏查看武器卡片 CD，无需重新导入配置。
0. 重启游戏及关卡编辑器加载武器数量规则；运行JSON已迁移，源表与玩家存档未改。
0. 重启游戏查看BOSS战独立血条；无需重新导入配置。
本次峰值规则已完成，无待办；后续配置流程如下。
0. 重启游戏及已打开的关卡编辑器以加载最后一场BOSS战规则；不需修改配置或存档。编队重叠仍仅警告，见 U-007。
1. 从工作区启动.cmd启动；后续测试只使用test/run.py及test/work，不在根目录生成验证副本。
2. 日常改独立分表后直接读取配置；改总表后先显式同步。首次读取会建立缓存，后续只解析修改过的文件。
3. 优先解决TODO P1原表/实现歧义；P2验证真实数值成长节奏。

Relevant Files:
- REFACTOR_PLAN.md；../test/test_ships.gd；../test/test_scientists.gd；../test/test_furnace_income.gd；../test/test_bulk_upgrades.gd；../test/test_equipment_limits.gd；../test/test_charge.gd；../test/README.md。
- scripts/game.gd；scripts/number_format.gd；../test/test_large_numbers.gd；docs/modules/progression.md；docs/VALIDATION.md
- scripts/main.gd；../test/test_damage_text.gd；docs/modules/ui.md；docs/VALIDATION.md
- scripts/main.gd；../test/test_equipment_tabs.gd；docs/modules/ui.md；docs/VALIDATION.md（装备卡片重排）
- scripts/main.gd；scripts/game.gd；assets/ships/enemy/；../test/test_enemy_ship_visuals.gd；docs/modules/ships.md
- tools/import_workbook.py；tools/config_workbooks.py；data/game_data.json；scripts/game.gd；scripts/main.gd；../test/test_ship_equipment_limit.gd；docs/modules/ships.md
- scripts/game.gd；scripts/main.gd；../test/test_unequip.gd；docs/modules/progression.md；docs/modules/ui.md；docs/VALIDATION.md
- scripts/ship_visuals.gd；scripts/game.gd；scripts/main.gd；tools/import_workbook.py；tools/config_workbooks.py；data/game_data.json；../test/test_ship_visuals.gd；docs/modules/ships.md
- scripts/game.gd；scripts/main.gd；scripts/database.gd；tools/import_workbook.py；tools/config_workbooks.py；config_excel/ship.xlsx；data/game_data.json；../test/test_ships.gd；docs/DATA.md；docs/modules/ships.md；docs/modules/progression.md；docs/modules/ui.md
- assets/weapons/icons/laser-emitter.png；assets/weapons/icons/missile-pod.png；assets/weapons/icons/cannon-turret.png；assets/weapons/README.md；docs/ART_GUIDELINES.md
- assets/ships/player/*.png；assets/ships/enemy/*.png；assets/ships/README.md；docs/ART_GUIDELINES.md；docs/INVENTORY.md；docs/STATUS.md
- scripts/game.gd；scripts/main.gd；tools/import_workbook.py；data/game_data.json；../test/test_scientists.gd；../test/test_scientist_config.py；../test/test_hightech_slots.gd；docs/modules/progression.md；docs/modules/ui.md
- scripts/game.gd；tools/import_workbook.py；data/game_data.json；../test/test_charge_growth.gd；../test/test_charge.gd；../test/test_charge_config.py；docs/modules/progression.md；docs/DATA.md；docs/VALIDATION.md（充能升级次数四舍五入）
- scripts/game.gd；scripts/main.gd；../test/test_guard.gd；../test/test_loop_retreat.gd；../test/test_skip_clear.gd；docs/modules/map.md；docs/modules/ui.md；docs/VALIDATION.md
- scripts/game.gd；scripts/main.gd；tools/import_workbook.py；data/game_data.json；config_excel/charge.xlsx；../test/test_charge_growth.gd；../test/test_charge.gd；../test/test_charge_config.py；docs/modules/progression.md；docs/modules/ui.md；docs/DATA.md；docs/VALIDATION.md
- scripts/main.gd；../test/test_charge.gd；docs/modules/ui.md；docs/VALIDATION.md（充能进度条卡片）
- scripts/main.gd；scripts/game.gd；../test/test_skip_clear.gd；docs/modules/ui.md；docs/VALIDATION.md
- AGENTS.md；scripts/main.gd；../test/test_tab_unlocks.gd；docs/modules/ui.md；docs/VALIDATION.md
- ../test/test_hightech_continuous.gd；../test/test_level_editor.py；docs/TODO.md；docs/VALIDATION.md
- scripts/game.gd；scripts/main.gd；tools/import_workbook.py；tools/config_workbooks.py；tools/level_editor_store.py；config_excel/charge.xlsx；data/game_data.json；../test/test_charge.gd；../test/test_charge_config.py；../test/test_config_workbooks.py；docs/modules/progression.md；docs/modules/economy.md；docs/modules/ui.md；docs/DATA.md；docs/VALIDATION.md；docs/TODO.md
- scripts/game.gd；scripts/main.gd；tools/import_workbook.py；data/game_data.json；../test/test_auto_gen_resources.gd；docs/modules/economy.md；docs/modules/ui.md；docs/DATA.md
- scripts/config_panel.gd；scripts/restart_host.gd；../test/test_full_restart.py；../test/test_full_restart_driver.gd；docs/modules/ui.md；docs/VALIDATION.md
- scripts/game.gd；../test/test_target_resistance.gd；docs/modules/weapons.md；docs/VALIDATION.md
- scripts/game.gd；scripts/main.gd；../test/test_bulk_upgrades.gd；docs/modules/progression.md；docs/modules/ui.md
- scripts/game.gd；tools/import_workbook.py；data/game_data.json；config_excel/hightech.xlsx；../test/test_hightech.gd；../test/test_hightech_continuous.gd；../test/test_config_workbooks.py；docs/modules/progression.md；docs/modules/ui.md
- scripts/game.gd；../test/test_furnace_income.gd；../test/test_hightech.gd；../test/test_hightech_continuous.gd；docs/modules/progression.md；docs/modules/ui.md；docs/VALIDATION.md
- scripts/game.gd；../test/test_target_resistance.gd；docs/modules/weapons.md；docs/VALIDATION.md（抗性索敌）
- scripts/main.gd；docs/modules/ui.md；../test/test_equipment_tabs.gd；docs/VALIDATION.md（武器卡片CD）
- tools/import_workbook.py；tools/config_workbooks.py；tools/level_editor_store.py；scripts/database.gd；scripts/game.gd；scripts/level_editor.gd；data/game_data.json；../test/test_enemy_weapon_counts.py；../test/test_enemy_weapon_positions.gd；../test/test_game.gd；docs/modules/weapons.md；docs/DATA.md；docs/TODO.md；docs/VALIDATION.md
- tools/import_workbook.py:49；scripts/database.gd:33；scripts/game.gd:496、716；data/game_data.json；docs/modules/weapons.md；docs/modules/combat.md；docs/TODO.md（本次伤害检查）
- scripts/main.gd；../test/test_boss_health_cards.gd；docs/modules/ui.md；docs/VALIDATION.md
- scripts/game.gd；scripts/level_editor.gd；tools/level_editor_store.py；../test/test_final_encounter.gd；../test/test_boss_projectile_clear.gd；../test/test_boss_info.gd；../test/test_level_editor.py；docs/modules/map.md；docs/LEVEL_EDITOR.md
- scripts/main.gd；../test/test_hightech_slots.gd；docs/modules/ui.md；docs/VALIDATION.md
- level_editor.tscn；scripts/level_editor.gd；tools/level_editor_store.py；关卡编辑器.cmd；scripts/config_panel.gd；../test/test_level_editor.py；../test/test_level_editor.gd；docs/LEVEL_EDITOR.md；docs/VALIDATION.md
- scripts/game.gd；tools/import_workbook.py；data/game_data.json；../test/test_furnace_income.gd；../test/test_hightech.gd；../test/test_hightech_continuous.gd；docs/modules/progression.md；docs/modules/ui.md；docs/VALIDATION.md
- scripts/game.gd；scripts/main.gd；tools/import_workbook.py；config_excel/hightech.xlsx；data/game_data.json；../test/test_hightech_continuous.gd；../test/test_hightech.gd；../test/test_config_workbooks.py；docs/modules/progression.md；docs/modules/ui.md；docs/DATA.md；docs/VALIDATION.md
- scripts/hightech_slot.gd；scripts/main.gd；scripts/game.gd；../test/test_hightech_slots.gd；docs/modules/ui.md；docs/VALIDATION.md
- scripts/game.gd；scripts/main.gd；scripts/number_format.gd；tools/import_workbook.py；data/game_data.json；../test/test_hightech.gd；../test/test_config_workbooks.py；../test/test_resource_display.gd；docs/modules/progression.md；docs/modules/ui.md；docs/DATA.md；docs/VALIDATION.md
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
