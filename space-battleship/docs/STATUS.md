# STATUS

## CURRENT

- DONE：武器/防御升级卡统一为深蓝渐变、青蓝高亮、金属切角界面；左侧图标、中部名称/精确等级/属性对比、右侧三级按钮、底部状态及进度条。卡片宽664、高112，保留战场和既有横向滚动。
- CHANGED：main.gd复用现有卡片和升级入口，新增局部SVG皮肤及防御图标；武器裁去既有图标透明留白。伤害/护盾/装甲和CD/同类型减伤展示当前→下级，满级展示相同值及标记。武器进度沿用冷却，防御进度显示等级，悬停区分语义。升级按槽更新数值、详情与等级进度；资源仅影响消费按钮；静态皮肤无逐帧重绘。没有修改配置、战斗规则或正式玩家数据。
- VERIFY：隔离test_upgrade_ui 21项、test_local_ui 70项，合计91项、0失败；真实点击、动态MAX、无资源禁用、长名称/属性宽度、两页预览、局部控件身份/写入和隐藏恢复通过；已核对实际武器/防御截图，git diff --check通过。Godot系统证书警告未影响测试。
- EVIDENCE：../../test/work/test_upgrade_ui-figaxms1/space-battleship/.runtime/equipment-weapons.png、equipment-defence.png、equipment-disabled.png；局部回归路径见../../test/work/equipment-local-run.log。
- NEXT：本轮无待办；维持原有初建/显式重置和实际槽位变化的最小卡片替换。更多槽位仍使用横向滚动。

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
