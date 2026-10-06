"""Human explanations only. Never changes business literals or workbook bytes."""
from pathlib import Path
import json,gzip,runpy
out=Path(__file__).resolve().parent
notes={
'unlock_stage':('最高已到达主线关','异空间开放门槛。调大更晚开放，调小更早开放；达到门槛仍需满足路线最低关卡和资源条件。正整数，不新增关卡内容。'),
'minimum_level':('主线关','可选择探索的最低主线关。调大屏蔽更多低关，调小允许更早关；所选关不得超过已到达关及正式关卡表。'),
'energy_rate':('能量/游戏秒','在线异空间充能基础速度。调大更快攒票，调小更慢；受挂设及60关后补给倍率共同作用。随游戏时间推进，离线不补充。'),
'energy_cap':('能量','基础储能上限，也是自动探索满能量派发门槛。调大一次储能更多但首次充满更久，调小更快满；挂设会同步放大容量。'),
'ticket':('能量/次','手动票耗及自动票耗基数。调大每次消耗更多，调小更便宜；自动再乘B/(B+船员等级)，失败仅退实际已付票。例如B=20、等级20，自动票耗为此值的一半。'),
'minimum_duration':('游戏秒','自动探索耗时下限。实际=max(此值,最佳手动X1记录×船员折算)。调大提高最快可达到的耗时下限，调小允许更快；离线不推进。'),
'warehouse_capacity':('无人机格','初始仓库容量。调大能存更多无人机，调小更早满仓；后续容量另加每次重铸增长。影响满仓暂停和领取条件，不直接提升伤害。'),
'overflow_capacity':('无人机格','固定10格溢出缓存，处理正常仓库暂时无法接纳的无人机。只读，必须10，不是可扩容参数。'),
'reforge_capacity_gain':('无人机格/重铸','每次重铸永久增加的仓库格数。调大后续轮次更能囤机，调小容量成长更慢；不增加单舰装备槽。'),
'initial_retention_capacity':('保留无人机格','首轮可标记跨重铸保留的基础容量。调大首轮允许保留更多，调小更少；可为0，另受保护引用和实际保留事务规则约束。'),
'retention_capacity_gain':('保留无人机格/重铸','每次重铸增加的保留容量。调大后续保留更多，调小成长更慢；不赠送无人机，也不改封存/重新开放规则。'),
'maximum_equipped':('无人机架','全局装备数量硬上限，范围1..5。调小限制同时生效架数；最终还受当前舰型容量限制，调大不能超过5。'),
'maximum_legendary':('传说无人机架','同时装备传说无人机上限，范围1..2。调小限制传说效果组合，调大允许更多组合但不能超过2；不是抽中传说的概率。'),
'maximum_ultimate':('究极无人机架','同时装备究极上限，现有合法值只能1。硬上限1，不提供多究极玩法；不是核心抽取概率。'),
'completion_budget':('结算轮数/advance调用','固定单次推进最多结算8轮的性能保护。只读；积压工作由后续调用继续处理，不是奖励倍率或探索次数上限。'),
'ultimate_weapon_bonus':('武器有效等级增量','究极武器有效等级增量，覆盖普通/蓝来源/传说等级加成而不叠加。调大究极输出通常更强，调小更弱；不提高实际购买等级或改造费用。'),
'affix_initial_probability':('概率，1=100%','首个潜在词缀槽生成成功概率。调大更易生成词缀，调小更少；后续槽乘追加因子，某槽失败不停止后续抽取。限制0..1。'),
'hanging_initial_probability':('概率，1=100%','首个潜在挂设槽生成成功概率。调大更易带挂设，调小更少；后续槽乘追加因子，某槽失败不停止后续抽取。限制0..1。'),
'additional_probability_factor':('后续概率乘数，0..1','潜在槽每向后一个位置，概率再乘此因子。调大后续槽更易成功，调小更稀少。例如起始0.2、因子0.25，前两槽概率0.2与0.05；失败不提前停止。'),
'value_precision':('原始参数量化步长','词缀及传说参数随机值的量化步长。调小候选值更细、保底MAX期望报价通常更高；调大值更粗。必须正数，各区间至少含一个量化点。'),
'amplification_rate':('每无人机等级复合增长率','标记amplified的词缀按(1+此值)^(无人机等级−起点)放大。调大高于起点时更强、低于起点时缩小更多。例如0.05每级因子1.05；不是每级固定加5个百分点。'),
'amplification_start_level':('无人机等级','词缀放大指数的零点，正式接线后生效。调大同等级词缀的放大值更小，调小更大；level=起点时×1，低于起点仍按负指数缩小。默认4与旧固定值等效。'),
'material_base_reward':('专属材料份/成功探索','探索基础专属材料奖励。调大各关奖励整体增加，调小减少；基础再加floor(max(0,关卡−成长起点)/步长)，最后乘补给倍率并向下取整。'),
'material_reward_level_step':('主线关/增加1份材料','每隔多少探索关增加1份基础专属材料。调小成长更快，调大更慢；正整数。例如起点5、步长3，8关首次增加1份。'),
'material_reward_start_level':('主线关','材料奖励成长起点，同时是现代化费用等级项的原点。调大同关材料成长更晚且现代化等级项更低，调小反之；此联动保留，不拆成第二个价格起点。'),
'maximum_filter_conditions':('筛选条件条','固定筛选安全上限5条。只读；限制玩家规则复杂度，不调整无人机质量或奖励，不是筛选结果数量。'),
'maximum_filter_string_length':('字符','固定筛选导入文本安全长度4096。只读；用于拒绝过大输入，不决定伤害、掉落或筛选概率。'),
'maximum_forecast_attempts':('预估抽取尝试次','固定改造保底预估循环保护10000次。只读；超过即报告预估限制，不能作为更高掉率或无限保底开关。'),
'lock_cost_multiplier':('每个已锁词缀的费用倍数','锁定费用=基础胶子费×此值^已锁词缀数。调大后续锁定更贵，调小更便宜；首次未锁时指数0。例如4时每增加一个已锁词缀，下一次费用再×4。'),
'reroll_guarantee_multiplier':('保底MAX期望费用倍数','保底MAX重洗报价=基础反质子费×各重洗区间可取值数量乘积×此值，并向上取整。调大保底更贵，调小更便宜；不改变MAX结果或普通随机重洗范围。'),
'modernization_cost_base':('专属材料份及舍入粒度','现代化价格公式的材料基数，也是最终报价舍入粒度。调大通常更贵且报价更粗，调小更便宜且更细；价格按round(原价/此值)×此值，不改实际提升目标。'),
'modernization_level_step':('主线关','现代化费用等级项分母：(1+(目标关−材料成长起点)/此值)。调大等级费用增长更慢，调小更快；目标由该路线已有最佳记录决定，正数。'),
'modernization_legendary_multiplier':('传说现代化费用倍数','仅传说无人机现代化价格乘此值。调大传说升级更贵，调小更便宜；普通无人机不乘此倍率。例如2表示传说同条件费用×2。'),
'late_supply_unlock_stage':('已清主线关','后期补给门槛，须该主线关已通关，而不是仅最高到达。调大更晚开始补给，调小更早；之后按在线爬升时长渐进，默认60。'),
'late_energy_rate_multiplier':('充能最终倍数','后期补给爬升终点的充能倍率。调大最终充能更快，调小更慢；从×1线性爬升到此倍率，另乘挂设效果，不是储能容量倍率。'),
'late_material_reward_multiplier':('材料最终倍数','后期补给爬升终点的专属材料奖励倍率。调大材料更多，调小更少；从×1线性爬升，结算份数向下取整。例如终点4即基础奖励×4。'),
'late_supply_ramp_seconds':('在线游戏秒','补给从×1到目标倍率的爬升时间。调大完全生效更晚，调小更快；只在线累计，离线不补进度，默认600游戏秒。'),
'modernization_base_coefficient':('费用无量纲起始系数','现代化阶级系数=此值+逐个词缀的阶级费用权重。调大价格更高，调小更低；还乘等级项及传说倍率，默认1与旧固定值等效。'),
'auto_duration_crew_base':('船员等级折算基数B','自动耗时=max(最低耗时,最佳手动X1秒数×B/(B+船员等级))。同一正等级时调大耗时更长，调小更短；B=100、等级100时记录耗时减半。'),
'auto_ticket_crew_base':('船员等级折算基数B','自动票耗=基础票耗×B/(B+船员等级)。同一正等级时调大消耗更多，调小更少；B=20、等级20时半票。只调自动，失败退实际已付票，结算和UI共用公式。')}
rows=json.loads(gzip.decompress((out/'ALL_CURRENT_FIELDS.json.gz').read_bytes()))
for r in rows:
 if r['source_file'].endswith('/hyperspace_config.json') and r['path'][1:] in notes:r['unit'],r['description_zh']=notes[r['path'][1:]]
(out/'ALL_CURRENT_FIELDS.json.gz').write_bytes(gzip.compress(json.dumps(rows,ensure_ascii=False,indent=2).encode(),mtime=0))
new=json.loads((out/'NEW_NUMERIC_FIELDS_DRAFT.json').read_text())
for r in new:
 if r['path'][1:] in notes:r['unit'],r['description_zh']=notes[r['path'][1:]]
(out/'NEW_NUMERIC_FIELDS_DRAFT.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
runpy.run_path(str(out/'verify-two-workbook-rows.py'))
