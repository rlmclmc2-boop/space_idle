# 炮台放大：完整战场原尺寸复核

先看 [最小舰体磁轨](Frigate-cannon-battle.png)、[最小舰体导弹](Frigate-missile-battle.png)、[第五档脉冲](Heavy_Battleship-laser-battle.png)。[同窗口放大前](before/Heavy_Battleship-laser-battle.png) / [放大后](Heavy_Battleship-laser-battle.png) 保留作直接比较。

**20组实际战斗图、40张转向检查图，全部1372×883完整窗口PNG，无裁切、拼贴或放大。** 原窗口设置为1373×883，Godot保持原纵横比后实际framebuffer为1372×883。场景为真实 `main.tscn`，每组实际开火和命中后取图；不使用局部预览替代。

每组在隔离内存档配置该舰体与满槽同类武器，保持同一窗口。转向图在真实战斗取图后暂停，清理仅该夹具中的飞行/反馈并转至左右60°，用于检查空间遮挡，不冒充真实战斗转向瞬间。每组开火/命中计数及投影尺寸见同名JSON与TXT。

| 舰体与武器 | 实际战斗完整原图 | 暂停转向完整原图 | 当前朝向矩形投影宽×高 px |
|---|---|---|---|
| Frigate · 磁轨 | [原尺寸战场](Frigate-cannon-battle.png) | [−60°](Frigate-cannon-turn-60.png) / [+60°](Frigate-cannon-turn60.png) | 39–39 × 50–50 |
| Frigate · 导弹 | [原尺寸战场](Frigate-missile-battle.png) | [−60°](Frigate-missile-turn-60.png) / [+60°](Frigate-missile-turn60.png) | 34–34 × 37–37 |
| Frigate · 脉冲 | [原尺寸战场](Frigate-laser-battle.png) | [−60°](Frigate-laser-turn-60.png) / [+60°](Frigate-laser-turn60.png) | 40–40 × 45–45 |
| Frigate · 持续光束 | [原尺寸战场](Frigate-longLaser-battle.png) | [−60°](Frigate-longLaser-turn-60.png) / [+60°](Frigate-longLaser-turn60.png) | 35–35 × 45–45 |
| Destroyer · 磁轨 | [原尺寸战场](Destroyer-cannon-battle.png) | [−60°](Destroyer-cannon-turn-60.png) / [+60°](Destroyer-cannon-turn60.png) | 42–46 × 54–57 |
| Destroyer · 导弹 | [原尺寸战场](Destroyer-missile-battle.png) | [−60°](Destroyer-missile-turn-60.png) / [+60°](Destroyer-missile-turn60.png) | 40–43 × 42–45 |
| Destroyer · 脉冲 | [原尺寸战场](Destroyer-laser-battle.png) | [−60°](Destroyer-laser-turn-60.png) / [+60°](Destroyer-laser-turn60.png) | 40–44 × 46–49 |
| Destroyer · 持续光束 | [原尺寸战场](Destroyer-longLaser-battle.png) | [−60°](Destroyer-longLaser-turn-60.png) / [+60°](Destroyer-longLaser-turn60.png) | 44–47 × 51–53 |
| Cruiser · 磁轨 | [原尺寸战场](Cruiser-cannon-battle.png) | [−60°](Cruiser-cannon-turn-60.png) / [+60°](Cruiser-cannon-turn60.png) | 49–54 × 66–69 |
| Cruiser · 导弹 | [原尺寸战场](Cruiser-missile-battle.png) | [−60°](Cruiser-missile-turn-60.png) / [+60°](Cruiser-missile-turn60.png) | 56–62 × 59–63 |
| Cruiser · 脉冲 | [原尺寸战场](Cruiser-laser-battle.png) | [−60°](Cruiser-laser-turn-60.png) / [+60°](Cruiser-laser-turn60.png) | 60–67 × 66–71 |
| Cruiser · 持续光束 | [原尺寸战场](Cruiser-longLaser-battle.png) | [−60°](Cruiser-longLaser-turn-60.png) / [+60°](Cruiser-longLaser-turn60.png) | 54–61 × 65–69 |
| Battleship · 磁轨 | [原尺寸战场](Battleship-cannon-battle.png) | [−60°](Battleship-cannon-turn-60.png) / [+60°](Battleship-cannon-turn60.png) | 49–49 × 68–68 |
| Battleship · 导弹 | [原尺寸战场](Battleship-missile-battle.png) | [−60°](Battleship-missile-turn-60.png) / [+60°](Battleship-missile-turn60.png) | 49–49 × 53–53 |
| Battleship · 脉冲 | [原尺寸战场](Battleship-laser-battle.png) | [−60°](Battleship-laser-turn-60.png) / [+60°](Battleship-laser-turn60.png) | 54–64 × 62–70 |
| Battleship · 持续光束 | [原尺寸战场](Battleship-longLaser-battle.png) | [−60°](Battleship-longLaser-turn-60.png) / [+60°](Battleship-longLaser-turn60.png) | 59–67 × 70–74 |
| Heavy_Battleship · 磁轨 | [原尺寸战场](Heavy_Battleship-cannon-battle.png) | [−60°](Heavy_Battleship-cannon-turn-60.png) / [+60°](Heavy_Battleship-cannon-turn60.png) | 51–66 × 70–79 |
| Heavy_Battleship · 导弹 | [原尺寸战场](Heavy_Battleship-missile-battle.png) | [−60°](Heavy_Battleship-missile-turn-60.png) / [+60°](Heavy_Battleship-missile-turn60.png) | 49–49 × 53–53 |
| Heavy_Battleship · 脉冲 | [原尺寸战场](Heavy_Battleship-laser-battle.png) | [−60°](Heavy_Battleship-laser-turn-60.png) / [+60°](Heavy_Battleship-laser-turn60.png) | 53–65 × 61–71 |
| Heavy_Battleship · 持续光束 | [原尺寸战场](Heavy_Battleship-longLaser-battle.png) | [−60°](Heavy_Battleship-longLaser-turn-60.png) / [+60°](Heavy_Battleship-longLaser-turn60.png) | 58–69 × 69–75 |

## 改动及必要检查

- 磁轨/导弹/脉冲显示倍率为1.85/1.85/1.9，较窄的持续光束炮为2.2；按安装座附近空间放大，不以旧炮口距离约束整张图。导弹取消原X/Z压缩，四种图均保留源图纵横比。
- 基座中心仍是固定旋转轴。独立 `VisualPort` 按新图比例定义视觉炮口；原 `Muzzle/Muzzle02` 与数值发射提供器保持原位。磁轨数值几何保留旧坐标处理，避免视觉放大改变数值射线。
- 20组均有实际开火和命中。贴图基座/固定底座/旋转轴90次检查通过，最大误差0.000338801px；原显示/逻辑数值炮口专项最大误差0.000068240px。
- 五档×四种满槽配装×−60/0/+60度共480组相邻关系检查：炮台不透明部分未覆盖其他炮台的底座中心。直接采样实际贴图alpha与真实变换；原图保留供审阅部分轮廓遮挡与辨识。
- 尺寸表是可见矩形投影，随朝向改变，不等于基座宽度。引擎纹理接口报告964×620逻辑尺寸，PNG实际1372×883；投影值按二者比值统一到PNG像素。原逻辑测量和换算比例均保留于JSON，截图未处理。
- 射速、弹速、伤害、目标、命中、碰撞、数值几何、配置表及原生源码/DLL均未修改或重编。入口 `test/test_turret_full_battle.gd` 与 `test/test_turret_clearance.gd`。

## 剩余缺口

**本轮是Godot 4.6.3 GDS回退完整战场；不能称正式4.7原生GPU整场通过。** 当前无4.7引擎及可加载的正式原生组件。原生保留GPU事件仍持有数值发射位置，扩大后的独立视觉炮口映射尚需正式路径复核及必要适配；本轮GDS截图不证明该映射已完成。未为补图扩展构建或改变战斗逻辑。原局部示意图已标尺寸否决，本目录供原尺寸审阅，不合main。
