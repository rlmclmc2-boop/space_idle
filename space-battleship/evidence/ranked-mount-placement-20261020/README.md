# 四舰精英/BOSS主装甲挂点重排

基准3198fb54。只改data/ship_weapon_visuals.json中未启用的enemy_weapon_interface四舰精英/BOSS点位，补carrier_group和carrier_region作者标记；normal/default/count、active ships硬点/slot_map不变。所有生产scripts、game_data、Excel、静态PNG及dev/qa/ranked_turret_preview.gd逐字节未变。生产没有接口消费者，不改变任何装备数、伤害、冷却、倍率或编队。接口区域不是碰撞体、编队占位或新容量规则。

| 舰体 | 新的主承载面布局 | 精英2炮台 前→后 | BOSS4炮台 前→后 |
|---|---|---|---|
| 锚定 | 精英左右主翼各1；BOSS左右主翼宽装甲面各2，沿翼横向成组，离开背后外挂和下方引擎 | [前](before/anchor-elite.png) → [后](after/anchor-elite.png) | [前](before/anchor-boss.png) → [后](after/anchor-boss.png) |
| 反应 | 精英移入两块后主装甲内侧宽面；BOSS两块后甲各1、前方主甲并列2，避开中央小核心与三叶间隙 | [前](before/reactive-elite.png) → [后](after/reactive-elite.png) | [前](before/reactive-boss.png) → [后](after/reactive-boss.png) |
| 护盾 | 精英左右主弧下部宽甲各1；BOSS左右主弧上/下甲各1，沿弧分段，避中央核心和外围发射外挂 | [前](before/shielded-elite.png) → [后](after/shielded-elite.png) | [前](before/shielded-boss.png) → [后](after/shielded-boss.png) |
| 指挥 | 精英左右主舰舱前装甲各1；BOSS每侧舰舱前/后白灰甲各1，夹开中部发光窗，避中央指挥脊和推进器 | [前](before/command-elite.png) → [后](after/command-elite.png) | [前](before/command-boss.png) → [后](after/command-boss.png) |

所有图为实际main.tscn默认1372×883原始窗口，没有裁切/放大/拼图。before精确保留3198fb54的PNG；after相同save-disabled/held-health隔离夹具，保留显式2/4独立装备与普通1武器护航。静态舰体、位置、model width、body AABB、展示框逐字段与基准一致；炮台样式和12.453–18.367像素底座大小原样保留。只移动预留武器位。血盾仍居中且在预留框内；隔离保护轮廓会随QA武器位置重新计算其可见顶部。

940专项检查0失败，包含24个炮台×3种实际瞄准角度。测试通过既有绘制上下文的目标位置输入调用真实enemy_component_pose，在-55°/0°/+55°钳位转向后，把实际paint transform下的底座及炮身轮廓反变换到PNG。32方向×4径向采样和炮身四角必须落在对应主装甲carrier区域、alpha>=0.9、不得覆盖橙色核心/引擎发光面；轴心需在白灰装甲上，底座两两不重叠且处于前景层。区域按主翼、主甲块、主弧、主舰舱分组，不用透明大外接框作为安装面。转向后底座必须仍以live pivot为中心。保持原身份/只读接口/中心/留白/native view检查。

sprite空间规划同时核对了完整圆底座不落透明区域或橙色发光像素；圆底座包络包含炮身，因此旋转不会将其甩到外挂/核心。实际aim最大误差与底座重心误差见summary.json；raw各角度记录见after.json。本次不改变原数值geometry来源/生产武器硬点；QA重定位的muzzle随其挂点同步移动，不把它宣称为生产接入。

静态资产/接口冻结检查通过；未修改攻击链/生产战斗，不扩展伤害组合/性能/全量测试。Linux Godot4.6.3 llvmpipe/GDS，native view函数级验证，未声称native整场。编队重设计仍暂停，自然密度不在隔离展示验收内。

复现：python test/check_enemy_ranked_assets.py；隔离工程图形运行test_enemy_ranked_art.gd，RANKED_OUTPUT指定test/work本次目录。新增carrier字段只供作者/预览检查，没有生产应用。独立候选供父审，不合main，无执行阻塞。
