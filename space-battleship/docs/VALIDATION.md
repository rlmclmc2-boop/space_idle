# 验证与证据

## 2026-09-15 Phase 6～7

- `test_level_editor.gd`修改前后18项通过，含环境指定/无效指定/空指定/内置缺失四种Python定位分支，以及独立编辑器读取、草稿校验、保存、重载及引用删除保护。
- `test_config_panel.gd`当前分表夹具14项通过，覆盖导入/无变化不写JSON、暂停/速度、同进程重启、QA窗口身份与偏好保留。旧总表夹具失败定位见TODO U-018；未修改生产校验。
- `test_full_restart.py`通过：busy guard、新PID、新源码、同一隔离用户目录、存档进度与QA设置。所有运行均经test/run.py创建无缓存隔离副本；未执行正式启动脚本或读取正式存档。三份.cmd已静态核对目标/参数/路径，未宣称逐一执行脚本。
- 日志与CHECKPOINT 3见[REFACTOR_PLAN第9节](../REFACTOR_PLAN.md)。12份正式配置输入哈希未变，tools/data/config_excel及game/main无diff。仅既有根证书提示，无未解决专项失败。

## 2026-09-15 Phase 5

- 全部经`test/run.py`隔离项目与用户目录；最终结果、失败定位与日志清单统一见 [REFACTOR_PLAN第8节](../REFACTOR_PLAN.md)。正式玩家存档未读写，version仍为1，12份正式配置输入哈希不变。
- `test_state_ownership.gd`：1114项、0失败，其中539次读取前后完整profile/cooldowns/player深比较及539次槽位数组身份检查；7种状态包含新档、同名不同等级、首槽卸下、重载、空槽旧档、残留旧字段及收入描述。无缓存写入豁免。
- `test_unequip.gd`：27项、0失败，新增同名不同等级的按钮资格/槽位绑定。装备页282、批量70、上限28、数量限制68、换舰页8、前进冷却22、索敌21、充能57/成长20、科技排序32、科学家63、炼铁炉23、离线11、删除存档7及舰船专项均通过。
- 护盾恢复（延迟/受击重置/倍率/上限）、容量保损与退款守恒已纳入状态专项；不依赖历史test_game的旧安装假设，见TODO U-017。UI满装截图已核查。

## 2026-09-15 大数性能

- `python test/run.py test_large_numbers.gd` 隔离导入/执行退出0，11项全部通过：1e20/1e30研究点批量结算、非负余量、常量费用、整数安全边界、科学计数法、无穷值终止和小数值显示兼容。最终产物 `../../test/work/test_large_numbers-s18tguf8/`，1e20预算约百亿级升级单次耗时40微秒（专项测量，非整帧基准）。
- `python test/run.py test_scientists.gd` 38项全部通过，产物 `../../test/work/test_scientists-o7xdptzn/`；验证原低数值研究及批量生成/分配流程。仅既有Windows根证书提示，无脚本错误；未操作正式配置或玩家存档。相关diff空白检查通过。大数近似行为归progression模块。

## 2026-09-15 伤害数字避让

- `python test/run.py test_damage_text.gd` 隔离导入及图形执行退出0；验证敌我同帧24次伤害全部保留、两两边界不重叠，上浮后追加6次相邻命中仍不重叠，清空后原位置复用。已检查 `../../test/work/test_damage_text-8vtc14wz/space-battleship/damage-text.png`，分行/分列数字清晰。仅既有根证书提示，无脚本错误；未操作正式存档。

## 2026-09-15 科学家批量操作

- `test/run.py test_scientists.gd` 在 `../../test/work/test_scientists-4w9itbu8/` 38项全部通过，导入与图形执行退出0。新增逐个费用与×10总扣费等价、MAX资源边界、失败原子性、分配不足十人、全部重均分/余数/点数保留，以及真实×10生成、×10/MAX分配按钮验证。原零级效果断言改用equipment_stat隔离同期多槽装备影响。
- 已查看批量操作截图：管理卡生成×1/×10/MAX和平均分配全部、各卡片+10/MAX与+1/−1无重叠，研究点条正常。仅既有根证书提示；未修改正式配置或玩家存档。

## 2026-09-15 武器/防御卡片重排

- `python test/run.py test_equipment_tabs.gd`：282项通过、0失败；覆盖升级/切页保持、空槽安装三类装备，以及满装两页所有可见卡片子控件边界与两两不重叠检查。产物 `../../test/work/test_equipment_tabs-u8hmckx_/`，已核查 `tabs-filled-0.png` 与 `tabs-filled-1.png`；空槽边界检查另在 `test_equipment_tabs-mizjfqdv` 156项通过。Godot隔离副本运行，未操作正式存档，仅既有根证书警告。

## 2026-09-15 敌舰图片与单格编队

- `test_enemy_ship_visuals.gd`：24项通过；六档素材截图及十艘size=100同屏截图，验证尺寸对应舰缘发射、十格独立定位和中央索敌。产物 `../../test/work/test_enemy_ship_visuals-pbq0u_hg/`，Godot 4.7.2隔离执行，无正式存档操作。
- `test_level_editor.py`：8项通过，产物 `../../test/work/test_level_editor-n0izhj1b/`；包括size=100十舰编队校验。系统Python缺lxml，改用已带依赖的桌面内置Python运行通过。

## 2026-09-15 战舰更换页签

- `python test/run.py test_ship_tab.gd`：8项通过，退出0；覆盖第二艘战舰解锁前隐藏、仅列出已解锁战舰、换舰页签内配置装备、确认前不切换及确认后提交目标配置。已查看 `test/work/test_ship_tab-jc11ds1y/space-battleship/ship-tab.png`，槽位卡片与确认按钮无重叠。
- 直接影响回归：`test_equipment_tabs.gd` 9项通过、`test_tab_unlocks.gd` 14项通过、`test_unequip.gd` 25项通过；`test_ship_visuals.gd` 167项通过，炮口坐标保持一致且炮台显示缩放调整生效。Godot 4.7.2 仅有既有系统根证书提示，无脚本错误。

## 2026-09-15 同种装备上限

- 隔离 `test_ship_equipment_limit.gd` 68项通过，退出0；覆盖五舰武器/防御限额、拒绝超限不扣资源、卸下释放名额及重新安装1级。产物位于test/work/test_ship_equipment_limit-uh2t2__k；无脚本错误。
- ship分表经read_rows/convert_sheet与JSON.ship完全一致，validate_projection通过。未操作正式存档。

## 2026-09-15 移除已装备下拉箭头

- 隔离运行 `test_unequip.gd`：25项通过，退出0；已核查 `test/work/test_unequip-pktf_4v9/space-battleship/unequip-confirm.png`，占用槽显示普通名称无箭头，空槽仍保留下拉入口。

## 2026-09-15 确认卸下装备

- `python test/run.py test_unequip.gd`：隔离导入及运行退出0，25项检查、0失败。覆盖禁止直接替换、弹窗取消/确认、各资源全额退款、重复退款保护、同名实例等级隔离、重新安装1级、两类防御退款与空槽不自动补装。
- `test/work/test_unequip-ncehi7p4/space-battleship/unequip-confirm.png`、`unequip-empty.png` 已核查；正式存档未操作。引擎证书库和QA子窗口嵌入警告不影响测试，无脚本错误。

## 2026-09-15 舰船尺寸与槽位

- `python test/run.py test_ship_visuals.gd`：隔离导入及运行退出0，167项检查、0失败；覆盖五舰占地比例、槽位数、各槽三种武器弹体起点与fire事件坐标，以及动态size缩放。
- 使用read_rows/convert_sheet读取ship分表，与运行JSON.ship逐项相等；validate_projection通过。
- `test/work/test_ship_visuals-bstcb_7j/space-battleship/visual-*.png` 五舰截图已核查，舰体按占地缩放、模块不遮槽环。正式存档未读写。引擎有系统证书库警告，无脚本错误。

## 2026-09-15 科学家研究点制

- `test/run.py test_scientists.gd`：28项全部通过，`../../test/work/test_scientists-7qfn_kf_/`。覆盖0级无效果、未解锁禁用、逐人复利费用/四舍五入、多资源扣费、余额不足、分配守恒、多人指数速率、并行研究/升级剩余点、撤回保留、暂停、真实存档往返、离线推进、旧档废弃和真实生成/分配/撤回按钮。
- `test_scientist_config.py`：6用例通过，`../../test/work/test_scientist_config-_2fzuvee/`；验证实际分表投影一致、小数hightechLimit、多资源扩展、非法费用/点数拒绝与timeCost不再使用。仅同步config/hightech运行段，未改Excel或正式存档。
- `test_hightech_slots.gd`：32项通过，`../../test/work/test_hightech_slots-2y2d4mlj/`；真实拖放、空槽、边缘滚动、页签隐藏及存档顺序保留。管理卡增加后专项按新位置滚动，研发归属断言改为科学家分配。
- 已检查 scientists.png：管理卡费用、空闲人数、卡片人数/点速率/点数/百分比及+1/−1可读，0级显示未研发无效果。Godot 4.7.2 导入及图形执行退出0，仅既有根证书提示。旧计时专项已在test/README说明废弃范围，新验收入口如上。

## 2026-09-15 充能升级次数四舍五入

- charge_required统一返回round(para_5×para_6^等级)，供升级、离线边界、存档校验和进度条使用。配置允许小数参数，保留正次数检查；只同步最新charge投影（当前para_6=1.3），其他运行段不变。
- 隔离 `test/run.py`：成长20项通过（`../../test/work/test_charge_growth-qz8zpg7n/`），新增1.5→2、2.25→2、无小数次数残留、跨级扣费边界及基础次数舍入；原充能53项通过（`../../test/work/test_charge-rscuqbf1/`），固定次数参数夹具避免平衡修改影响机制测试；配置6用例通过（`../../test/work/test_charge_config-7cr3a87e/`），验证小数参数可导入及非法范围拒绝。
- Godot导入/运行退出0，仅既有根证书提示。未修改源表或正式玩家存档。

## 2026-09-15 高科技研发进度条

- `test/run.py test_hightech_progress.gd` 在 `../../test/work/test_hightech_progress-85jf83c2/` 12项通过：未开始空条、半程比例/百分比、切换保留与颜色、续研下一等级归零、暂停保留、重建保留页签及各卡片条/按钮边界。编辑器导入、有图形执行退出0；已查看 hightech-progress.png，描述、进度文字/条和右侧按钮无重叠。
- 拖拽直接影响回归 `test_hightech_slots.gd` 在 `../../test/work/test_hightech_slots-hypa6tid/` 32项全通过，覆盖按钮落点、换位/空槽、扩展、存档和页签解锁；按钮落点改为实际按钮中心。测试解锁条件改读当前配置，替代已过期的固定关卡夹具；首轮专项因旧夹具无法解锁而停止，修正后以上最终运行通过。
- 最终日志无脚本错误，仅既有根证书提示。本次只改UI显示及相关测试，未改研发计算、Excel、运行JSON或正式存档，未跑无关玩法测试。

## 2026-09-15 充能消耗等级成长

- 只读核对charge!A1:K6：三项para_7均为0.05，基础para_2已由用户改为1；以当前分表仅同步charge运行投影，断言其他段不变。用户最新补充完整公式结果四舍五入，替代先前向上取整。
- `test/run.py test_charge_growth.gd`：最终16项通过，覆盖0级基础、升级即刻变价、长步跨级、800小步与长步结算一致、断料恢复、幂次后四舍五入、半整数向上舍入、0费率、旧配置兼容、credit跨级、实际离线加载与上限、卡片费率。证据：`../../test/work/test_charge_growth-_s9i95vz/`。
- `test/run.py test_charge.gd`：53项通过（`../../test/work/test_charge-438fqvk8/`），旧机制测试明确固定基础5与para_7=0，避免绑定用户平衡调整。`test_charge_config.py`：5用例通过（`../../test/work/test_charge_config-dy00_9qx/`），包含para_7负值/空值/无穷拒绝和源表投影一致。
- Godot导入/运行退出0，仅既有根证书提示。正式源表与玩家存档未修改，未运行无关测试。

## 2026-09-15 充能进度条卡片

- `test/run.py test_charge.gd`：53项全部通过，Godot导入/运行退出0；新增本次与累计进度条比例、暂停保留、资源补充状态恢复及固定条高检查，原充能逻辑回归仍通过。
- 已检查 `../../test/work/test_charge-p0897q_o/space-battleship/charge.png`，三卡片的双进度条、标题、效果、状态、消耗及按钮无重叠。首次原生ProgressBar最小高度导致重叠，已改为复用现有冷却条的ColorRect结构，最终固定6像素。仅既有根证书提示；未改配置、充能计算或正式存档。

## 2026-09-15 页签解锁显示规范

- `test/run.py test_tab_unlocks.gd`：隔离图形专项14项全部通过，Godot导入/运行退出0。覆盖武器、防御、高科技、充能四页的解锁门槛、首项解锁显示、原选择保留、重新锁定回退及全部锁定时无选中页。配置门槛只在测试内存设置。
- 证据：`../../test/work/test_tab_unlocks-ez5_pg6s/`。已检查 `space-battleship/tabs-before-unlock.png` 和 `tabs-charge-unlocked.png`，确认解锁前无充能入口，解锁后可正常展示三卡片。仅既有根证书提示，未改正式配置/存档。

## 2026-09-15 过期测试修复

- 保留两组有效回归。`test_hightech_continuous.gd` 增加统一的内存机制夹具，明确研发耗时/成长/并发/离线上限、效果参数及描述；按当前配置unlock解锁，收入样本标注origin=drop。在线、重载、UI使用相同前提，继续验证暂停、切换、跨级、离线与描述。
- `test_level_editor.py` 在隔离编辑请求中显式设置 `=D4` 和 `=ROUND(D4*1.17,2)` 测试公式链，保留2.34的独立期望，并断言保存后公式原文仍在；不再以正式配置的成长倍率作为该机制测试前提。
- bundled Python、`PYTHONIOENCODING=utf-8`，通过 `test/run.py` 隔离执行：连续研发20项全过（`../../test/work/test_hightech_continuous-m395e3w3/`）；编辑器7用例全过（`../../test/work/test_level_editor-0xj8c4_9/`）。Godot导入/执行退出0，仅既有根证书提示。未改游戏实现、正式Excel、运行JSON或玩家存档；U-015已解决。

## 2026-09-15 充能页签

- 只读重新核对用户修正后的 `config_excel/charge.xlsx` · charge!A1:J6，以 func 实现三种效果、des 构建描述；运行JSON仅新增charge及其source_files路径，保留其他现有修改，未写源表或正式玩家存档。
- bundled Python执行 `test/run.py test_charge.gd`：48项、0失败，Godot4.7.2导入/运行退出0。覆盖解锁、同时启动、整数扣费、均分及启动顺序余数、断料冻结/补充继续、跨级累计、暂停、保存恢复、旧档、离线扣费/上限、攻击与高科技叠加、双防御、仅击杀铁加成、描述安全解析与百分比舍入、实际卡片按钮和页签保留。小步长100帧确认没有逐帧额外扣费。
- 证据：`../../test/work/test_charge-n2vt75kf/` 的import.log/test.log及 `space-battleship/charge.png`。已检查三卡片截图，标题、动态描述、进度、消耗、等待按钮无重叠。Godot仅有既有根证书提示。
- `test/run.py test_charge_config.py`：5用例通过（`../../test/work/test_charge_config-7mhiznln/`），验证源表投影、参数/表达式拒绝、失败保留JSON、无变化不解析、关卡编辑器发现并保留charge配置。
- `test/run.py test_config_workbooks.py`：14用例通过（`../../test/work/test_config_workbooks-atng1xew/`）；测试断言适配旧总表没有可选charge的情形。Windows运行命令设置 `PYTHONIOENCODING=utf-8`，避免旧控制台打印中文异常。
- 两个旧回归的配置前提问题见 TODO U-015：连续研发测试在缺研发项处中止；关卡编辑器7用例中6通过、1个旧数值期望失败。本次共享描述逻辑及charge编辑器集成已分别通过上述专项，没有改无关配置或旧测试期望。

## 2026-09-14 自动生成资源

- 只读核对 `config_excel/config.xlsx!A11:C11` 得到 `autoGenRes=10,2,10,40`；使用 bundled Python 执行增量配置导入，确认仅更新 config 投影并成功写入 `data/game_data.json`。
- `python test/run.py test_auto_gen_resources.gd`：7项通过，覆盖配置投影、资源倍率取整、右侧生成、左移速度、鼠标全额拾取、到船自动损耗及不受普通超时拾取影响；Godot 4.7.2 导入/运行退出0，仅有既有根证书提示。
- `python test/run.py test_import.py`：通过。尝试运行既有 `test_game.gd` 时因总表与当前分表/运行配置的既有不一致在无关断言处失败并中止，本次未修改其期望。

## 2026-09-14 全部 equipment 批量升级

- `test_bulk_upgrades.gd` 已覆盖装甲、护盾及武器均显示10连/MAX按钮；批量成本与等级逻辑专项回归通过。

## 2026-09-14 QA大重启

- `test/run.py test_full_restart.py`，环境变量 `SPACE_BATTLESHIP_TEST_GODOT` 指向本机4.7.2引擎；最终隔离目录 `../../test/work/test_full_restart-5jyi33vv/`。驱动真实点击QA按钮退出旧进程，辅助进程重新导入并启动新游戏；验证忙碌保护、新旧PID不同、当前进程加载后才修改的源码在新进程执行、用户目录相同、资源进度及QA倍速保留。测试创建的所有游戏进程自行退出，退出0。
- 已检查 qa-full-restart.png，「大重启」与原重启/读取/删除同排，无裁切。原 `test_config_panel.gd` 在 `../../test/work/test_config_panel-f5w28und/` 14项全部通过，原同进程重载/配置导入等保持正常。
- 资源导入及测试仅在test/work副本运行，未重启用户正式游戏或改正式配置/存档。Godot仅既有根证书提示；首次测试的证据读取因Windows默认编码失败，改显式UTF-8后通过。测试命令建议设置PYTHONIOENCODING=utf-8。

## 2026-09-14 游戏内数值 K/M/B/T 展示

- 新增 `scripts/number_format.gd` 作为公共格式化入口；游戏内资源、生命/护盾、伤害、费用、掉落、命中飘字、研发倒计时及高科技描述的数量展示统一接入。实际计算、数值与存档不变。
- `python test/run.py test_equipment_tabs.gd`：9项通过；`test_resource_display.gd`：9项通过；`test_hightech.gd`：46项通过；`test_hightech_continuous.gd`：20项通过。Godot 4.7.2 导入与图形执行退出0，仅既有根证书提示。
- 已查看隔离截图 `../../test/work/test_equipment_tabs-pjze_dk8/space-battleship/tabs-weapons.png`：资源显示为 `990K/1M`，生命显示为 `1.2K/1.2K`，装备伤害与费用显示无重叠。

## 2026-09-14 导弹数量与不同目标优先

- `python test/run.py test_target_resistance.gd`：隔离运行21项全部通过；覆盖按 para1 发射、目标不足时循环复用、同目标齐射的视觉错位、抗性优先、不同目标优先及失锁重选。Godot编辑器扫描退出0，仅有既有Windows根证书提示。

## 2026-09-14 武器与护盾批量升级

- `python test/run.py test_bulk_upgrades.gd`：隔离运行9项全部通过，覆盖10连十级总成本一次扣除、资源不足时不部分升级、MAX按当前资源推进，以及武器/护盾按钮和装甲单次按钮范围；Godot编辑器扫描退出0，仅有既有Windows根证书提示。
- 相关旧测试 `test_equipment_tabs.gd` 当前仍受同期 `number()` 显示格式断言影响失败，`test_game.gd` 受当前用户配置与旧测试夹具不一致影响失败；本次未修改其无关期望。

## 2026-09-14 高科技复利与双防御

- 读取独立 `config_excel/hightech.xlsx!A5:H6` 的新 des/description；总表同范围仍为旧版，本次以分表为准。复用转换/校验/原子写入仅更新运行 hightech 段，写入前断言其他段不变，未覆盖总表、分表或玩家存档。
- 隔离 `test/run.py`：test_hightech.gd 46项全过（`../../test/work/test_hightech-i9g4qsmd/`）；test_hightech_continuous.gd 20项全过（`../../test/work/test_hightech_continuous-3x_cgy1d/`）；test_config_workbooks.py 14项全过（`../../test/work/test_config_workbooks-11x4bmad/`）。覆盖三种武器幂次成长、生命/护盾上限与当前容量保持、0级/3级模板、全角括号、整数百分比截断及导入校验。旧描述断言按新模板更新后复验通过。
- 已查看 hightech-continuous.png：3级显示所有武器133%、生命125%，文本和研发按钮布局正常。Godot 4.7.2 导入及图形退出0，无脚本错误，仅既有根证书提示。

## 2026-09-14 炼铁炉历史峰值

- 隔离运行 `python test/run.py <测试名>`：test_furnace_income.gd 17项（`../../test/work/test_furnace_income-tzlmqcrq/`）、test_hightech.gd 40项（`../../test/work/test_hightech-i7rcc70m/`）、test_hightech_continuous.gd 18项（`../../test/work/test_hightech_continuous-4tzhrw63/`）全部通过。覆盖峰值记录/过期保持/新高/等级成长/存档恢复/旧样本兼容及描述与实际产量。
- 连续研发UI夹具显式固定 para2=0.5，与该测试机制期望一致；首次该断言受运行配置0.25影响失败，修正夹具后18项全过。Godot 4.7.2 导入及图形执行退出0，仅既有根证书提示；未修改正式配置或玩家存档。

## 2026-09-14 抗性索敌

- `python test/run.py test_target_resistance.gd` 隔离运行20项全部通过，编辑器导入与执行退出0。覆盖三种武器实际发射优先不抵抗目标、组内排序、全抵抗回退与发射、死敌排除、无参数原排序、导弹多目标补选与失锁重选。
- 产物：`../../test/work/test_target_resistance-84ckf0at/` 的 import.log、test.log。仅既有根证书提示，无脚本错误；夹具只改内存，未修改正式配置或玩家存档，未运行无关测试。

## 2026-09-14 武器卡片CD

- `python test/run.py test_equipment_tabs.gd`：隔离编辑器导入与图形测试退出0，8项检查全部通过。已查看三种武器卡片截图，CD 秒数与名称/等级无重叠；静态检查仅 cd > 0 的攻击装备显示，升级重建时重新读取当前等级。
- 产物：`../../test/work/test_equipment_tabs-06hjc10e/`，截图在其 space-battleship/tabs-weapons.png。仅既有根证书提示，无脚本错误；未修改配置或正式玩家存档，未跑无关测试。

## 2026-09-14 武器数量

- 经 test/run.py 隔离运行：test_enemy_weapon_counts.py 2用例通过（数量展开、混合顺序、非法数量）；test_enemy_weapon_positions.gd 193项通过（当前两艘 |2 敌机实际生成/发射两件基础伤害武器、独立冷却及既有排列回归）。Godot导入和执行退出0，仅既有根证书提示。
- test_level_editor.py 7用例、test_config_workbooks.py 14用例全部通过；首次默认Python缺lxml，改用已有完整依赖的Python后通过，未安装依赖或修改运行器。
- 证据：../../test/work/test_enemy_weapon_counts-9kvnjtf0/、../../test/work/test_enemy_weapon_positions-6j0zz6vp/、../../test/work/test_level_editor-17ocyzp9/、../../test/work/test_config_workbooks-yojzdhsi/。正式JSON仅转换敌机装备数量投影及补全说明，源表/玩家存档不变。

## 2026-09-14 BOSS多船血条

- `test/run.py test_boss_health_cards.gd` 隔离图形运行，Godot 4.7.2；最终 `../../test/work/test_boss_health_cards-_3lrvemo/` 17项全部通过。覆盖1/2/5/6/10个独立卡片、战斗区域内不重叠、size与旧boss字段不影响卡片、独立生命更新、死亡移除与其他卡片位置稳定、前置大型舰无BOSS面板、通关/换关无残留。
- 已检查双大型舰、十小型舰与暂停截图；十船最终截图使用运行时44像素槽距。长描述省略、血量可读、暂停框不遮卡片；BOSS战拾取说明左移，避免与第十艘编号重叠。截图为上述目录 boss-health-two.png、boss-health-ten.png、boss-health-paused.png。
- 编辑器扫描和图形测试退出0，无本次脚本错误，仅既有Windows根证书提示。只改 main.gd 显示与专项测试，未修改配置、战斗数值或正式存档，保留同期高科技UI改动；未运行无关完整战斗测试。

## 2026-09-14 最后一场BOSS战

- 使用当前本机 Godot 4.7.2，经 `test/run.py` 隔离执行；新专项 `test_final_encounter.gd` 在 `../../test/work/test_final_encounter-_vrpj8rm/` 18项通过。覆盖连续两个前置大型舰战不通关/不揭示/不清弹、最后小型舰群身份和信息、多敌全灭门槛、最后死亡立即清弹、单场关卡、跨关落在前置大型舰后不重放及越过最终小型群后原地重放。
- 直接影响回归：`test_boss_projectile_clear.gd` 8项通过（`../../test/work/test_boss_projectile_clear-5aawui9o/`），`test_boss_info.gd` 8项通过（`../../test/work/test_boss_info-urfaxzop/`），`test_loop_retreat.gd` 18项通过（`../../test/work/test_loop_retreat-95awui2q/`）。清弹夹具改为实际最终遭遇，信息期望改为最终敌群所有不同描述。
- `test_level_editor.py` 在 `../../test/work/test_level_editor-_z5c4877/` 7用例通过，新增前置大型舰+最后小型舰配置不再产生旧BOSS警告的验证。编辑器仅调整对应说明文字，本次未重复截图验收。
- Godot扫描及最终测试均退出0，仅既有Windows根证书提示。全部使用隔离配置/用户目录；未改动用户同期编辑的源表、运行JSON或正式玩家存档。初次命令引用上次4.6路径已失效，查明当前引擎为4.7.2后完成上述验证。

## 2026-09-14 高科技页签显示门槛

- `python test/run.py test_hightech_slots.gd`：隔离目录 `../../test/work/test_hightech_slots-apj6o7x9/`，Godot 4.7.2 编辑器导入与图形执行退出0，32项检查全部通过。覆盖首项解锁前隐藏、解锁显示且不切页、全锁后选中页回退，以及既有拖拽/排序/滚动/存档回归；日志仅既有根证书提示，无脚本错误。
- 游戏代码仅新增页签隐藏与选中页回退判断；未修改配置或正式玩家存档。

## 2026-09-14 关卡编辑器

- `test/run.py test_level_editor.py`：6用例全部通过，产物 `../../test/work/test_level_editor-scv_pbo4/`。覆盖新增/修改/删除的源表与运行投影往返、公式及级联缓存/样式保留、增量导入无变化、外部修改冲突、十类非法输入、只读校验、Godot浮点ID传输、提交失败回滚。
- `test/run.py test_level_editor.gd --godot space-battleship/engine/Godot_v4.6-stable_win64.exe`（工作区根执行）：14项全部通过，产物 `../../test/work/test_level_editor-v35v2nyu/`。真实图形场景覆盖读取、复制、字段编辑、搜索、十槽下拉引用及换机、遭遇行、校验、保存导入、重载、删除与引用保护。已查看 formation-editor.png 和 level-editor.png，列表/字段/遭遇可读，长表单与引用区域可滚动。
- 直接影响回归 `test_config_panel.gd`：14项全部通过，产物 `../../test/work/test_config_panel-000pz01m/`；原拆分/读取/重载与控制流程保持正常。
- 当前工作区未携带历史记录中的4.7.2引擎。本次从官方 GitHub 4.6-stable release 下载 Windows 版到忽略的 engine/，以上测试实际使用 Godot 4.6.stable.official.89cea1439；编辑器启动器也支持 SPACE_BATTLESHIP_GODOT 或 engine 自动发现。各次导入/最终图形执行退出0，仅既有Windows根证书提示；不声称4.7.2本机验证。
- 首轮图形测试发现整数ID经过Godot JSON传输成为小数，已在数值XML写出和UI引用显示两端修复，并新增专项断言。所有写配置测试均在隔离副本，不改正式源表、运行JSON或玩家存档。
- 实际执行项目关卡编辑器.cmd，资源导入完成且独立「太空战舰 · 关卡编辑器」窗口成功打开。启动器为编辑器设置独立 `.runtime/level-editor-user` 环境，避免依赖系统编辑器设置目录的写权限；新脚本 UID 已保留。

## 2026-09-14 炼铁炉排除自身收益与描述同步

- `test/run.py test_furnace_income.gd` 在 `../../test/work/test_furnace_income-vyqeqkhx/` 12项通过：普通手动/自动损耗后收入、炉子来源标记、总收入与炉子基数分离、连续三轮领取不放大、最新“不含自身”描述结果、存档来源保留、60秒边界及其他资源排除、旧档未知来源样本处理。
- 直接影响回归：`test_hightech.gd` 在 `../../test/work/test_hightech-hhpifwm4/` 40项通过；`test_hightech_continuous.gd` 在 `../../test/work/test_hightech_continuous-0ict183b/` 18项通过；`test_config_workbooks.py` 在 `../../test/work/test_config_workbooks-121p_ka2/` 14项通过。机制夹具明确固定 para2，避免把同期数值编辑混入机制期望。Godot 编辑器/有图形执行及Python测试均退出0，日志仅既有根证书提示。
- 核对总表和已更新分表：description 新增 `不含自身`，para2 同期改为0.25；使用现有转换/校验同步运行 hightech 段，未覆盖其他运行段或正式存档。具体口径及旧档窗口兼容见 modules/progression.md。

## 2026-09-14 高科技动态描述与连续研发

- `test/run.py test_hightech_continuous.gd` 最终隔离目录 `../../test/work/test_hightech_continuous-hawinqe6/`：18项通过，编辑器导入/图形执行退出0。覆盖切换冻结/切回续研、多等级连续推进、暂停、离线跨级和暂停项不推进、存档恢复、多名额显式替换、description 参数/实时收入/等级/取整/括号与小数、非法表达式、真实UI切换与无重建动态刷新。补测发现表达式整数字面量除法问题，转为浮点字面量后 `{1/2}` 正确显示0.5。
- 已查看 `hightech-continuous.png`：三项 description 为计算后的文本，无 para/花括号原文；“切换研发 / 继续研发 / 连续研发中”状态及剩余秒数清楚，卡片/滚动区布局正常。
- `test/run.py test_config_workbooks.py` 在 `../../test/work/test_config_workbooks-ha_cakkv/` 14项通过；覆盖新的 description 引用/语法校验、错误时保留旧JSON与缓存，原增量/全表一致与回滚测试通过。测试坐标随源表新增C列调整，运行转换继续按字段名读取。
- 直接影响回归：`test_hightech.gd` 在 `../../test/work/test_hightech-nngb3146/` 40项通过；`test_hightech_slots.gd` 在 `../../test/work/test_hightech_slots-zktya57y/` 29项通过。旧“完成释放名额/不能切换/des显示”断言按用户新规则更新；所有图形/导入退出0，无脚本错误，仅既有根证书提示。
- 仅从总表同步 hightech 分表及运行 hightech 投影，其他运行段保持原值；测试在 test/work 隔离副本及独立存档运行，未访问正式玩家存档。

## 2026-09-14 高科技卡槽换位

- `test/run.py test_hightech_slots.gd`：最终隔离目录 `../../test/work/test_hightech_slots-jea5ulqk/`，编辑器导入及有图形执行退出0，29项全部通过。覆盖未解锁隐藏/单项解锁、6个匿名空槽、后续10项扩展至12槽、真实按下/移动/松开事件驱动原生拖拽、预览/目标高亮、双向交换、按钮落点不研发、区域外取消、边缘自动滚动、移入空槽、保留页签与滚动、拖拽期间延后重建、实际隔离存档往返、非法索引/重复/失效配置处理及研发归属不变。
- 输入测试使用独立 SubViewport 接收鼠标事件并走原生拖放回调；早期直接向桌面 Window 注入事件时，测试环境系统指针不在窗口内，导致命中验证失败，已改为隔离视口坐标。没有把直接调用换位函数当作拖拽验收。
- 已检查 `hightech-one-unlocked.png`、`hightech-drag-preview.png`、`hightech-empty-slot-drop.png`：隐藏项不泄漏名称；卡槽/描述/按钮无纵向重叠；拖拽预览与青色目标框清晰；松手后卡片固定在扩展槽内，滚动位置保留。
- 直接影响回归 `test/run.py test_hightech.gd` 在 `../../test/work/test_hightech-9a3jquci/` 40项全部通过、编辑器及图形退出0。两组日志只有既有根证书提示，无脚本错误；本次未修改Excel/运行JSON/正式玩家存档，未运行无关战斗测试。

## 2026-09-14 高科技

- 捆绑 Python 执行 `test/run.py test_hightech.gd`，最终隔离目录 `../../test/work/test_hightech-wo0g5lzm/`；编辑器导入和有图形专项退出0，40项通过。覆盖0级/解锁、配置并发限制及改为2、线性耗时、无装备等级上限、暂停与模拟增量、能量类型判定/向上取整、装甲仅增上限、同源一分钟铁入账、点击/禁止悬停及自动结算、10秒过期、长离线跳过过期生成、真实存档往返、旧档兼容、离线1倍及 offlineMax 非默认/零/四小时上限、真实页签/按钮/描述精度与布局。
- 已查看最终 `space-battleship/hightech.png`：三项卡片完整、炼铁炉长描述正确换行、研发倒计时/占满状态清楚，橙色铁块、数量和“点击领取”提示可见。首轮发现描述越界，调整换行设置顺序后重跑本专项并验图。
- `test/run.py test_config_workbooks.py`：`../../test/work/test_config_workbooks-sqwzcldm/`，12项通过；包括 hightech 全表/分表投影一致、仅更新高科技时其余段不变、重复名称/无效周期/并发数/离线时长拒绝且保留旧JSON与缓存，原增量/回滚测试均通过。
- 直接影响回归：`test_resource_display.gd` 在 `../../test/work/test_resource_display-psnbrch0/` 9项通过；`test_equipment_tabs.gd` 在 `../../test/work/test_equipment_tabs-u24v3xpi/` 8项通过，均编辑器扫描及图形执行退出0。日志只有既有根证书提示，无脚本错误。未扩大到无关完整战斗模拟。
- 正式运行 JSON 仅按现有转换函数接入 hightech 与相关 config 键，源表/分表已只读核对；没有用测试结果覆盖其他运行数据，未访问正式玩家存档。规则来源与用户澄清见 modules/progression.md。

## 2026-09-14 BOSS死亡清弹

- 捆绑 Python 执行 `test/run.py test_boss_projectile_clear.gd`，隔离目录 `../../test/work/test_boss_projectile_clear-vf9czs4_/`；编辑器导入及图形专项退出0，8项检查全部通过。
- 覆盖弹体击杀BOSS、三种武器敌我弹体全部清空、同帧后续致命敌弹不再结算、通关记录/状态、重复伤害不重复掉落、等待后正常进入下一关、普通敌舰死亡保留弹体及直接伤害击杀BOSS立即清弹。旧 test_game 仅移除被新指令替代的BOSS残弹保留分支，普通波次分支保留；未运行无关完整模拟。
- 已查看 `space-battleship/boss-before.png` 与 `boss-after.png`：死亡前舰船及弹体可见，死亡后BOSS和弹体消失、玩家保持1生命并显示解锁弹窗。日志 import.log/test.log 无脚本错误，仅既有 Windows 根证书提示。未修改正式配置与玩家存档。

## 2026-09-14 前进重置冷却

- 用户纠正后更新实现及断言；隔离副本 `../test/work/travel-cooldowns/` 与独立 APPDATA/LOCALAPPDATA 运行 `../test/test_travel_cooldowns.gd`，22项断言通过、退出0：暂停保留、波次结束恢复完整CD、三种武器下次遭遇不会立即发射、前进不倒计时、完整间隔前不发射/到时发射、后退完成及开局恢复完整CD。
- 日志 test.log/test.err 仅既有根证书提示，无测试脚本错误；未运行无关完整模拟/图形QA，未使用玩家存档。

## 2026-09-14 重复武器发射位置

- 使用捆绑 Python 执行 `test/run.py test_enemy_weapon_positions.gd`，隔离目录 `../../test/work/test_enemy_weapon_positions-qg9karbi/`；编辑器导入与有图形专项退出0，185项断言全部通过。
- 覆盖普通舰/BOSS、1/2/3/6个同名武器及激光/火炮交错配置：实际 tick 发射数量、对称等距位置、单个居中、实际起点瞄准、冷却/伤害保持及玩家起点不变。未运行无关测试。
- 补充视觉验收：`test/run.py capture_enemy_weapon_positions.gd` 在 `../../test/work/capture_enemy_weapon_positions-z1neryii/` 隔离运行，导入与截图退出0。逐张查看 `space-battleship/mounts-{laser,cannon,missile}_mon-{origin,flight}.png` 六张真实渲染图：左列普通舰、右列BOSS，从上到下2/3/6个同名武器；起点上下均匀展开，飞行0.08秒后仍可辨识分离，三种弹体朝向正确。普通舰六枚导弹间距较紧但仍分离，外侧起点偏出舰缘，符合用户允许偏移。无需修改游戏实现。
- 截图夹具首轮缺少 targets 排序所需 size 字段，补齐后重跑；以上最终目录日志无脚本错误，仅既有根证书提示。未重复已通过的185项数值测试。
- 日志 import.log、test.log 仅既有 Windows 根证书提示，无脚本错误；未改写正式 Excel、运行 JSON 或玩家存档。

## 2026-09-14 装备页签

- 必要脚本/data/assets/场景复制至 `../test/work/equipment-tabs/`，APPDATA/LOCALAPPDATA 隔离；编辑器资源扫描退出0。
- `../test/test_equipment_tabs.gd` 图形专项8项全部通过：首个武器页、起始装备保留、防御隐藏/切换显示、升级实际生效、升级后保持所选页、全部装备跨页保留及页签不越过页脚。
- 已检查 tabs-weapons.png / tabs-defence.png；修正冷却条高度遮挡后最终武器页图标、费用、升级按钮清晰。日志 scan.log/scan.err、test.log/test.err 仅既有根证书提示，无脚本错误；未运行无关战斗或配置测试。

## 2026-09-14 QA 删除存档

- 在 ../startup-verification/game 项目副本及 delete-save-user 隔离用户目录运行 ../test/test_delete_save.gd，7项全部通过、退出0：完整初始进度、第一关、QA实例保留、QA设置保留、旧存档不回写、新进度可保存且普通重启保留、无存档也可重开。正式玩家存档未删除。
- 检查 preview-delete-save.png，三个操作按钮同排显示完整，清档成功提示正常。仅既有根证书提示，无脚本错误；未跑无关配置/战斗测试。

## 2026-09-14 启动黑屏修复

- 正式游戏日志确认 main.gd 第13至15行 PNG preload 报 no resource loaders，导致主脚本解析失败；三张图片存在但尚无导入产物。
- 启动脚本新增等待 headless editor import；保持 UTF-8/CRLF、原便携用户目录与同进程 QA。
- 将必要项目文件复制到 ../startup-verification/game，确认初始无 .godot，隔离用户目录，通过实际 CMD 启动（副本末尾仅加 /wait 和 --capture 方便自动退出），退出0。查看 preview-combat.png，舰船、激光、敌舰和升级面板正常；游戏日志无脚本错误。仅既有 Windows 根证书提示。
- 正式项目也完成资源导入、退出0；该步骤使用隔离编辑器用户目录，未运行正式玩家会话、未修改玩家存档或运行 JSON。未运行无关玩法/配置测试。

## 2026-09-14 分表增量配置

- `../test/test_config_workbooks.py` 在 `../config-incremental-verification/` 临时子目录使用总表副本运行，8个用例全部通过：单表公式/缓存/样式保留且与全表投影一致；无变化零工作簿解析/零JSON写入；只解析单个修改文件；非法数据保留JSON与旧指纹；缺公式缓存整批拒绝；缺分表不静默忽略；同名同步与未改文件不重写；提交故障回滚已替换文件。
- 全表 `../test/test_import.py` 在项目副本运行通过；行数按实际来源核对，不再固定旧10关/20级。与增量路径复用同一转换/校验实现。
- 复制 scripts、tools、data、../test、场景及必要 assets 到 `../config-incremental-verification/game/`；APPDATA/LOCALAPPDATA 指向副本自身目录。最终 Godot 编辑器扫描退出0，图形 `../test/test_config_panel.gd` 14项断言全部通过、退出0，覆盖真实拆分按钮、排除总览、读取/无变化、暂停/5倍速、同进程重载及QA实例/路径状态保留。未运行无关战斗模拟。
- 视觉查看副本 `preview-config.png`：新增拆分/目录按钮与读取目录提示无重叠。Windows OS.execute 中文结果传输已改为 ASCII JSON 转义，由QA解码显示，图形断言验证成功提示及无变化提示。
- 本次仅在正式项目创建六份独立 Excel 与清单，未正式增量导入、未改写总表或玩家存档；游戏运行 JSON 未因测试改变。下一次读取首次建立指纹缓存，以后只解析修改过的分表。已测试拆分保留原始单元格XML与样式，不声称执行了 Excel 公式重算。
- 环境仍有既有 Windows 根证书读取提示；最终无本次脚本解析/运行错误。代码只新增配置流程，没有改动同期武器美术等逻辑。

## 2026-09-13 本次整理

| 检查 | 结果与局限 |
|---|---|
| 原表结构/公式缓存 | 7张表；257个公式用受限独立求值核对缓存，无差异/未支持公式。未改写或重算原文件。证据：原 docs/audit/source-check.json（已清理） |
| 原表 → 临时JSON → 当前JSON | 导入成功（10关/6敌机/7群/103装备行），结束时差异0；非原地导入 |
| `../test/test_import.py` | PASS：真实导入、数据行数、defaults保留、坏文件失败时保留原JSON；不代表全部输入边界都覆盖 |
| Godot隔离编辑器扫描 | 本地Godot v4.7.2.stable.official.ed1daf0bf；退出0，无脚本解析失败；有Windows根证书读取错误提示 |
| `../test/test_game.gd` | 最新副本/隔离用户目录运行：71 checks，0 failures，退出0；详细输出及测试输入哈希见 原 docs/audit/game-check.json（已清理） |
| `../test/test_config_panel.gd` | 同一最新副本、另一个隔离用户目录，有图形运行：11项检查通过、退出0，见 原 docs/audit/qa-check.json（已清理）；导入、暂停/继续、5倍速、场景重载/存档/QA实例保留、隐藏重显、来源历史持久化均覆盖 |
| 视觉布局 | 未额外验收像素布局；集成测试通过不等于完整视觉QA。图形测试同样出现根证书读取提示，不影响本次本地断言 |

测试解释：test_game 在内存覆盖部分武器伤害/CD/成本作为机制基准，数据文件保持不变；其“uses Excel”断言名不代表检查真实源表值。10关通关使用强化装备，尚未验证真实初始数值平衡，见 U-013。更早失败已由外部测试更新解决，不作为当前阻塞。

## 后续任务命令

### 2026-09-15 驻守与跃迁

- test/run.py 隔离运行：test_guard.gd 最终28项全通过（work/test_guard-sdhs2lgq），test_loop_retreat.gd 更新旧循环期望后17项全通过（work/test_loop_retreat-hzwqja8k），test_skip_clear.gd 更新驻守离开期望后7项全通过（work/test_skip_clear-9n915e6x）。各编辑器导入与测试退出0；仅既有Windows根证书提示。
- 覆盖巡航到下一波、战斗中原点驻守、清空才计时、间距/速度换算、暂停、原波刷新、关闭恢复推进、三种死亡选项、跨关返回/就地驻守、最终遭遇通关后重刷、独立跃迁、驻守位置及选项存档、实际设置菜单信号；相关即时换关与原死亡回退同步验证。
- 检查最终副本 space-battleship/guard.png，跃迁/驻守/设置及刷新倒计时无重叠；产物均在 ../test/work，各副本 import.log/test.log 为证据。未运行无关完整战斗、充能或配置导入测试。

### 2026-09-15 立即过关按钮

- 通过 test/run.py 运行 test_skip_clear.gd，隔离副本 `../test/work/test_skip_clear-5t6ofpk4/`；编辑器导入退出0，专项7项全通过，测试退出0。
- 覆盖战斗中拒绝跳关、保留解锁确认、倒计时期间按钮可用、实际按钮信号立即换关、防重复跳关、循环目标及原自动倒计时。检查 space-battleship/skip-clear.png；仅既有Windows根证书提示，未运行无关测试。

### 2026-09-14 离线资源收益

- 总表及分表 config!A10:C10 核对 offlineMax 单位为小时；运行投影接入该字段。test_offline_config.py：7项通过，覆盖表/JSON字段一致、零/小数小时、拒绝负数/文本/无限值。产物：test/work/test_offline_config-_du3trig。
- test_offline_resources.gd：11项通过，覆盖分资源速率、最终取整、4小时及非默认上限、零上限、时钟倒退、旧档、异常速率、存档速率与重复加载不重复领取。最新产物：test/work/test_offline_resources-amd12rrr。
- 同期统计/UI代码更新后运行 test_resource_display.gd：9项通过，无脚本错误；产物：test/work/test_resource_display-joap7lkg。初次UI运行遇到同期高科技描述格式错误，最新源码已修正后复验通过；不更改其玩法。
- 均由 test/run.py 隔离副本与用户目录执行，Godot 4.7.2 编辑器导入、测试退出0；存在既有根证书提示。未读写正式玩家存档，未修改Excel源文件，未跑无关完整模拟。离线提示复用现有 toast，未额外进行该提示截图验收。

### 2026-09-14 测试产物权限修复

- 用户授权后，仅为 test/work/test_resource_display-kba6xqg5 及子项启用权限继承：125项成功、0失败。view_image 已成功读取原 resource-rate.png，补完顶部“铝”的视觉核查。
- test/run.py 在 Windows 的 mkdtemp 后执行带失败检查的 icacls /inheritance:e，再创建子项。Python AST检查通过；test/work/acl-check-_1hkn_cr 使用相同创建/继承流程，子文件继承访问权限。未运行无关游戏测试或修改正式存档权限。

### 2026-09-14 资源名称同步

- 复用 `test/run.py test_resource_display.gd` 隔离运行，编辑器导入与图形测试退出0，9项通过；当前运行 JSON resources 为铁/铝。静态确认顶部直接复用同一资源名映射，掉落/拾取/升级原已使用该映射。
- 产物：`../../test/work/test_resource_display-kba6xqg5/` 下 import.log、test.log；截图读取被文件权限拒绝，未完成截图视觉核查。未修改 Excel、运行 JSON 或玩家存档；仍有既有Windows根证书提示。

### 2026-09-14 弹体缩小

- 仅修改 main.gd 显示缩放，复用 `../weapon-art-verification/capture_weapons.gd` 及隔离用户目录。有图形绘制退出0，六发敌我弹体正常加载、旋转并绘制，已查看缩小后的 weapons-preview.png。
- 日志 scale.log/scale.err 无脚本错误，仅既有根证书提示；未运行无关战斗模拟。原始PNG保持不变，各武器基准尺寸统一乘 PROJECTILE_SCALE=0.65。

### 2026-09-14 武器美术

- 内置 image_gen 生成三种PNG，检查均含真实alpha并原样保存至 assets/weapons；提示词随素材README保存。
- 必要脚本、data、assets及场景配置复制至 `../weapon-art-verification/`，隔离 APPDATA/LOCALAPPDATA。编辑器资源导入与扫描退出0；临时 capture_weapons.gd 有图形专项运行退出0，三张纹理正常加载，绘制敌我六发弹体，覆盖向右、向左倾斜及空目标。
- 已检查副本 weapons-preview.png：三种轮廓、配色可分辨，透明背景及朝向正常。scan.log/scan.err、capture.log/capture.err 无脚本错误，仅既有Windows根证书提示。纯美术接入未运行无关完整模拟/Excel导入。

### 2026-09-14 敌人生命显示

- 独立副本 `../enemy-health-verification/` 隔离 APPDATA/LOCALAPPDATA，编辑器扫描退出0；临时 ../test/probe.gd 验证13组格式输入，全部通过，包含0、两位数、123、1230、单位边界及K/M/B/T。
- 有图形检查 normal.png/boss.png，普通敌舰当前/最大生命置于舰体右侧避免相邻槽遮挡，BOSS面板显示缩写。最终探针退出0；日志 scan.log/scan.err、test.log/test.err 仅既有Windows根证书提示。只改显示，未运行无关战斗模拟或改写玩家存档。

### 2026-09-14 资源收益切换

- 必要项目文件复制至 `../resource-rate-verification/`，APPDATA/LOCALAPPDATA 隔离，使用 `--script <隔离工作区>/test/test_resource_display.gd -- --capture` 有图形运行，未使用玩家存档。
- 编辑器扫描退出0；专项9项全通过、退出0：默认总量、按钮来回切换、实际手动/自动入账、扣费不影响收入、UI重建保留模式、资源分类、60秒边界淘汰及无收入归零。
- 已查看副本 resource-rate.png：顶部按钮与铁/钛每秒速率可读、无重叠。日志 scan.log/scan.err、test.log/test.err；有既有Windows根证书提示。未运行无关完整模拟/Excel导入。

### 2026-09-14 关卡旁 BOSS 信息

- 独立副本 `../boss-info-verification/` 复制 scripts/data/场景配置及 ../test/test_boss_info.gd，隔离 APPDATA/LOCALAPPDATA，未使用玩家存档。
- Godot 4.7.2 编辑器扫描退出0，有图形专项8项全通过、退出0：未遭遇未知、普通敌群不揭示、BOSS遭遇揭示、死亡与重刷保留、未通关发现记录存档往返、不同关卡隔离、旧已通关存档兼容。
- 检查 boss-known.png 与 boss-unknown.png：信息位于关卡标题右侧，与循环选择及进度条无重叠。日志 scan.log/scan.err、test.log/test.err 仅有既有 Windows 根证书提示；未运行无关完整模拟或QA导入测试。

### 2026-09-13 护盾回归修复

- U-014 根因为 test_game.gd 硬编码旧恢复比例和等待时间，与当前 data/game_data.json 的 shield 1级 para2/para3 不一致；game.gd 正确读取当前配置。本次只修改测试及文档，不修改游戏恢复逻辑或运行数值。
- 复用原 advance/check，为护盾建立独立 BattleGame，跳过敌群以避免较长等待期间受击干扰；断言读取配置，覆盖等待期间不恢复、等待结束后每秒恢复量、再次受击重置等待及恢复上限。
- 复制 scripts、data、../test/test_game.gd 与场景配置至 `../shield-verification/`，隔离 APPDATA/LOCALAPPDATA。为确认此前完整模拟唯一失败项已消除，运行完整 test_game.gd：103项全部通过，退出0；编辑器扫描退出0。
- 日志：副本 scan.log/scan.err、test.log/test.err。仅既有 Windows 根证书提示，无脚本错误；未运行无关 Excel/QA 导入测试，未使用玩家存档。

### 2026-09-13 指定循环关卡与跨关死亡回退

- 独立副本 `../loop-retreat-verification/`，复制 scripts/data/场景配置与 `../test/test_loop_retreat.gd`，隔离 APPDATA/LOCALAPPDATA；未读取或修改玩家存档。
- Godot 4.7.2 编辑器扫描退出0；最终有图形回归18项全部通过、退出0，覆盖已通关选择限制、开启立即切换、持续重刷、独立目标存档、跨关剩余距离、目的位置敌群重放、非默认/零距离、精确关卡边界、第一关截断，以及跨关落在BOSS后方时在落点重新触发BOSS。
- 真实场景实例的下拉选择和开关信号已验证，窗口截图 loop-ui.png 已检查，关卡选择与循环状态无遮挡。未执行无关完整战斗/Excel/QA导入测试；既有 U-014 不在本次范围。
- 日志：副本 scan-out.log/scan-err.log、test-out.log/test-err.log；仅既有 Windows 根证书提示，无脚本解析或运行错误。

### 2026-09-13 自动拾取独立取整验证

- 在 `../auto-rounding-verification/` 复制 scripts/data 与场景配置，隔离 APPDATA/LOCALAPPDATA；从 test_game.gd 提取本次3项资源断言运行，不执行无关模拟。
- 3项全部通过，退出0：3×1.1掉落为4；自动损耗40%后提示/余额/本局累计均为3；手动拾取4后累计为7。静态确认标签直接使用整数 drop.amount，拾取提示使用 collect 事件 amount。
- Godot 4.7.2 编辑器扫描退出0；存在既有Windows根证书提示。日志为副本 scan.log/scan.err、test.log/test.err，探针现为 ../test/legacy/resource_probe.gd。旧合并取整验证属于历史规则，已由本次用户指令替代。

### 2026-09-13 掉落显示验证

- 掉落标签复用 number()，传入 ceilf(float(drop.amount))；静态检查确认仅更改显示参数，不回写掉落中间值或改变自动拾取损耗计算。
- 复制必要项目文件至 `../resource-display-verification/` 并隔离 APPDATA/LOCALAPPDATA，Godot 4.7.2 编辑器扫描退出0，无脚本解析错误；存在既有Windows根证书提示。日志为副本 scan.log/scan.err。
- 本次为单行显示修复，未运行无关模拟或QA导入测试，未进行窗口视觉验收。

### 2026-09-13 失去目标后弹体继续飞行

- 在 `../projectile-flight-verification/` 独立副本与隔离 APPDATA/LOCALAPPDATA 运行；保留当前资源取整等外部修改。
- 最终有图形 `../test/test_game.gd`：100项、99通过、1失败，退出1；唯一失败为既有 TODO U-014。无脚本解析/运行错误，仅既有Windows根证书提示。日志为副本 `visual.log`、`visual.err`。
- 覆盖激光/火炮不换靶且直线飞行、导弹无活目标后继续飞行、出屏清理、敌舰死亡后弹体在普通波次/BOSS通关后继续移动与命中、玩家死亡后敌弹继续飞行、无目标弹体实际场景绘制。未改无关护盾逻辑，未重跑Excel或QA配置面板测试。

### 2026-09-13 资源取整验证

- scripts、../test、data、project.godot、main.tscn 复制至 `../resource-rounding-verification/`，APPDATA/LOCALAPPDATA 指向该副本独立目录；未读写玩家存档或修改原表/运行数值。
- Godot 4.7.2 隔离编辑器扫描退出0；模拟86项、85通过、1失败、退出1，资源相关断言全部通过。唯一失败为既有护盾恢复检查，见 U-014；仍有Windows根证书提示。
- 新增7项覆盖中间倍率精度、倍率与损耗完成后单次取整（3×1.1×0.6 → 2，提前取整会误得3）、手动拾取/事件/本局累计、成本判定和扣除、起始资源、整数存档往返；更新自动拾取及旧小数存档期望。
- 仅在副本撤销本次4处资源实现作对照，护盾断言同样失败，同时出现9项资源期望失败；恢复副本实现。日志：test-out.log/test-err.log、baseline-out.log/baseline-err.log、scan-out.log/scan-err.log。保留同期外部后退距离修改；不改无关护盾实现或断言。

### 2026-09-13 backRange 验证

- 只读核对 config!A8:C8；临时导入对比仅 config 新增 backRange，随后现有导入器更新运行JSON。未修改原表。
- 独立副本运行 test_import.py 通过；test_game.gd 为79项、1失败，非默认/零后退距离新增断言均通过。换用新隔离用户目录仍复现；在副本撤回本次后退代码与新增夹具后同一护盾断言仍失败，见 TODO U-014。
- 日志：`../weapon-target-verification/backRange3.log`、`backRange3.err` 与 `baseline.log`、`baseline.err`；既有Windows根证书提示仍存在。副本源码已恢复为当前改动。

### 2026-09-13 武器死亡换靶验证

- 仅复制 scripts、../test、data、project.godot、main.tscn 至 `../weapon-target-verification/`，APPDATA/LOCALAPPDATA 指向副本下独立目录，未使用玩家存档。原项目 `.runtime` 写入被拒绝，改用工作区内独立副本。
- Godot 4.7.2 隔离编辑器扫描退出0；`../test/test_game.gd`：77 checks、0 failures、退出0。日志位于副本 test.log/test.err、scan.log/scan.err。仍有既有Windows根证书读取提示。
- 新增6项断言覆盖激光/火炮失去目标后清理且不伤害其他敌人、下次开火选择活敌、导弹死亡换靶及无活敌时清理。原有模拟继续通过；本次未执行无关Excel导入或图形QA。

在项目根执行，`python` 必须含 openpyxl；设置 GODOT 为实际引擎路径。不要将本机 Codex 安装路径写成必需依赖。

```sh
python tools/inspect_knowledge.py --sheet equipment --range A44:N45
python tools/inspect_knowledge.py --output ../test/work/audit/source-check.json
python ../test/run.py test_import.py
```

test_import.py 使用 test/work 下临时目录。审计退出1可能表示发现配置差异，并不等于工具崩溃。工具不会改原表或运行JSON；完整审计只在来源/数据核对任务执行。

Godot首次接手先导入类缓存，再运行模拟测试。PowerShell示例（用**项目副本**运行，避免并行代码修改和QA覆盖）：

```powershell
$env:APPDATA = '<隔离目录>/roaming'
$env:LOCALAPPDATA = '<隔离目录>/local'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
& '<Godot可执行文件>' --headless --path '<项目副本>' --editor --quit
& '<Godot可执行文件>' --headless --path '<项目副本>' --script '<隔离工作区>/test/test_game.gd'
```

QA测试用有图形环境的同样副本，运行 `--script <隔离工作区>/test/test_config_panel.gd`；同时将原表置于副本父目录，创建副本 `.runtime`，隔离 user:// 偏好并检查实际Excel来源。此测试会临时更改副本JSON并显示附属窗口；仅重定向 APPDATA 不会隔离 res://data。headless普通游戏不自动创建QATools，不能直接用它运行这份图形集成测试。本次QA测试与game-check记录的同一源码副本一致。

验证范围随任务选择：只改文档检查链接/来源/状态；数值改动检查原表缓存、导入差异及受影响模拟；战斗改动跑对应规则及模拟；UI/QA改动另做按钮和真实窗口交互。不为文档整理修改既有测试期望。

## 2026-09-14 目录整理验证

- test/run.py：分表8项、全表导入检查、有图形QA 14项均通过，验证测试外移后的源码/总表定位与隔离工作区。
- test/work/startup-js6jpuwm：无 .godot 的完整相对布局副本，以实际 CMD 启动根入口；仅在副本最终启动行加入 /wait 和 --capture 以自动退出，退出0，生成 preview-combat.png，已检查舰船、敌舰与升级面板正常，无脚本错误。
- 正式 data/game_data.json 的 SHA-256 与整理前一致；未操作正式 .userdata。旧验证副本和审计产物已删除，新验证产物全部位于 test/work。

## 目录整理后的测试入口

测试源码位于工作区 test/，测试工作副本、截图、日志、测试存档与审计结果只写入 test/work/。从工作区根执行 `python test/run.py <测试文件名>`；运行器保留项目与总表相对布局并隔离用户目录，Godot测试默认有图形。旧 *-verification 目录、preview 截图和 docs/audit JSON已清理，上述历史记录只表示当时验证结论，不能再引用为现存产物。legacy 中的探针仅供复用。
