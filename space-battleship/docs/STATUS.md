# STATUS

## CURRENT

- DONE：完成用户指定的六项高频性能修复；不改数值、战斗规则或 UI 结果。
- CHANGED：game 合并充能存档、短路活敌判断、提供弹体 serial 和模块数值失效事件；main 每次绘制复用弹体索引/位置/粒子预算；equipment_tab 分离结构、数值、资源可购买性和排序刷新；config_panel 隐藏时仅处理未完成工作。保留退出/关键节点立即保存，失败不清 save_dirty。
- VERIFY：save_boundaries 21、hot_paths 33、local_ui 70、module_ui 35、long_laser 83、journey_resume 28、weapon_fx 43、boss_projectile_clear 8、config_panel 14 项通过，共 435 项。QA 初次环境缺 lxml，改用已安装完整 Python 运行环境后通过。已核对 module_ui-titecwy2 装备截图和 weapon_fx-6_jj31lg 导弹截图。三轮隔离同场景探针中位数：装备空闲刷新 1823→2 μs，128 弹体更新 1862→490 μs，128 导弹/700 粒子战场绘制 110297→22119 μs；不等同整帧耗时。证据 ../../test/work/perf-fixes/，复用 test_hot_path_probe.gd。
- NEXT：本轮完成。

## DONE

- 已具备自动战斗、驻守/跃迁、资源与离线结算、独立模块成长/自由换装与换舰、科学家研究、充能和炼铁炉。
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
| U-023 | 旧 test_charge.gd 的解锁、敌实体和保存夹具及卡片接口未适配当前项目，在 UI 段之前即失败/超时；当前页面回归改走 test_charge_panel/test_local_ui/test_tab_unlocks。证据 test/work/test_charge-av25f3xw/test.log；迁移旧综合测试时不可修改游戏规则迁就断言。 |

## NEXT

- 配置事务/并发与存档故障需独立任务；规则歧义交策划裁决，不自动修复。
- 跨平台发布与已测性能热点按需求另立任务；不继续本轮重构。
