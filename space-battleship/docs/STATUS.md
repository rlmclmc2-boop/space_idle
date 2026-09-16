# STATUS

## CURRENT

- DONE：处理战点切换时星空拖尾整批瞬时出现/消失造成的背景亮度跳变，改为星空层自身的平滑过渡，暂停冻结；确认宝石背包只有显式操作才打开，创建即隐藏，未解锁时拒绝open，拾取/状态刷新不打开。
- CHANGED：scripts/main.gd增加star_streak视觉过渡且星空绘制只依赖实际显示参数；scripts/jewel_panel.gd补初始化隐藏与open门槛；新增../../test/test_battle_transition_ui.gd。规则/定位/测试路由更新在PROJECT、ARCHITECTURE及../../test/README.md；未动游戏数值、配置或正式玩家存档。
- VERIFY：战点切换13项、局部UI46项、宝石UI26项全部通过，退出码0。战点切换同一时刻背景取样区像素完全一致，随后拖尾逐渐进入/退出；静态背景/chrome/页签不重绘、不重建，暂停星空不重绘；宝石关闭状态在拾取/波次/通关后保持。已核对修复前后截图与diff；仅有引擎既有证书提示。
- EVIDENCE：修复前../../test/work/test_battle_transition_ui-zw5abg55/；修复后../../test/work/test_battle_transition_ui-r7tap57d/、../../test/work/test_local_ui-hy08eh1f/、../../test/work/test_jewel_ui-r5by9y2i/。切换截图在对应space-battleship/.runtime/transition-*.png。
- NEXT：游戏“大重启”加载修复，观察战点间巡航背景过渡。证据定位到星空拖尾的瞬时切换；没有观察到整屏UI重建。

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
