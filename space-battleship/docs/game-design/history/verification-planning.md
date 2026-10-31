# 历史测试设施与实施顺序提案（不生效）

固定来源：[main@e3b38d7b 的 07 原文](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/docs/game-design/07-verification.md)。此页保留设施设想与原实施顺序，不是当前命令、既有设施或恢复授权。规则场景仍见 [07](../07-verification.md)；当前命令见 [foundation](../../../foundation/README.md)。

## 1. 一套规则，一种场景运行器

生产Excel和测试Excel通过同一个ConfigCompiler生成相同ConfigBundle；测试不复制生产表、不在用例代码中构造一套隐藏平衡数据。测试工作簿显式提供所需最小定义，允许专门小数值以便手算，但必须经过同一类型/引用/拓扑校验。每个测试数据包自足，不能运行时从正式大表补缺失行。

`tests/excel/`规划分包：`core_rules.xlsx`（最小资源/装备/关卡/敌人）、`combat_cases.xlsx`、`progression_cases.xlsx`、`hyperspace_cases.xlsx`、`persistence_cases.xlsx`。这些为测试独立权威；schema与生产共享，内容完全独立。不要求本次文档任务创建这些xlsx。

测试用例表：

| 表 | 列与含义 |
|---|---|
| case | case_id、config_fixture、seed、duration、comparison_mode |
| initial | case_id、entity_kind、entity_id、field_id、typed_value；field_id从测试装配允许表，不任意执行路径 |
| actions | case_id、sequence、at_game_time、method、typed_args；method只允许具名session方法 |
| clock_segments | case_id、order、real_dt、focus、pause_action、speed；专项测试现实/游戏转换 |
| expected_state | case_id、checkpoint、owner、field_id、value、tolerance_kind、tolerance |
| expected_events | case_id、sequence、type、source_id、target_id、amount、count |
| expected_errors | case_id、operation、reason、must_leave_unchanged |
| fault_schedule | case_id、file_operation、boundary、fault_kind；注入保存写入/导入读取故障 |

运行命令规划为`godot --headless --path . --script tests/run_cases.gd -- --fixture <manifest> --case <id>`。运行器先调用同一Excel编译器，加载小型ConfigBundle，构造真实GameSession和实际SpaceCombatKernel；按actions时刻直接调用具名方法，用clock_segments传入real_dt/focus/speed，推进真实frame。它不创建游戏主场景、显示窗口或GPU图形对象；逻辑几何来自fixture所引用的同一几何函数。native GDExtension是此运行的必需依赖，缺失即启动失败，不改跑另一套战斗。

测试保存使用隔离临时目录；SaveFiles在指定文件操作位置注入错误，不需要一套模拟业务存储。UTC值由加载函数参数显式提供，战斗/世界/改造随机种子由fixture提供，与新档初始化相同。运行器读取完成步的宿主状态、核只读视图和take_results所生成的观察记录，与Excel期望比较；观察记录不再驱动战斗。失败输出首个分歧时间、规则ID、Excel坐标及局部输入/期望。

Amount和几何纯函数可直接在native测试程序中调用同一C++函数；不把伤害重新写成Python/GDScript oracle。配置编译器的类型/引用测试可独立运行Python，无需Godot。

期望值不能调用生产公式生成，否则只是自证。可手算例子写在Excel；复杂随机效果使用固定seed与显式规则事件期望，概率正确性另用多seed统计区间；不在运行器重写随机效果生成逻辑。常规测试只用小矩阵；新增规则才添加对应边界，避免每次文档改动跑整游戏。

## 5. 实施顺序

以下只定义用户批准后的落地顺序，本次不改代码。

1. 建立独立Excel编译、共享C++ Amount/Godot绑定、最小fixture及native headless入口；保存文件骨架同时建立。
2. 让GameSession经Battle接现有native核，完成静态装备输入/历史动态层、四武器、命中、波次、航行与掉落闭环；Campaign与表现层只调用Battle具名接口，从第一步战斗就使用native。
3. 在同一核补齐02强化和04传说，接宿主反应炉、AI、配装、伤害统计和现有GPU表现。
4. 加入船员、星球、星系及其直接完成函数；各进度加入保存，测试占用、收入峰值、容量和余时。
5. 加入超空间编队/返回、挂机凭据、仓库/改造/挂设/过滤/预设，与native的手动模式和无人机动态状态连接。
6. 完成长期字段保存及加载新战场，完成导入、重铸、备份和磁盘失败场景；接完整页面、移除旧业务/测试与依赖游戏的编辑器入口。

每一阶段按正文已经确定的玩法和对应fixture实现。纯表现、静态资产和现有native快路径按05连接，不建立临时长期保留的另一套战斗。
