# 共享几何与占位身份：最小待审提案

状态：仅来源核对与接口方案，未批准、未实施。后端源码基线`24279e19d4826a4e3d42fa03d5374bf15c48cfb1`；同分支Amount尾项`6f6f9fd2a6f9fb5b2ce829a86f02937552b5328c`只改Reactor复制，不改本页几何依据。需求仅取前端`a3e05ea05418841821e2acfec6899b900d8d0b90`的`docs/ui-redesign-plan/g1-internal/g2-battle-restoration.md`末节“联合空间预算修订”。P1/P2均是条件方案，不能借本页选定方向。

## 权威核对与缺口

[M1空间要求](../game-design/art/modules/battle.md)规定普通1格、精英2×2、首领居中3×2；[05几何边界](../game-design/05-architecture.md#55-大数几何和图形)及[14§7](../game-design/14-ui-contracts.md#7-已实现出口敌盾与双条的最小战场展示契约)要求真实几何由原所有者交给native，展示查询不授权重新布点。M1没有说明每个配置演员如何归入占位等级。

| 来源 | 本轮直接核实事实 | 不能推出的结论 |
|---|---|---|
| `config_excel/monGroup.xlsx` / monGroup第2291行 | 33011为11×271013、3×271020、1×271019；只有组级`combatTier=elite`，表头仅id/des/mon/combatTier | 不能从组级遭遇标签确认每舰占位角色 |
| `config_excel/mon.xlsx` / mon第10406、10412、10413行 | 对应size为1、4、1，archetype为swarm、anchor、swarm；没有逐舰占位等级/矩形跨度列。size旧说明为“战场占据的格子数” | 面积描述没有给矩形宽高、精英映射或leader居中规则，不能直接等同1×1/2×2/3×2 |
| `src/combat_setup.gd::build_wave` | 先按槽生成位置；group tier写给每个actor；boss/ultimate只将最大size的首个成员标leader | 生成位置时尚未用actor的最终visual_key；不能让UI事后选图后重排 |
| `scripts/enemy_visual_identity.gd::visual_rank/resolve` | elite组全员rank=elite；boss/ultimate仅leader rank=boss；只有anchor/reactive/shielded/command选择分级模型，资源就绪性参与选图 | 无elite贴图不代表普通身份；视觉fallback不能暗中决定业务等级 |
| `data/ship_weapon_visuals.json::ships` | 四elite有display_span=[2,2]、四boss有[3,2]；八普通无display_span | 缺省1×1是P1提案解释，当前并无占位消费者确认其为规范 |
| `scripts/ship_geometry_convention.gd::formation_positions/battle_geometry` | 前者按size降序/id/slot排序、数量排位，支持显式formation_positions；后者按已选模型display_size旋转等比适配 | display_size是舰体适配框，未包含全炮台扫掠、盾、固定像素条与净空 |

本次只读工作簿SHA256：monGroup=`321f2d87798e6a8374f16a47f6f24956fe5d07e58e97cc5078d5e451b0219b6b`；mon=`204acd2961cec56282763513415d4bcf14cee40de4ea59e4a852ac3e1cf2040e`。上述行用openpyxl只读/data_only直接回读，未重写Excel。其余全表可达集/4020次装箱、60组预算与图像证据仍是前端固定候选声明，本轮没有独立重跑或提升其验收状态。

## 占位最小接纳方案（待裁定）

由CombatSetup组装阶段统一解析每槽的占位输入，再交Geometry生成真实坐标；视觉身份解析与占位解析共用所需源事实，保持两者职责清楚。内部最少需源slot/mon_id、已解析visual_key、批准的span与leader居中约束；这是具名共享几何输入，不增通用DTO、公开金额状态或存档字段。位置生成后仍写回同一actor.x/y，供绘制、目标与native接触使用，不能在展示端另设坐标。

| 用户裁定 | 33011结果及影响 |
|---|---|
| P1：所选模型display_span，缺省1×1 | 14个1×1加1个2×2，18格；视觉模型/fallback改变可能改变占位。若接受此语义，须明确资源不可用时占位是否也跟随fallback；不能由实现自行决定 |
| P2：encounter rank映射 | 全15舰elite为2×2，共60格；boss/ultimate仅leader为3×2，其余1×1仍须明确批准；未分级贴图也占精英格 |
| 若要求独立逐舰占位身份 | 需另行批准来源与配置表达，现表不能可靠推导；本轮不先加Excel列或虚构映射 |

选定语义后仍须一起批准前端同版的模板、逐模型display_size、我舰共用倍率/原点、条/外缘/效果/净空与无人机空间预算。P1的7×3、P2的10×6只是方案模板；格数相容不等于矩形装箱成功。首领“居中”、同面积顺序、显式formation_positions覆盖遇到冲突如何处理，需要在实现前补齐具名约束；前端“逐行中心优先”不能自动证明首领居中。推荐在准备期报告无法布置的组/槽，发布前拒绝，不截断演员、不压缩或UI私排；沿既有提交故障政策，不新增查询停机链。

## 无人机：真实接纳链与最小缺口

已查链：`GameSession.equip_hyperspace_drones`→Hyperspace.prepare_loadout→`publish_equipment_refit`→`Battle.prepare_player/commit_player`→`_sync_geometry`。Session先完成native提交，随后接受装配/各模块，再发布通知；普通失败不提前接受loadout。Battle从贡献稳定id生成`drone:<id>`、drone_id、generation，slot由装备槽数+当前index生成。index可变，不可作持久绑定键。

现缺口：prepare_player把drone weapon.muzzle设为玩家原点，_sync_geometry直接沿用该点，未建立独立机体root和真socket链。`scripts/hyperspace_drone_visual.gd`已有按id管理节点、socket描述及mesh前脸抽取、apply_geometry_frame/restore_canonical_display辅助；本轮`git grep`未找到这些辅助或该脚本的生产调用方，不能写成当前Battle已接入。screen_muzzle_for_drone缺socket时回退到玩家显示中心，不能作为真炮口接纳依据。

建议在原几何所有者中准备一份按稳定id绑定的canonical装配：批准的世界root变换+资产局部socket变换列表+贡献generation。socket描述在资产安装时提取/核实，可复用现有GLB提取方法，不每帧扫描mesh。root、机体、品质结构、所有真socket采用同一变换链；投影只在展示边界一次进行，不把OFFSETS、clamp屏幕点、相机反投影或玩家中心当世界权威。缺有效socket或身份不匹配在准备期报告，不静默中心发射。

Battle准备阶段结合当前装配/容量产生完整候选，普通失败不替换已接纳frame；commit内将同一组世界炮口数组按`drone:<id>`给现有`input_geometry`和`input_ballistic_geometry`，同批接纳展示frame，完成后再通知。无需先扩native API：现内核`apply_muzzles`已接受PackedVector2Array，前者更新数值端口、后者更新screen端口；`muzzle_port`按ordinal选择同序列表。列表顺序必须在资产描述中稳定，不能因UI排序或重建改变。

generation用于既有装配出生/替换语义，不能当每帧几何revision；禁用、卸载、换装、同id新generation和会话替换按原native生命周期退役/保留，逐项核对旧弹与活光束，不另造复活或回溯规则。展示浮动若改变socket，必须明确为纯表现（不伪称其为数值出生点），或经批准成为canonical运动同步进native；当前display_motion不能仅移动真炮口显示来宣称一致。此选择及运动幅度仍待批准。

P2改变player_y时，必须同时核对`Battle.mount_inputs/collection_inputs`、CombatSetup玩家锚点、native player_point/hull、炮口及Economy掉落target_y，不能仅把我舰贴图下移。真实掉落位置沿Economy事实，前端示例点不进入结算。护盾/双条继续复用enemy_presentation，不为此增加通用轮廓查询。

## 实施门槛与后续验证

必须用户裁定：占位来源（含fallback/leader）、P1/P2或其他联合空间方向、完整真实参数、无人机canonical运动与表现偏移边界。随后契约复审确认来源/接纳/失效及所需最小字段，才可实施。main审批暂停，不合并、不发布。

获准后仅做受影响验证：确定性矩形占位及显式覆盖/不溢出；所有批准来源可达组与反例；稳定id/generation、容量/禁用/卸载/重排与ordinal；同一canonical socket的native出生/显示及活光束目标一致；P2玩家点与掉落目标；再由同版GameSession/Godot整屏完成五舰、全合法装配、最密编队、固定像素条、输入逆变换和V1/G9画面验收。文档核对与前端静态装箱不替代这些运行证据。本轮无几何代码、配置、资产或游戏测试变更。
