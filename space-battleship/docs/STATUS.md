# STATUS

## CURRENT

- DONE：导航刷新已按实际显示依赖收窄，不再遍历ui子节点统一设置可见性；保留宝石面板自主开关修复。音效仅更新自身文字，驻守仅更新自身文字/禁用，死亡设置仅改菜单勾选；前进与战斗显示结果相同时不进入属性更新。
- CHANGED：scripts/main.gd明确帮助/解锁可见性关联组，使用所属控件的局部依赖快照；跃迁目标改变只select，通关列表变化只增减选项/修正变化项，不clear重建。../../test/test_local_ui.gd扩展导航属性检查与实际写入区分；ARCHITECTURE记录入口和快照归属。未改变游戏规则、配置或正式玩家存档。
- VERIFY：隔离test_local_ui.gd 46项与test_jewel_ui.gd 26项通过，退出码均0。覆盖真实点击、仅目标属性检查、无关层不重绘、任意兄弟控件不被导航显示、跃迁选项身份保留、静止不进入属性setter、UI实例保留及宝石关闭后不重开。已核对帮助与宝石界面截图，git diff --check通过；仅有引擎既有根证书提示。
- EVIDENCE：../../test/work/test_local_ui-3cv3awwg/；../../test/work/test_jewel_ui-rvbcpeh8/。截图位于各自space-battleship/.runtime/。
- NEXT：游戏“大重启”加载最新代码。帮助/解锁仍更新其实际关联控件；初始化/显式重置仍允许完整构建，普通导航操作不重建UI。

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
| U-010 | 跨平台发布、依赖锁定、导出预设/CI与可迁移启动未完成；project.godot、启动脚本、[操作说明](../README.md)。 |
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
