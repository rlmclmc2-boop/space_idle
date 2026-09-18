# STATUS

## CURRENT

- DONE：新增“一键合成”：自动连续升级、跳过已装/锁定/禁用/满级宝石、碎片补位继续参与、一次保存及背包通知、异常回滚、合并最终产物及短高亮；无结果显示指定提示。
- CHANGED：game.gd共用单次/批量合成和碎片补位实现，配方与属性规则不变；jewel_panel.gd增加按钮与结果展示，保护标记不计入可合成提示。只更新变化宝石及详情，保留其他格子/装备控件与初始化构建；新增批量领域专项，扩展UI专项，并将旧UI测试写死的1000碎片成本改为读取当前100配置。未修改正式配置、存档格式、战斗流程或玩家数据。
- VERIFY：隔离test_jewel_combine_all 49、test_jewel_ui 66、test_jewel_fragments 22、test_jewels 110，共247项、0失败，退出码0；脚本编译和git diff --check通过。覆盖连锁、合并统计、保护状态、配置边界、重复点击、满包补位、无效数据不扣除、已报告保存失败的profile/serial/RNG回滚、重试/读档、单次通知与局部控件保留。结果页截图已核对。UI测试仍有此前独立复现的Godot弹窗焦点日志及系统证书警告，未影响断言。
- EVIDENCE：../../test/work/test_jewel_combine_all-8uvx7sxp/、../../test/work/test_jewel_ui-tioug413/、../../test/work/test_jewel_fragments-t6m1mord/、../../test/work/test_jewels-acd05rqu/；结果截图在UI副本space-battleship/.runtime/jewel-bulk-result.png。
- PARALLEL：保留本轮期间另一任务完成的持续光束首次发射单次双发判定，未触碰对应逻辑；其原记录验证为test_long_laser 83项及test_jewels 110项通过，证据../../test/work/test_long_laser-i20n4nfa/与../../test/work/beam-repeat-once-jewels.log。
- NEXT：本轮无待办；未新增宝石锁定界面/持久化标记。未报告的底层存档故障仍按U-008另行处理。

## DONE

- 已具备自动战斗、驻守/跃迁、资源与离线结算、独立槽位装备/换舰、科学家研究、充能和炼铁炉。
- 已具备宝石/碎片/合成/分解/镶嵌与战斗效果；游戏UI、QA、关卡编辑器、分表投影及专项测试；装备等级/玩家冷却以槽位为权威，读取无隐式写入。

## KNOWN ISSUES

以下仅记录未解决事项；证据不等于设计批准，不能在其他任务中顺便修复。脚本简名位于scripts/，测试简名位于../test/，其余路径相对项目。

| ID | 问题与必要入口 |
|---|---|
| U-001 | 实验配置晋升与长期可迁移来源指纹协议未定；`tools/config_workbooks.py`。 |
| U-004 | 空unlock默认开放与startEquip、原equipment说明有歧义；`database.gd:unlock_level`。 |
| U-005 | 拾取/回退/换关默认时长、弹速换算、初始资源、保损/自动推进等实现补充尚未全部获策划确认；JSON.defaults、game.gd。 |
| U-006 | 最小/零伤害、跨盾取整、一级行抗性、同优先级索敌与拾取半径的设计适用范围待定；`game.gd:reduced_damage/hit_player`。 |
| U-007 | 资源/装备扩展与不同导入入口引用/重复ID校验未完整对齐；仍有五类装备、资源ID1/2及config参数映射限制，`tools/import_workbook.py`。 |
| U-008 | 非连续cleared、坏档/多实例共享档等风险未解决；`game.gd:load_progress/save_progress`。普通QA重启已拦截save_error，但不代表存档所有写入故障均可检测或恢复。 |
| U-009 | 品质、独立能源/建造/探索、独立关卡AI及全局结局未设计；范围问题，不自动创建模块。 |
| U-010 | Windows x64 单 EXE、固定版本模板与一键验证已完成；另一台干净 Windows 真机验收、其他平台导出及 CI 未完成；[操作说明](../README.md)。 |
| U-011 | 旧State/leave仍有消费者；敌方导弹未被编队引用且不套玩家齐射机制；`game.gd`、TEST_MAP，先核用途。 |
| U-012 | 总览!D17倍率示例2与线性1.9歧义仍在；`database.gd:ratio`，不得擅改舍入时机。 |
| U-013 | 内存规则夹具/满级通关不能证明真实初始数值成长平衡；[TEST_MAP](../../test/TEST_MAP.md)。 |
| U-017 | test_game仍混有旧安装/循环/配置假设，不能作整套规则基线；[测试入口](../../test/README.md)。 |
| U-018 | 旧总表缺techPointGet等当前字段，部分总表测试仍失败；`test_config_input_matrix.py`，不得猜默认值。 |
| U-019 | 提交后回滚自身失败可能留下半提交，Store备份也可能被清理；`atomic_batch`与输入矩阵故障观察。 |
| U-020 | incremental导入不复核并发目标/manifest，可能覆盖外部目标修改；Store.save拒绝但validate无最终复核；输入矩阵。 |
| U-022 | ship.xlsx的sameEquipmentLimit投影均为1，既有JSON五舰为1/2/2/3/3；本次装备任务保留原JSON舰船段，未裁决差异。后续全量读取配置可能应用分表值，需单独核实来源。 |

## NEXT

- 配置事务/并发与存档故障需独立任务；规则歧义交策划裁决，不自动修复。
- 跨平台发布与已测性能热点按需求另立任务；不继续本轮重构。
