# 防御优先：三族 × 两种装甲材质候选

[舰体30/50/80px与灰度](review.png) · [真实武器组件与包络](mounted-review.png) · [30px朝向/盾状态](state-review.png) · [盾状态灰度](state-review-grayscale.png)

父已批准候选接通：本分支新增四个正式资产描述、统一archetype/装甲类别解析和共享ship_key发布，盾标记进入前三关既有状态层。敌人表、装备、数值、碰撞算法与背景未改；不是main或最终验收。详见[接通证据](BINDING_IMPLEMENTATION.md)。沿用[共享ship_key提案](../binding-proposal/README.md)，同一资产描述必须同时进入显示与既有几何权威。新旧轮廓不同不是否决条件，不再要求旧壳等价，也不套隐藏旧壳。

## 本轮收敛

- 同族两材质使用相同外接尺度：三角720×640、宽板720×710、U族700×720；同族共享原有挂点/slot_map。alpha不要求逐像素一致。标准画布仍887×1774 RGBA、舰首朝上、四周透明；审稿中战斗方向旋转180°。
- U族保留前双叉，尾部改平桥，中央补实心凹甲板与横梁。中央不再是透明洞；现有凸包仍会跨过舰首凹口，不作可穿透承诺。修订只使用新源图的U列，另外两族保留上轮源。
- 盾类别增加候选形状：抗物理为双横肋，抗能量为空心菱形，均放在既有有效盾轮廓内侧。只在alive且当前盾量>0时显示；未新增外包络或盾机制。灰度图可审两个类别的形状差异。

## 识别契约

| 数据 | 视觉责任 | 边界 |
|---|---|---|
| armourType=2 | 横向宽厚叠甲、深横缝、金属倒角 | 不是攻击类型或绝对免疫 |
| armourType=1 | 浅色陶瓷纵面、深色中槽 | 无盾/破盾后仍保留材质 |
| shieldType | 独立盾层类别＋双横肋/菱形 | 不改舰体材质；hit.type是攻击类型 |
| max_shield / shield | 无容量、有效、耗尽 | 无盾/耗尽不画有效盾类别标记 |
| 真实盾量增长 | 现有恢复回流 | 不把延迟到期当恢复；暂停抑制回流 |
| 装备与真实事件 | 炮口、发射、命中、机制反馈 | 不预测攻击窗口或猜免伤分项 |

shield_shape_proposal.gd现在只是兼容旧审稿入口，直接继承已接通的enemy_recognition_visual.gd；标记在共享draw_protection中绘制，opening_readability限制于前三关。state-review为合成只读状态，使用现有state函数，不是战斗录像。无盾格的离散角括号仍是既有装甲提示，不是有效盾轮廓。

## 真实挂点/包络证据

mounted_review.gd调用现有compose_weapon_components、_source_enemy_component_pose、geometry_from_descriptor和main.gd::draw_enemy_weapon_components。仅为离线固定转角覆盖enemy_weapon_angle；没有自写炮口公式或另算生产碰撞。

- 六候选×cannon-mon/laser_mon/missile-mon×30/50/80px＝54组；每挂点采样181个合法角度，以现有mount_corners和边距离审计核对权威inner包络，结果见mounted-audit.json。
- 每组把对应已有slot_map全装同一种真实武器作为覆盖审查；**不是拟上线敌人装备表**。三角对照enemy_1、宽板enemy_4、U族enemy_6，仍未绑定这些旧敌人。
- 屏幕图绿色为从新alpha＋实际挂点派生的现有inner包络；淡橙线为炮口合法扫掠，亮点为正向炮口。武器绘制使用现有最小15px规则，不缩小或藏掉它们。
- 54组武器与舰体均在包络内。此结果不是碰撞命中/性能全验收；没有发射、伤害或实玩推进。

几何明细见geometry-audit.json；它调用既有hull_profile/alpha_boundary/convex_hull，同时保留旧资源差异作参考，不以旧壳等价作为批准门槛。完整武器包络审查比上一轮仅检查挂点中心前进了一步。

## 已准许的候选映射与未完成验收

U族30px平尾/双叉比原双端尖角明确；但全装四个炮/能量器的覆盖样本明显遮挡甲面，不能宣称所有30px实际装备都识别通过。候选已按下表接通；已只读Sol 6b2e98da装备/尺寸并按默认窗口比例作单舰对照，见[生命周期补证](LIFECYCLE_EVIDENCE.md)。该版本只有单武器组合，四武器U压力稿不是实际配置；当前攻击甲板仍遮挡材质，未完成18点编队画面验收。不得改敌人装备或数量解决遮挡。

下列映射已获父批准用于隔离表现分支；数字ID仅是先前草案参照，代码只按archetype_id和匹配armourType选择，新增掉落ID保持同archetype外观。candidates.json是审稿清单，不是运行配置。

| 草案身份 | 候选 |
|---|---|
| 270001/scout、270002/sentry | triangle-physical |
| 270003/interceptor、270004/swarm | triangle-energy |
| 270005/anchor、270006/reactive | slab-energy |
| 270007/shielded、270008/command | u-energy；shielded仍由真实shieldType/当前盾量显示独立盾层 |

slab-physical与u-physical仅用于跨族材质一致性审查，不由此新增敌人。盾标记已获准接入；实现沿既有共享appearance/几何发布，未单改某条绘制路径。若实际组合遮挡严重，优先调整舰体可读大面与既有表现分层，不自行改射速、弹体数量、战斗规模或几何算法。

## 资产来源与复现

ImageGen基于R03制作；无Blender模型。提示为正交俯视、舰首朝上、下右照明、三列三角/宽板/U、横叠金属与纵向陶瓷两材质、石墨/暗红框架、无武器/文字/背景/发光；U修订提示为前叉保留、短平尾桥、中央实心甲板。prepare.py仅提取连通域、规范同族尺度并置入透明画布；源保存在source。

隔离项目先运行prepare.py，再用Godot --path <project> --rendering-method gl_compatibility --audio-driver Dummy --script res://docs/art/opening-three/defence-candidates/review.gd；mounted_review.gd同法生成武器/状态/灰度证据。验证环境为Godot4.6.3、Mesa llvmpipe；未运行Windows原生性能验收或新档测试。直接源图读取仅用于离线审稿，生产仍需正式导入路径。
