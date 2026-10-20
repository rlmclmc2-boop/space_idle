# 四舰八版炮台：对称、整齐、稳定

基准169890d1。本次按用户新优先级，以炮台点阵的对称/整齐/重心稳定为先；允许直接盖住装饰光，不再让点位因避光而分散。只调整未启用enemy_weapon_interface四舰精英/BOSS点位和相应主承载区域标记；normal/default/count、active ships硬点、生产脚本/装备/伤害/冷却/倍率/编队、全部PNG及可读性painter完全不变。

## 单舰炮台规则

精英：左右同高、等距的一对。锚定/护盾/指挥均在船体横向中线，反应舰落在两块面积较大的后主甲中心，同高成对。BOSS：四版全部采用相同左右列宽、相同前后行距的两列两排，四点算术重心严格位于舰体中心，不用前窄后宽或横向散点。各舰行距随装甲比例调整。这里的炮台两列两排不改变战舰展示尺寸（精英仍2×2、BOSS仍3×2），更不是编队重排。

| 舰体 | 精英前→后 | BOSS前→后 |
|---|---|---|
| 锚定 | [前](before/anchor-elite.png) → [后](after/anchor-elite.png) | [前](before/anchor-boss.png) → [后](after/anchor-boss.png) |
| 反应 | [前](before/reactive-elite.png) → [后](after/reactive-elite.png) | [前](before/reactive-boss.png) → [后](after/reactive-boss.png) |
| 护盾 | [前](before/shielded-elite.png) → [后](after/shielded-elite.png) | [前](before/shielded-boss.png) → [后](after/shielded-boss.png) |
| 指挥 | [前](before/command-elite.png) → [后](after/command-elite.png) | [前](before/command-boss.png) → [后](after/command-boss.png) |

全部实际main.tscn原始1372×883窗口，未裁切、放大、拼图。before从169890d1逐字节保存；after相同隔离QA：中央精英2/BOSS4炮台和两艘普通护航。save disabled、held health，交火后暂停清除瞬时弹道/浮字。舰体位置/尺寸/旋转后AABB、展示框、model width与before逐字段一致，已认可的炮台底座/轮廓/明暗样式逐字节未变，底座实际12.453–18.367像素不变。

## 验证及界限

996专项检查0失败。显式断言双炮同高/左右对称；四炮两列、两排、左右上下等距、重心为0。24炮台×-55/0/+55共72个真实瞄准函数姿态；实际paint transform下的圆底座、炮身四角反查主承载区域、alpha和边缘，仍要求不悬空/不越主体carrier、不互相重叠、位于前景层，保留原中心/血盾留白/native view等检查。独立alpha距离场核对所有完整圆底座均有不透明承载与边缘余量，结果及精确UV点阵见summary.json。

按用户明确新规则，取消此前“轴心必须是白灰色”和“发光样本导致失败”约束；现在只记录装饰光覆盖而不据此移动点位。指挥舰双炮有意覆盖左右主舰舱光窗，仍落在完整舱体承载面；没有改底图或生产发光/数值。carrier区域只是主翼/主甲/主弧/主舰舱作者标记，不是碰撞体或编队占位。测试夹具的装配与挂点应用仍仅在隔离内存，生产没有自动启用1/2/4接口。

原静态资产/接口冻结检查通过。未改生产攻击链，不扩展伤害组合/性能/全量测试；Linux Godot4.6.3 llvmpipe/GDS，native view为函数级验证，没有声称native整场。自然编队密度与编队重设计不在本轮。

复现：python test/check_enemy_ranked_assets.py；隔离工程图形运行test_enemy_ranked_art.gd，RANKED_OUTPUT指定test/work本次目录。独立候选供父审，未合main，无执行阻塞。
