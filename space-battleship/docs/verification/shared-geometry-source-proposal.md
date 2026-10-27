# 共享几何与占位身份：最小待审提案

状态：仅来源核对与接口方案，未批准、未实施。后端源码基线`24279e19d4826a4e3d42fa03d5374bf15c48cfb1`；同分支Amount尾项`6f6f9fd2a6f9fb5b2ce829a86f02937552b5328c`只改Reactor复制，不改本页几何依据。需求仅取前端`a3e05ea05418841821e2acfec6899b900d8d0b90`的`docs/ui-redesign-plan/g1-internal/g2-battle-restoration.md`末节“联合空间预算修订”。P1/P2均是尚未成熟的条件方案，本页不要求用户现在二选一。

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

## 占位来源冲突与团队推荐方案

由CombatSetup组装阶段统一解析每槽的占位输入，再交Geometry生成真实坐标；视觉身份解析与占位解析共用所需源事实，保持两者职责清楚。内部最少需源slot/mon_id、已解析visual_key、批准来源导出的span与M1已定的首领居中约束；这是具名共享几何输入，不增通用DTO、公开金额状态或存档字段。位置生成后仍写回同一actor.x/y，供绘制、目标与native接触使用，不能在展示端另设坐标。

| 条件解释与来源冲突 | 33011结果及影响 |
|---|---|
| P1：模型元数据display_span，缺省1×1 | 14个1×1加1个2×2，18格，只是前端条件统计；尚缺将该元数据确认为逐舰业务占位来源的依据。素材fallback不能改变业务占位；若保留此方向，须在fallback前从获准来源固定占位身份，不能直接以最终选中贴图反推 |
| P2：encounter rank映射 | 全15舰elite为2×2，共60格；冲突在于组级遭遇标签能否代表每舰占位身份。首领已确定须居中占3×2，不重新征询此规则；boss/ultimate其余成员的逐舰身份仍受来源问题约束，不能因未分级贴图推定普通 |
| 若要求独立逐舰占位身份 | 需另行批准来源与配置表达，现表不能可靠推导；本轮不先加Excel列或虚构映射 |

团队推荐并提交技术审核的实现细节：先固定首领于中心的3×2矩形，再对其余成员按span面积降序、同面积保持源slot顺序，在完整空闲矩形中按确定性的中心优先次序装箱；显式formation_positions也须在准备期核验与已定占位、中心及边界约束的相容性，冲突则具名报告组/槽并在提交前拒绝。若批准模板无法容纳居中首领，报告方案失败并改进设计，不把放弃居中当用户选项。这些细节由团队评审，不全转为用户选择；不截断演员、不压缩或UI私排。P1的7×3、P2的10×6仍只是条件模板，格数相容不等于矩形装箱成功。来源冲突澄清且整体设计成熟后，才将模板、逐模型display_size、我舰共用倍率/原点、条/外缘/效果/净空和无人机预算作为完整真实参数方案提交批准。

## 无人机：真实接纳链与最小缺口

已查链：`GameSession.equip_hyperspace_drones`→Hyperspace.prepare_loadout→`publish_equipment_refit`→`Battle.prepare_player/commit_player`。当前`commit_player`顺序是`native.set_player_configuration`成功→增加提交计数→`_accept_player`本地接纳→若geometry_changed则`_sync_geometry`；随后Session才接受loadout等模块并发布通知。几何同步发生在native与Battle本地状态已接纳之后，当前并没有完整候选几何在提交前校验的全链原子保证。native配置普通拒绝不提前接受loadout；提交后几何fault沿原RunState/Session停机政策，不能写成普通拒绝或声称全部回滚。Battle从贡献稳定id生成`drone:<id>`、drone_id、generation，slot由装备槽数+当前index生成。index可变，不可作持久绑定键。

现缺口：prepare_player把drone weapon.muzzle设为玩家原点，_sync_geometry直接沿用该点，未建立独立机体root和真socket链。`scripts/hyperspace_drone_visual.gd`已有按id管理节点、socket描述及mesh前脸抽取、apply_geometry_frame/restore_canonical_display辅助；本轮`git grep`未找到这些辅助或该脚本的生产调用方，不能写成当前Battle已接入。screen_muzzle_for_drone缺socket时回退到玩家显示中心，不能作为真炮口接纳依据。

建议在原几何所有者中准备一份按稳定id绑定的canonical装配：批准的世界root变换+资产局部socket变换列表+贡献generation。socket描述在资产安装时提取/核实，可复用现有GLB提取方法，不每帧扫描mesh。root、机体、品质结构、所有真socket采用同一变换链；投影只在展示边界一次进行，不把OFFSETS、clamp屏幕点、相机反投影或玩家中心当世界权威。缺有效socket或身份不匹配在准备期报告，不静默中心发射。

建议补齐的准备边界：在调用native配置提交前，根据候选装配/容量生成完整几何候选，核齐所有预期`drone:<id>`及generation、root/socket有限变换、每个有效武器非空且全有限的有序炮口列表、稳定ordinal以及机体/目标几何的一致性；缺项或非法候选在此普通拒绝，保持已接纳状态。不能先提交后用查询补齐。提交阶段再将已核同一份世界炮口数组交现有`input_geometry`和`input_ballistic_geometry`，让展示消费同一候选；这属于待实施方案，不是当前全链保证。提交后若发生native或几何fault，继续沿原故障政策处理，不承诺回滚。

现内核`apply_muzzles`支持PackedVector2Array，但对缺项、类型不符、空数组或非有限端口直接跳过，不能据返回/调用完成判为完整候选已有效接纳。`input_geometry`更新数值端口、`input_ballistic_geometry`更新screen端口；`muzzle_port`按ordinal选同序列表。团队先审核上述准备期完整性校验及现有API承载能力，再确定是否需最小接口补充，不提前断言无需任何native变更。列表顺序由资产描述稳定定义，不能因UI排序或重建改变。

generation用于既有装配出生/替换语义，不能当每帧几何revision；禁用、卸载、换装、同id新generation和会话替换按原native生命周期退役/保留，逐项核对旧弹与活光束，不另造复活或回溯规则。展示浮动若改变socket，必须明确为纯表现（不伪称其为数值出生点），或经批准成为canonical运动同步进native；当前display_motion不能仅移动真炮口显示来宣称一致。此选择及运动幅度仍待批准。

P2改变player_y时，必须同时核对`Battle.mount_inputs/collection_inputs`、CombatSetup玩家锚点、native player_point/hull、炮口及Economy掉落target_y，不能仅把我舰贴图下移。真实掉落位置沿Economy事实，前端示例点不进入结算。护盾/双条继续复用enemy_presentation，不为此增加通用轮廓查询。

## 实施门槛与后续验证

真正待用户裁定的是逐舰占位权威来源冲突，以及设计成熟后提交的整体真实参数和无人机运动边界；目前不要求在尚未成熟的P1/P2中二选一。首领居中3×2等M1已定规则、素材fallback不改变业务占位均继续遵守。稳定排序、先固定首领中心再装箱、显式坐标冲突在准备期拒绝，以及完整几何候选的提交前校验由团队推荐并技术审核，不全转嫁用户。来源/接纳/失效及最小字段复审、完整方案获准后才可实施。main审批暂停，不合并、不发布。

获准后仅做受影响验证：确定性矩形占位及显式覆盖/不溢出；所有批准来源可达组与反例；稳定id/generation、容量/禁用/卸载/重排与ordinal；同一canonical socket的native出生/显示及活光束目标一致；P2玩家点与掉落目标；再由同版GameSession/Godot整屏完成五舰、全合法装配、最密编队、固定像素条、输入逆变换和V1/G9画面验收。文档核对与前端静态装箱不替代这些运行证据。本轮无几何代码、配置、资产或游戏测试变更。
