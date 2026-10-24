# 07 异空间、无人机与改造

## H01 手动挑战

Hyperspace保存每路线层记录（最快X1游戏秒）、当前手动run及后台run、奖励状态与私有RNG。Combat仍唯一战斗执行器，不能给异空间另写数值模型。路线alpha/beta/gamma/delta分别绑定laser/missile/cannon/longLaser及各自材料，来源Excel路线表。

当前入口挑战该路线最高通关层+1，后台重复最高已清层；代码票耗为0，与Excel旧minimum_level/ticket/energy规则冲突，D02阻止擅自收费或恢复门槛。手动请求先校验路线、层级、主线权限、敌表完整性和模式；排队/取消不得扣费或抽奖。进入采用清空原战场、不保存暂停现场的用户允许方向；进入边界与返回主线节点/生命/CD由D01明确，不复刻旧suspended_main快照。

战场攻击/生命依据探索层；普通铁/铀/强化碎片奖励在派发时冻结最近实际通关主线关，不能用highest reached；特殊无人机/材料按探索层。战场候选/路线/奖励参考全部从hyperspace_enemies Excel生成，失败拒绝开始不能用普通敌兜底。退出/失败不发胜利奖励，不创造通关记录；是否涉及退款取决于D02，零支付不能退非零。

UI每路线显示已清/下一层/最快记录、挑战/退出、后台状态与船员；按钮reasons明确locked、busy、inventory_full、crew_unavailable、invalid_config。正式内容缺失禁挑战并报告，不能启动空战场算胜。手动运行中禁止重铸；读档中断处理见09/D01。A-HYP。

## H02 后台、完成、领取

后台无需停主线，使用游戏时间；手动一次后台duration=当前层best；船员自动=best×K/(K+L)。一次全局后台槽与一次手动槽可区分存在；不能给每条路线暗加并行槽。自动重复须有效船员、已清记录、存储空间、无未领取完成奖励；无船员不推进新任务。

run状态 `started -> completed_pending -> claimed`。开始冻结route/level/crew/luck/时长与runId；结束抽取并冻结一次奖励和RNG后态；满仓保留completed_pending，不重新抽、不丢奖励、不重新生成历史。领取检查空间→一次材料到账/物品入库/挂载成长→标记完成→UI通知。重复领取返回already_settled。关闭自动不能删除completed_pending；进行中停止清该轮工作且不补发。满仓期间不积攒可无限补领的后台时间。

手动成功记录最短有效X1时长，不含暂停真实时间；加速不缩短X1秒指标。自动后台不得用自己更快的duration覆盖手动best。普通死亡不删除路线历史；重铸保留路线历史但当前主线限制可用记录，见08。

## H03 奖励、幸运和预算

品质：核心概率来自ultimate_core_probability，其他品质按其weight重新归一分配剩余概率；抽核心按固定exclusive策略只发一个核心不同时生成无人机，路线材料仍按规则发放。固定规则页不开放任意策略字符串。材料量=(material_base_reward+floor(max(0,level−material_reward_start_level)/material_reward_level_step))×有效材料倍率×material_unit_scale，最后floor。阶段后补给倍率按配置late_supply门槛与ramp游戏时间线性渐进；充能部分是否保留属于D02，不自动激活。

生成无人机：quality给词条/挂载上限；每个可用槽独立用当前概率抽是否生成，每次尝试概率×additional_probability_factor；词条先按tier_weights抽阶，再在适配该武器且有该阶区间的ID中等概率抽种类，再按value_precision量化抽值。传说在兼容weapon的效果中抽，参数分别按对应范围抽。新机私有改造RNG不消费主战斗RNG。

幸运只提高普通词条阶级：每100额外一次，余数作为额外一次概率，在原抽与额外抽取最好（T1最好）；不改变品质/核心概率、词条数量/种类、挂槽数、传说概率或改造抽签。幸运在run开始冻结，来自永久征服+该路线船员。若阶变强按新阶重抽值。奖励参考的早段预算是正式Excel内容；成员分配必须守恒于参考掉落次数/金额，不以“合并相同资源”悄悄改变概率。

## DRI01 库存、装备、收藏、预设、筛选

无人机事实：id、origin_quality、weapon、level、来源planet、legendary/ultimate/blue_source_bonus、普通词条{key,tier,value,locked}、保留ultimate_affix、hanging_slots/hangings/preserved_slots、omen、forge版本/私有RNG。数值投影不写回原随机值。

仓库容量=warehouse_capacity+reforge_count×reforge_capacity_gain；溢出仓另有overflow_capacity；空出普通仓时按溢出顺序移入。装备必须来自普通仓、未封存、不重复ID，数量<=min(hull_capacity,maximum_equipped)，legendary与ultimate独立计数（默认2与1）；兼具两者同时占两额度。换船/替换先验证最终集合，不能先卸再失败。希格斯炮来源上限包括普通炮与无人机炮。

收藏、装备、预设引用、封存均保护对象，拆解/普通删除必须先解除保护；不能拿“清理”绕过。预设保存名称、无人机ID序列和挂载组合，应用时整体验证，不部分应用。传说seen与collection分开，发现不等于已收藏，只有已收藏且兼容才可指定改造结果。

筛选支持all/any及keep_matches/clear_matches；条件仅weapon、quality、minimum_level、affix(key,tier<=阈值)、legendary_effect。启用而无条件拒绝；条数和字符串长度有界。影响新奖励处理，不自动拆现有受保护仓库。被筛掉奖励按拆解规则转材料/挂载并冻结结果。导出带版本前缀的规范base64 JSON；导入只解析不执行，非法编码/字段/ID拒绝，原筛选不变。UI支持详情、空位装备/明确替换、仓库/溢出/封存、材料区和领取入口，完整名字/限制在详情显示。

## DRF01 改造公共契约

`preview_forge(droneId,operation,args)`在对象与私有RNG副本上计算报价，不扣款、不推进正式RNG；报价含对象版本、配置ID、轮次、最终费用、影响和必要前提。`confirm_forge(quoteId)`重验对象/配置/资金/限制，仅一次安装对象、钱包与RNG后态；重复确认同报价不重复扣费。改变对象、操作、现代化目标或相关装备限制后报价失效，UI提示重新预览，不自动重抽确认。失败不更改锁定、已见收藏或库存。

| 操作 | 规则/公式 | 失败与保留 |
|---|---|---|
| add_affix | 低于quality词条上限时新增兼容随机词条 | 满额拒绝；旧词条不变 |
| replace_affix | 从未锁索引抽一条，重抽种类/阶/值；指定种类是连续随机替换直到得到目标，费用×实际draws | 有界maximum_forecast_attempts超限不提交；指定种类不等于指定位置/阶/最大值 |
| add_hanging_slot | 未达有效挂槽上限+1 | ultimate不可改；传说化保留已存在槽上限 |
| lock_affix | 在所有未锁词条等概率选一永久锁；费用base×lock_cost_multiplier^已有锁数 | 不受omen选最低阶影响；无解锁操作 |
| promote_affix | 先随机未锁词条；按tier_weights抽到更强阶才成功，但仅提升一阶并重抽值 | 失败仍正常收费；T1选中按现行拒绝不改其他条，若要跳过T1需另批 |
| reroll_values | 所有未锁词条及传说随机参数一起重抽，不改种类/阶 | locked不动；无对象拒绝 |
| guaranteed_max参数 | 各区间离散值数N=round((max−min)/precision)+1；费用=ceil(base×ΠN×reroll_guarantee_multiplier)，取本次全部相关值上限 | 大数计算报价，不改成单条最大化 |
| enable/disable_omen | 只改变该机替换选目标：最低阶（数值最大）优先，同阶随机 | 不提高新阶概率，不影响锁/升阶 |
| legendary | 首次传说化增加随机兼容效果，保留词条/锁/挂槽/挂载/蓝色来源加成；指定必须收藏，连续抽费用×draws | 已传说禁止再次传说化，不能悄悄重抽 |
| modernize | 目标=路线历史中不超过本轮highestLevel的最高级，必须更高；系数=base_coefficient+Σtier_weight；raw=cost_base×(1+(target−material_start)/level_step)×系数×传说倍率，再round(raw/cost_base)×cost_base | 保留种类/阶/原随机值；目标变更使报价失效；ultimate先还原 |
| ultimate | 消耗配置核心/材料，武器等级加配置bonus，首次生成额外词条 | 与legendary可并存；普通改造/挂载更换禁用 |
| restore_ultimate | 关闭究极，保留额外词条供下次复用 | 不退核心、不重抽、不升级 |
| dismantle | 删除未保护对象；按当前legendary或原品质dismantle_amounts返路线材料，并抽同数量挂载副本 | 永久删除需游戏内确认；重铸删除不走拆解不发奖 |

全部普通材料费用在完整基础公式后乘material_unit_scale，核心不缩放；不再用旧int上限溢出拒绝替代大数。改造材料按operation表，不等于无人机产地。D02未定票耗不影响已明确的改造费用。

## DRF02 挂载、兑换、重铸保留

首次获得挂载副本只解锁0级，剩余每份增加base_exp；下一级需求base_exp×(1+exp_growth)^L，扣需求留余数。装备贡献=(1+effect_growth)^L−1，多架同类相加；挂载需已解锁且达到unlock_stage，每机不能重复同类。extra_storage等跨域容量变动按03先验证整体再安装。

四常规材料2:1兑换，输入期望获得数量q，扣源2q、加目标q；正整数、源不同且均在路线材料集合，核心不可兑换。预览显示余额/缺口，确认重验；一次同步支付到账。该2:1现行代码常量需迁入Excel固定规则说明/值，不能另做隐藏汇率。

重铸显式选keepIds与解封关卡，容量包含本次新增retention_capacity_gain；被选对象保留完整随机事实但封存、取消装备，达到指定关后领取；未选删除不发拆解奖励。详细重置矩阵08/09，模糊的claim_stage来源必须在实现前由D09确认。A-DRONE/A-HYP。
