# 公共壳制作交接


制作目标与完成标准见[规范](../../../game-design/13-art-interaction.md)。

## 固定组合与接口

运行源`design/clear-zone-host@9838e1e77a60f31070bc472e9ed7ca6eca4161ef`，已接反应堆R12`0bc17ae48107972c88a84069cf5221bf5c1cbb0f`的30个运行件及main装备`e845ca58afd39184c3d4c5743021480e393adf74`。

公共层使用本分支`main.gd`、`ZoneShell`、`BridgeTheme`、`PlayerText.resource_number`和资源/导航状态；操作材质由`operation_plate/operation_button/apply_operation_button/apply_operation_select`、`control-materials.png`、`stepper-down.svg`提供。数量、费用和透明图标按13消费。

1440×900时模块x=0..808，顶轨下从y=65接续；导航x=808..855.875，战斗有效投影x=855.875..1392.125、scale0.9375。公共宿主维护退出、显隐、焦点、导航、资源及战斗输入关系。

反应堆接入保持`_init(owner,inputs,payment,publish,can_pay)`、`bind_presentation`、`bind_purchase_quote`和808×835舞台；五处UI源与`reactor_ports.json`及对应设备/管路/shader按固定源取入，坐标统一由PortContract提供。模块内部资产目标见[M3](../../../game-design/art/modules/reactor.md)。

## 下一步与必要依赖

按当前组合的真实完整页面与动态判断公共边界、控件状态和跨页材质关系；模块新修订由原组交固定源后精确同步。星球等待新的完整主体候选及接替交付。公共组合的完成标准为13的V0及本次涉及的跨页操作；模块内部标准由各M/V维护。

## 已有覆盖

作者自查，固定组合`9838e1e7`：Godot4.7.2导入与主入口check-only成功；1440×900装备、R12四路零载、单路真零及返回装备完整图；受控四路25%/核心100%、正常1×8秒短片（采屏12Hz，96帧）。记录墙钟约11.046秒、游戏时间约10.217秒。当前组合尚无独立整页/用户验收结论。

当前授权为制作组合，合main另按验收授权进行。

同一运行源另有作者检查的2路/3路零载和带载四张1440×900完整图：2路各50%，3路34%/33%/33%，核心100%。覆盖固定受控状态下的行数、标签、滑杆、凹槽和承载边界。
