# 当前保留的基础代码

当前保留 Excel 转 JSON、共享 C++ Amount/绑定和保存骨架，入口在 `src/main.tscn`，由 `src/game_session.gd` 驱动持续存在的 native 核。整体架构完成后再安排整体测试；本阶段只检查编译，并运行独立 Amount 的直接 C++ 正确性测试。

## Excel 导入

在 space-battleship/ 运行：

```powershell
python foundation/import_excel.py
# 也可指定另一个 Excel 目录和输出位置：
python foundation/import_excel.py --source <Excel目录> --output <输出JSON>
```

默认读取 config_excel/ 根目录的 *.xlsx，不递归进入 published/ 等子目录。输出 generated/config.json，结构为 `{工作簿文件名: {工作表名: [数据行对象]}}`。表头来自第一行，第二、三行为说明，数据从第四行起。公式读取 Excel 已保存的缓存值，导入器不计算公式。

没有逐字段 schema、逐表输入清单、主键/引用/规则检查。它只转换数据，不决定哪些候选或旧内容在游戏里启用。运行方直接读取生成 JSON，例如：

```gdscript
var text := FileAccess.get_file_as_string("res://generated/config.json")
var config = JSON.parse_string(text)
var equipment_rows: Array = config["equipment"]["equipment"]
```

`GameSession.initialize()` 直接读取该文件并调用普通组装函数，不经过配置包装层。文件名和工作表名原样作为两层键，不生成额外索引、哈希、元数据或发布指针。

Excel 是配置输入权威。需要大数表示的字段应在 Excel 中以文本保存，避免 Excel 自身的数值精度损失；普通数值字段保持原样。导入器原样传递文本，不解析、计算、舍入大数，也不复制 Amount 范围规则或与另一套算法比对。Amount 是唯一数值语义实现；保存层只保管其表示，不重算金额。

不存在 ConfigBundle 或查询包装。配置修改在对应 Excel 中进行，再重新导入；生成 JSON 只是运行产物，不作为测试或人工改值的入口。

## 原生构建

Amount 值及绑定在 addons/native_battle/src/amount_value.hpp、amount_api.hpp，平台文件替换原语在 foundation_disk.hpp；与保留的 native/GPU 源码一起构建。

```powershell
powershell -ExecutionPolicy Bypass -File addons/native_battle/build_native.ps1
```

该脚本使用其参数指定的构建及工具目录，要求固定的 godot-cpp 版本和 Godot API，输出 DLL。运行程序需要加载对应 GDExtension；最小入口通过构建产物中的 GDExtension 清单加载该 DLL。现有 native retained/GPU 表现读取同一个战斗核。

## 保存骨架

foundation/host/save_files.gd 只通过显式目录创建，request() 接收本次 payload 快照，poll() 回收写入结果，dirty()/close() 提供状态。保留实际保存需要的写入失败处理、flush/回读、checksum、A/B 槽与主备指针保护；测试专用故障注入已移除。没有默认个人存档路径。保存层不接收配置身份参数，也不写入或匹配配置哈希；文件 checksum 和 payloadHash 继续只校验保存数据的完整性。


## 唯一保留的正确性测试

`foundation/tests/amount_value_tests.cpp` 直接包含 `amount_value.hpp`，不依赖 Godot、Excel、配置或保存设施。它覆盖大数四则运算、幂、等比和、取整、编码范围及非法输入边界；含 0–10000 整数的 floor/ceil 一致性回归。必须启用 assert，不使用 `-DNDEBUG`。

```powershell
& '<C++编译器>' -std=c++17 -O1 -static foundation/tests/amount_value_tests.cpp -o "$env:TEMP/space-idle-amount.exe"
if ($LASTEXITCODE -eq 0) { & "$env:TEMP/space-idle-amount.exe" }
```

不保留阶段配置/保存测试、测试 Excel、无界面工程、runner 或验证记录。整体玩法、游戏中的配置读取、Godot 绑定运行和保存恢复行为均留待架构完成后整体测试。


## 运行入口与职责

在本目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File addons/native_battle/build_native.ps1
powershell -ExecutionPolicy Bypass -File run_game.ps1
```

启动脚本先按原路线将 Excel 导入为 JSON，再运行正常 Godot 主场景；原生 DLL 与 GDExtension 清单仍生成在显式 D 盘构建目录。它是游戏启动入口，不是测试 runner。编译检查不会执行该启动脚本。

`GameSession` 持有航程、固定步余量、钱包、待领取掉落及长期成长数据，直接调用 `combat_setup.gd` 和 `src/systems/` 普通函数。核只初始化一次，随后通过 `start_wave/finish_wave/begin_retreat/finish_retreat/advance/take_results` 推进；成长和换装调用 `set_player_configuration` 原位更新，提交入口校验一次。已飞出攻击持有出生快照，防具模块损伤是生命的唯一权威，合计盾甲仅供读取。

核内金额和宿主钱包共用 C++ Amount；边界使用 Amount 生成的十进制文本。装备函数只组装到 `charged_base`，熟练、适应和战斗临时效果由 native 计算。装备 Q 与首级特例只在 `systems/equipment.gd` 定义，单级、批量及 MAX 共用报价；Amount 只保留通用数值运算。

纯几何函数位于 `scripts/ship_geometry_convention.gd`。舰体 alpha 轮廓生成的逻辑凸包同时供接触计算与绘制；`GameSession._sync_geometry` 以稳定来源 ID 提供炮口，避免禁用无人机或内部槽复用改变数组对应。表现读取现有核与运动租约，不拥有伤害结算。

推进按武器、连发、离管、光束及奇异物质的真实到期时间切段。同刻先恢复及延期结算，再按来源处理出生（我方炮在出生调用内命中），随后把已有光束跳、飞行接触和到期奇异物质按时刻、阵营、来源槽、武器槽及生成序结算。每项执行前复查存活和代际；命中及其合法局部派生结束后再处理下一项。奇异物质到期伤害不重新触发主攻击派生。

非终波保留合法旧弹体；终波由核清攻击，宿主按自动领取口径收齐后等待、驻守或前进。死亡演员会回收，仍有合法在途引用的来源槽保留代际。敌炮与激光按舰体凸包检测接触，导弹沿用既定命中半径。

掉落按花括号内分号拆项，再解析资源、数量和概率。待领集合使用 `native:<DropId>` 与 `timed:<宿主序号>` 分域；native 登记游标只消费死亡结果流，两域领取后删除待领项，不积累永久已领集合。重复登记由游标拒绝，重复领取无效。

定时资源来自 `config.autoGenRes`，在航行、战斗、清关等待、驻守等待和撤退中累计生成时间，离港和暂停不推进。数量按战点倍率用 Amount 计算并取整，自顶部移动，到达、手动领取和终波强制领取共用入账函数。移动物不使用死亡掉落的自动领取期限；`timed_drop` 与 `enemy_drop/fragment_drop` 一同计入原生收入峰值。科研完成先同步收入效果；峰值在入账变化时更新，样本按现实与游戏时间窗口裁剪，自动投入到期计算。

`src/main.gd` 提供输入、只读显示与现有 retained/GPU 接线。空格暂停，G 切换当前战点驻守，点击掉落手动领取；成长面板调用 Session 的装备、强化、反应炉和科研命令。到期或终波强制领取按自动损耗规则处理，普通碎片不套用资源自动损耗。

当前验证范围仅为 C++/GDScript 编译及既有独立 Amount 测试，不新增配置、保存或战斗测试设施。整体玩法、完整页面和长期保存恢复仍待后续阶段统一运行验证。
