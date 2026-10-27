# 窗口、显示环境与战场输入边界：只读依据

封存日期：2026-10-27（UTC）。代码基线：`main@96b1e82a7a2a1e5e1247319a56c45f515078575a`。

范围：依授权，只读核实当前执行机显示环境、现行窗口配置及战场显示与输入/计算的关系，供完整前端交付规划引用。本报告不是设计规范，不批准任何布局方向或目标尺寸，也不改变既有 UI 未通过状态。没有移动窗口、启动游戏或新测试、修改配置或实现。

## 1. 执行机测量事实

以下是本次授权执行机的环境快照，**不等于用户已确定的目标窗口、支持分辨率或验收尺寸**。

通过 Windows `EnumDisplayMonitors` / `GetMonitorInfo` / `GetScaleFactorForMonitor` 只读获取；枚举成功，缩放查询返回成功。当前进程 SessionId 为 1，`SM_REMOTESESSION` 为 false。

| 设备 | 主屏 | 显示器矩形（虚拟桌面坐标） | 分辨率 | 工作区矩形 | 可用工作区 | 配置缩放 |
| --- | --- | --- | --- | --- | --- | --- |
| `\\.\DISPLAY2` | 是 | `(0,0)–(1920,1080)` | 1920×1080 | `(0,0)–(1920,1040)` | 1920×1040 | 100% |
| `\\.\DISPLAY1` | 否 | `(1920,-109)–(3840,1091)` | 1920×1200 | `(1920,-109)–(3840,1051)` | 1920×1160 | 100% |

测量线程的 DPI awareness 为 0；两屏配置缩放均为 100%。此记录没有测量游戏窗口的每窗口 DPI 行为，不外推到其他缩放环境。

进程列表未发现名称匹配 Godot 的运行进程。本次因此没有测得游戏客户区、窗口外框、装饰占用或实际画面拉伸。没有为补测而启动游戏。显示器 1920×1080 并不意味着普通窗口可拥有同尺寸客户区；主屏工作区高度已是 1040，窗口装饰预算尚未测量。

## 2. 代码事实

下列链接均固定到上述代码基线；不以阶段1 HTML 原型或未合入实现替代现行游戏。

| 核实项 | 事实与来源 |
| --- | --- |
| 初始视口配置 | [`project.godot:9–11`](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/project.godot#L9-L11) 为 572×960，`canvas_items` 拉伸；该文件没有显式窗口尺寸覆盖、全屏模式或最小窗口尺寸设置。此处是配置值，不是实测窗口矩形。 |
| 正常启动参数 | [`run_game.ps1`](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/run_game.ps1) 正常启动使用 `--path`，没有额外分辨率或全屏覆盖。 |
| 整体内容缩放基准 | [`main.gd:89`](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/src/main.gd#L89) 与 154 将 `content_scale_size` 设为 `session.battle.view_size()`；[`battle.gd:139`](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/src/systems/battle.gd#L139) 读取战场几何宽高。主线尚无将桌面界面画布与战场显示区域分开的通用局部布局适配层。 |
| 战场逻辑配置 | [`battle_geometry.xlsx`](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/config_excel/battle_geometry.xlsx) 的 `battle_geometry` 表：`view_width=572`、`view_height=960`、`player_x=286`、`player_y=520`。本次用只读方式读取，没有发布或改写配置。 |
| 战场尺寸进入计算 | [`combat_setup.gd:36`](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/src/combat_setup.gd#L36) 把同一宽高作为 `battle_width/battle_height` 传入内核配置，不能把改它们一概视为纯前端调整。 |
| 舰体、炮口与命中共享几何 | [`ship_geometry_convention.gd::battle_geometry`](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/src/scripts/ship_geometry_convention.gd#L106) 生成舰体轮廓/位置；[`battle.gd:407–458`](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/src/systems/battle.gd#L407-L458) 计算实际武器姿态和炮口，同源端口送入数值与表现出生点，并向内核提交 ballistic geometry、武器挂点、玩家位置和轮廓。单改逻辑舰体尺寸/锚点可能影响命中与出射。 |
| 原生表现挂接 | [`battle_view.gd:57–90`](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/src/ui/battle_view.gd#L57-L90) 建立接触层、光束实例并传入 canvas RID。新的局部显示变换必须覆盖相应原生表现，不能只移动舰体纹理就声称完成适配。 |
| 拾取输入 | [`economy_view.gd:16`](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/src/ui/economy_view.gd#L16) 直接把 `event.position` 传给 `collect_at()`；[`economy.gd:157–162`](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/src/systems/economy.gd#L157-L162) 使用与掉落物位置的距离 ≤18 判定。18 是逻辑坐标单位，不是承诺的物理像素点击半径；目前没有战场局部平移/缩放的逆变换。 |

## 3. 下一轮布局的最小边界

1. 分别声明目标窗口客户区预算、界面画布及战场显示区域；本机测量和现行 572×960 均只是输入依据。仅桌面宽屏的阶段范围不等于必须全屏，也不自动确定具体目标分辨率。
2. 区分纯显示映射与真实战场几何变更。可规划在逻辑战场外施加一致的展示变换；改变战场宽高、玩家逻辑点、舰体逻辑比例或炮口锚点，可能改变玩法计算，需单独说明与审查，不能作为布局适配隐含执行。
3. 统一变换舰体、武器、弹体、光束、接触效果和掉落物等战场表现；将视口输入逆变换回战场逻辑坐标后再调用拾取接口。背景延展/裁切可另作前端资产处理，不能据此改变命中几何。具体适配层尚未实现或运行验证。
4. 视图显隐和布局不能控制 `Session.frame` 的战斗推进；伤害表现事件流仍由 BattleView 单一消费，新增 HUD/布局不能重复消费。该接口责任见[现行14共用契约](https://github.com/rlmclmc2-boop/space_idle/blob/96b1e82a7a2a1e5e1247319a56c45f515078575a/space-battleship/docs/game-design/14-ui-contracts.md)。

## 4. 尚未确定/验证

- 目标窗口、支持范围、全屏/窗口模式、最小客户区、界面画布与战场区域比例、缩放/裁切策略，均未由本次核实决定。
- 实际游戏窗口矩形、运行中的画面/输入变换、其他 DPI 环境尚未实测。本报告不声称新布局已通过实机验收。
- 本次封存仅新增此独立证据报告；不改实现、规范、原型、配置或已有审核结论，不合入 main。
