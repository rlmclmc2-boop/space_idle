# 当前保留的基础代码

当前保留 Excel 转 JSON、共享 C++ Amount/绑定和保存骨架，第二阶段最小入口在 `src/main.tscn`，由 `src/game_session.gd` 驱动持续存在的 native 核。整体架构完成后再安排整体测试；本阶段只检查编译，并运行独立 Amount 的直接 C++ 正确性测试。

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

Excel 是配置输入权威。需要大数表示的字段应在 Excel 中以文本保存，避免 Excel 自身的数值精度损失；普通数值字段保持原样。导入器原样传递文本，不解析、计算、舍入大数，也不复制 Amount 范围规则或与另一套算法比对。Amount 是唯一数值语义实现；保存层只保管其表示，不重算金额。本轮未修改正式 Excel 内容。

不存在 ConfigBundle 或查询包装。配置修改在对应 Excel 中进行，再重新导入；生成 JSON 只是运行产物，不作为测试或人工改值的入口。

## 原生构建

Amount 值及绑定在 addons/native_battle/src/amount_value.hpp、amount_api.hpp，平台文件替换原语在 foundation_disk.hpp；与保留的 native/GPU 源码一起构建。

```powershell
powershell -ExecutionPolicy Bypass -File addons/native_battle/build_native.ps1
```

该脚本使用其参数指定的构建及工具目录，要求固定的 godot-cpp 版本和 Godot API，输出 DLL。运行程序需要加载对应 GDExtension；最小入口通过构建产物中的 GDExtension 清单加载该 DLL。完整 GPU 接线和页面仍留在后续阶段。

## 保存骨架

foundation/host/save_files.gd 只通过显式目录创建，request() 接收本次 payload 快照，poll() 回收写入结果，dirty()/close() 提供状态。保留实际保存需要的写入失败处理、flush/回读、checksum、A/B 槽与主备指针保护；测试专用故障注入已移除。没有默认个人存档路径。保存层不接收配置身份参数，也不写入或匹配配置哈希；文件 checksum 和 payloadHash 继续只校验保存数据的完整性。


## 唯一保留的正确性测试

`foundation/tests/amount_value_tests.cpp` 直接包含 `amount_value.hpp`，不依赖 Godot、Excel、配置或保存设施。它覆盖大数四则运算、幂、等比和、取整、编码范围及非法输入边界；含 0–10000 整数的 floor/ceil 一致性回归。必须启用 assert，不使用 `-DNDEBUG`。

```powershell
& '<C++编译器>' -std=c++17 -O1 -static foundation/tests/amount_value_tests.cpp -o "$env:TEMP/space-idle-amount.exe"
if ($LASTEXITCODE -eq 0) { & "$env:TEMP/space-idle-amount.exe" }
```

不保留阶段配置/保存测试、测试 Excel、无界面工程、runner 或验证记录。整体玩法、游戏中的配置读取、Godot 绑定运行和保存恢复行为均留待架构完成后整体测试。


## 第二阶段运行入口与职责

在本目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File addons/native_battle/build_native.ps1
powershell -ExecutionPolicy Bypass -File run_game.ps1
```

启动脚本先按原路线将 Excel 导入为 JSON，再运行正常 Godot 主场景；原生 DLL 与 GDExtension 清单仍生成在显式 D 盘构建目录。它是游戏启动入口，不是测试 runner。编译检查不会执行该启动脚本。

`GameSession` 拥有航程、固定步余量、钱包和可领取掉落；直接调用 `combat_setup.gd`、`systems/equipment.gd` 与 `systems/economy.gd` 的普通函数。它只初始化 native 核一次，随后用 `start_wave/finish_wave/begin_retreat/finish_retreat/advance/take_results` 推进。非终波合法旧弹体继续推进；终波由核清攻击，Session 强制按自动口径收物，再等待/驻守或进入下一关。跨关撤退、暂停原因、未执行固定步余量由 Session 保管。

核内生命、盾、攻击、掉落和损伤统计统一使用共享 C++ Amount；边界金额使用 Amount 生成的十进制文本，钱包通过同一 Godot 绑定使用它。`evaluate_module` 的预览入口与执行共用同一个 C++ 实现，历史保持 int64；防具模块损伤是唯一生命权威，合计盾/甲为只读投影，容量变化和恢复不再反向依赖另一份合计状态；静态装备函数只计算到 charged_base，不重算熟练/适应。

纯几何函数位于 `scripts/ship_geometry_convention.gd`，不读 UI 或动画状态。普通编队的体型/中央泊位排序沿用基线纯位置算法；坐标与原尺寸参数迁入 `battle_geometry.xlsx`。规范舰体静态图片的 alpha 轮廓生成逻辑凸包，同一组包络既交给 native 接触计算，也交给最小入口绘制。`game_rules.xlsx` 保存本阶段航行、撤退及掉落期限。现有其他 Excel 内容未改动，导入器仍不计算任何 Amount。

`src/main.gd` 负责一次性的 native 显示模式选择、帧调用、只读显示和输入命令。空格暂停，G 切换当前战点驻守，点击掉落手动领取；到期和终波强制领取使用自动损耗规则，普通碎片不套用资源的自动损耗。现有 native retained/GPU 数据路径继续保留，表现代码不再访问旧 Game 或修改核显示模式；完整 GPU、配装/升级操作、强化分支/传说补齐、其他成长系统、长期保存和完整页面按后续阶段接入。

本阶段只执行 C++/GDScript 编译检查及既有独立 Amount 正确性测试；不建立或运行配置/保存/战斗测试工程。游戏运行、场景切换、点击领取及 GPU 行为尚未执行验证。

第二阶段前轮实现修正：离港现实等待保留积压游戏步；新波回收死亡演员，并复用没有合法在途载体引用的敌武器槽，旧载体保留原槽，目标与来源以完整代际区分；派生连发不再增加规范攻击历史。敌炮与激光使用和玩家绘制相同的舰体凸包进行线段接触判定，导弹仍按既定命中半径检测。设计与配置尚未给出独立于舰体的盾外形或外扩量，本轮未自行增加该规则。

撤回此前“已通过双审及交叉复审”的交付表述：此前仅有实现方启动的子代理检查，不代表父级与指定 astra 的正式审核通过。`75adb6e7` 已被父级退回；本轮修正后仍需交父级及指定 astra 审核，不能据编译结果宣布阶段验收通过。

本轮返工将一组花括号中的掉落按分号拆为多项，再按逗号解析资源、数量与概率。领取只保留单调 DropId 登记游标和未领取集合：重复登记旧 ID 被游标拒绝，已领取物从集合移除，重复领取无效，不累积永久已领字典。该游标对应本会话同步、按生成顺序读取的 native 结果流。

`CombatSetup` 仅接收本次组装需要的普通数据参数，不持有或回读整个 Session，也不调用其解锁方法；Session 预先计算解锁后的抽签次数并传入。表现的完整弹体读取接口不再切换压缩模式；需要兼容完整数组的入口必须显式选择非压缩模式，压缩载体尚在时完整数组读取返回失败。推进按武器、连发、离管与光束到期时刻切段，同刻先恢复及延期结算，再按来源槽序处理出生（即时炮在其出生调用内命中），随后处理已有光束跳和飞行接触。

后续返工把已有光束跳与飞行推进收拢到同一个接触队列。同刻按我方普通槽、敌方出生时冻结的来源槽及武器槽、载体生成序排序；活动数组的交换回收不再决定结算顺序。每项执行前重新检查载体代际及目标状态，其命中和合法局部衍生完成后再处理下一项。

宿主读取正式 `config.autoGenRes` 的间隔、资源、基础数量及移动速度，在航行、战斗、清关等待、驻守等待和撤退中累计生成时间；离港和暂停不推进。数量按当前战点资源倍率用 Amount 计算并向上取整，从逻辑顶部向玩家纵坐标移动，到达后自动领取；手动和终波强制领取仍调用同一入账函数。移动物不使用普通死亡掉落的 5 秒自动领取期限，收入样本标记为 `timed_drop`。

待领取集合使用 `native:<DropId>` 与 `timed:<宿主序号>` 分域；native 登记游标只消费死亡结果流，宿主生成序号单独递增，领取完成后删除对应待领项。两域都不保留永久已领取集合，不能因为另一域的序号更大而漏登记。

`game_rules.xlsx` 追加反应装甲的齐射窗口 `0.16`、连续窗口 `2.2`、最多层数 `3`、每层减伤 `0.2`；`battle_geometry.xlsx` 追加既有弹体回收边界 `x=-32..604`、`y=-32..776` 及定时资源顶部纵坐标 `0`。既有数值未重平衡，native 从组装描述读取这些字段。本轮仍只有编译和既有 Amount 测试，未运行战斗、定时物或领取行为测试，正式审核待父级及指定 astra 完成。
