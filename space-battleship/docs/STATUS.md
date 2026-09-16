# STATUS

## CURRENT

- DONE：宝石/碎片/合成/满级分解/装备镶嵌/10种func效果与暴击已实现。正式参数读取当前config.xlsx和jewel.xlsx；用户执行中补充jewelCompose后已按原格式接入，未编辑Excel。30格容量、重复点击、同ID限制、卸装备/换舰回收、旧档默认值均有专项保护。
- CHANGED：scripts/game.gd、database.gd、main.gd、新增jewel_panel.gd；tools/import_workbook.py、config_workbooks.py支持jewel分表；data/game_data.json仅新增jewel段及宝石config字段，已比较确认其他投影和既有参数不变。规则/定位更新在PROJECT、ARCHITECTURE；测试路由在../../test/README.md。
- VERIFY：隔离runner通过宝石99项、宝石真实点击/UI19项、原局部UI33项、页签14项、装备状态1114项、弹道19项、抗性21项、末波清弹8项、存档16项，共1343项，另宝石分表投影/重复ID/发现/缓存验证通过。没有新增脚本/runtime错误；引擎环境既有根证书读取提示仍出现。Python配置测试使用项目QA同款bundled Python（系统Python缺lxml）。
- EVIDENCE：../../test/work/test_jewels-uppk29o5/；test_jewel_ui-y3pg1ubn/space-battleship/.runtime/jewel-workshop.png与jewel-sockets.png（其余路径同在../../test/work/）；test_local_ui-eifu872a/、test_tab_unlocks-hna0oun3/、test_state_ownership-i5rw4u91/、test_projectile_lifecycle-lphx1jlt/、test_target_resistance-d5ijmwv_/、test_boss_projectile_clear-e4ncql4c/、test_save_boundaries-f8vxke9_/、test_jewel_import-16rejk3v/。已核对真实鼠标操作和工坊/镶嵌截图。
- UI范围：背包始终复用30个格按钮；合成/分解/拾取/排序更新变化内容，镶嵌额外更新对应装备卡；插槽数量变化只增减插槽按钮。隐藏面板停刷，暂停静止无属性写入或额外绘制，无普通操作调用build_ui。完整构建仍仅用于初始化/显式重置。
- NEXT：通过项目既有“大重启”入口加载代码；达到配置门槛后进入宝石页，装备卡“镶嵌”管理插槽。无需操作正式玩家存档。

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
