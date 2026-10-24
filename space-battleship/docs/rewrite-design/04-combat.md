# 04 战斗、效果与 native/GPU

## B01 一条战斗路径与状态

确认：保持命中时扣逻辑血量、死亡及对应表现。发射只建立攻击快照/载体；命中处理才修改防护、护盾、装甲/生命。UI动画可插值，不重新算伤害。没有预测致死、伤害预占、提前换目标、额外逻辑/显示死亡窗口或新同刻互射规则。

Combat持有Actor{id,faction,alive,HP/shield/max,type,recovery/delay,lastHit,weaponIds}、WeaponState{moduleId,nextFire,target,beamSession}、AttackSnapshot{source,raw,type,critical,effects,repeatPlan}、Flight{attackId,targetId,motion,state}、DefenseEffect{moduleId,protection,cover,timers}、全局伤害债务桶与稳定事件序号。攻击快照保存必要参数；击中时读取目标当前抗性。角色/载体状态只归native，不与GDScript同时推进。

接口见03；一次advance保持既有最大1/60游戏秒步及发射/脉冲子边界。按当前已批准路径稳定处理到期事件，不能因换容器改变随机消耗、同刻命中顺序和盾溢出结果。记录必要事件顺序作为A-BTL场景的期望，不把旧测试断言直接复制。无正间隔、非法数值、未实现效果在创建前拒绝；运行内部错误终止该推进并报告，不能换规则静默继续。

所有战斗瞬态普通读档清空；普通波次、完整战斗、死亡、换装、重铸的区别见B07和09。UI显示当前HP/盾/保护/债务、武器CD及效果说明；界面读数不推进计时。验收A-BTL、A-NATIVE。

## B02 武器与载体

| 类别 | 配置/公式 | 时序、目标与保留行为 | 验收 |
|---|---|---|---|
| laser | equipment.dmg/dmgMulti/cd/dmgtype；para1速度；weapon_motion的玩家/敌方pixels_per_unit | 普通齐射一次攻击；固定方向飞行，沿当前命中路径进入Damage；不追击已死亡目标 | 普通命中、目标先死、暂停、同帧多命中 |
| cannon | 同上；玩家速度再乘player_cannon_speed_multiplier；rail_*纯视觉 | 敌方普通炮保留飞行；玩家磁轨现行主命中在发射帧、余辉不再扣血，D06确认该既有例外；不推广为全武器发射结算 | 蓄力在CD末段、主命中恰一次、余辉无业务 |
| missile | para1每批枚数、para2巡航速度；ejection_gap/launch_speed/ignition/seek/cruise/turn/brake/lifetime/hit_radius逐项取Excel | 按间隔逐枚离管；目标不足轮转发满；已离管追踪原目标，目标死后沿末方向飞离不重锁，加速仍继续；尚未离管目标无效按既有选择规则处理 | 逐枚序、满批、失锁、生命周期、边缘发射 |
| longLaser | 基础伤害、cd伤害间隔、para1增长时长、para2增长上限、para3蓄力时长按有效表；冷却倍率也作用伤害间隔 | 从启动到中断为一次攻击；蓄力不伤害；有效脉冲命中，冻结攻击者参数和增长参数；失去主目标/中断停止链路；新装备/增益影响下一束 | 充能/脉冲/成长/中断/升级中途不改快照 |
| 追加/副本/连锁 | enhance_config与无人机贡献 | 普通齐射一次历史；独立追加齐射另计攻击；副本、连锁和beam tick只计伤害；普通齐射及其副本共享一次链额度，独立追加有自身额度 | 不重复历史、不递归、命中后主目标死仍按既有链规则 |

原始伤害取Attributes（05）→攻击快照一次暴击与效果判定→载体保存继承结果→命中时进入共享Damage。追加代数在源攻击有界规划，不在每个命中递归抽追加。正常连锁首次有效命中产生载体，到达才伤害；束链启动绑定，目标死断链，不自动替换。攻击者快照与目标即时防御各有清楚边界，不允许连锁绕过护盾。

选敌先取存活目标并把敌盾恢复结到当前命中时刻；非零伤害类型优先当前有效防御类型不匹配者，再按y降序、abs(slot−4.5)升序、slot升序。0类型不作抗性优先。此4.5中心常量也影响15槽选择，D13确认后迁入阵型配置，不能重排容器时顺带改变。

主线阵型10槽保留后排顺序；15槽为3×5，空位不压缩。异空间显式槽位采用其Excel x/y，F9评分图不是正式位置。尺寸/舰体轮廓、显示炮口与数值几何之间继续保持当前批准关系，本次不另改命中判定。配对模板attack_type与实际武器一致；counter仅表示玩家对敌防御的分类。

## B03 伤害与防御分层

敌方：对每次有效命中，应用共享攻击修正一次；先盾、后体，抗性按层类型匹配。某层减伤r时，消耗原始伤害额度为该层实际吸收/(1-r)，剩余额度进入下一层重新用该层抗性；r=1需专门处理不能除0。盾最大值=ceil(mon.shield×当前lifeRatio)，体同理。shieldRecovery是每游戏秒最大盾比例，超过shieldDelay后恢复，每次beam脉冲也刷新受击时刻；暂停/死亡不恢复，重生满盾。不能追加额外低伤害过滤。现行盾层吸收min(shield,max(1,incoming×factor))，不先ceil；体层在盾未吸收或仍有incoming时扣max(1,ceil(incoming×factor))。factor=0时盾仍有最小1吸收且不再向体溢出，这是当前实际行为，见D12确认极端边界。

我方：无人机免伤/反击等入口→共享原伤修正→无抗性短罩→记忆防护→当前普通盾→装甲；按模块维护防御损失/恢复/保护归属。中性保护不凭空获得体抗性。盾溢出先用其他有效盾，再到装甲；最终装甲记录应受过量伤害但实际损失夹到0。只有护盾与装甲均耗尽才走死亡/重建判定。表中的物理/能量/中性类型不能由贴图猜测。

收到攻击历史每个来袭攻击一次，即使被保护吸收；延迟付款不再增加历史。死亡转换只一次，击杀掉落只一次。伤害统计实际shield和HP损失分列，overkill不当实际损失；工具口径D07。

## B04 强化六类基础与分支

L=有效共享强化等级；c=全局历史；Q(x)=round(x×bonus_round_scale)/bonus_round_scale。熟练/适应基础倍率=1+Q(growth×L×log_base(max(1,c)))，作用后按属性管线取整。费用、门槛与排序见05。

下表每行A均在三个节点可选，按已启用A节点数量累加；B1/B2/B3对应本效果三个节点，数值均取enhance_config同名前缀，不能写死表中默认。

| 效果 | 基础 | A | B1 | B2 | B3 |
|---|---|---|---|---|---|
| proficiency | 攻击历史增加伤害 | 每节点加damage_bonus，先加后乘其他贡献 | 同一主目标每完整interval独立乘(1+growth)，副目标不重置主锁 | CD×interval_multiplier | 匹配敌抗性改用配置resistance |
| repeat | probability触发；伤害倍率1+repeat_growth×L | 概率百分点相加后夹0..1 | 首有效命中连额外targets个 | 有界额外再触发repeats代，源预规划 | probability另锁目标；导弹副本完整一批、束为副命中 |
| critical | base_rate与装备原生概率独立来源；暴伤base_multiplier+critical_growth×L+装备值 | 概率百分点相加 | 暴击后后续attacks次规范攻击获得damage_bonus，源攻击只消费一次 | 暴击增加整组stack，最多stacks，新暴击刷新duration，层增加概率/伤害 | guaranteed_rate是实际保底事件，底层概率的额外暴伤抽签仍独立 |
| adaptation | 来袭历史增加防御容量 | 每节点加capacity_bonus | 按敌UID共享旧层数减原伤，当前攻击后加层，上限stacks | 每interval生成本模块罩=(真实max+自身Memory上限)×capacity_multiplier，持续duration | 只加强已存在匹配抗性resistance_bonus，中性不获抗 |
| memory_material | 每interval回复自身max×heal_fraction×L；溢出形成保护上限max×buffer_fraction×L | 恢复和上限增加bonus | 全局实际正恢复跳只抽一次probability，触发减伤reduction持续duration | 来袭授予匹配抗性，异类清除并进入lockout；duration到期失效 | 启用盾数加overflow charge，启用装甲数加cap；不放大body heal |
| delayed_damage | s=percent_scale；q=max(1,ceil(s/(1+kL)))；incurred按max(0,(s−q)/s)拆分 | 每节点只全局加一次clear_probability | 队列实际清空后减原伤reduction持续duration | 不正常清债，以未强制的清除概率×conversion减原伤 | forced_probability覆盖B2；伤害增量按(1−底层概率)×damage_scale |

同类A容量/伤害/Memory加法；不同共享减伤乘法。熟练目标计时、暴击余势/整组层、适应来源层、短罩/记忆抗性等状态有界于当前模块/来源，来源死亡清理。换装/降容量时移除失效贡献并夹容量，不能治愈另一个模块。UI装备卡不包含同目标时间成长和限时暴击层，战斗包含；分支说明显示公式与当前有效门槛。

## B05 记忆与债务的精确时序

记忆每模块基于真实max而非保护后的max；没有Memory20B时所有启用模块贡献中性总池，但仍保留贡献归属。满上限且无实际回复不触发恢复概率。Memory20B的抗性只对本合格模块贡献生效，适应30B增强也同样限定。

债务先记录已减伤后的incurred；不能将盾当前容量把应发生的装甲overkill完全截掉。每份债务分为配置duration/interval确定的分期，合并到有界全局游戏时间桶；首期至少interval后，量化允许总完成延后小于一interval。到期先支付本期，再一次全局概率清除余债；无先抽签免第一期。付款顺序为当前短罩/中性临时保护→当前盾→装甲，不再减伤或延期；来源曾是装甲不妨碍已恢复盾吸收。

同刻债务支付先于记忆恢复与死亡检查；战斗清场阶段仍按规则付债。重排/换装不能免债；暂停冻结，离线不回放。模块失去资格保护夹除，但债务不会因装备对象消失丢失。死亡/全状态重置统一见09，不新增另一份“显示债务”。

## B06 无人机战斗效果

普通无人机即使白色无词条也有独立武器；装备槽外的DroneSource仍进入同一管线。词条同ID相加，放大项=value×(1+amplification_rate)^(level−amplification_start_level)。挂载同类效果相加，每架每类只能一份。相同传说按配置评分参数取最高，平分按稳定ID；不得每次攻击扫描全仓，装备变化时形成贡献。

| 传说ID | 规则与状态（参数取hyperspace表） |
|---|---|
| higgs_cannon | 炮伤×(1+damage_bonus)，宽度×(1+area_bonus)；maximum_cannon_sources含普通+无人机，换装前校验 |
| scatter_pulse | 激光对全部当前有效候选各发一份；仅一个目标时再×(1+single_target_bonus)；该齐射只计一次攻击历史，副命中继承源快照 |
| precise_guidance | 每主批次每目标首命中读取已有层B^stack并加一；同批继承首次因子；stack_limit_enabled才限层；不按导弹枚数叠 |
| prism_tower | 对该来源束最大倍率加maximum_multiplier_bonus，附近目标数取常量 |
| strange_matter | 合格炮命中按spawn_probability产生延迟全体伤害；击杀产生kill_spawns份；伤害=该炮原伤×damage_multiplier；派生不递归 |
| wild_missile | 每attack_period个普通主批次之后，下一个主批次替换为单枚狂野弹，获得damage_multiplier与blast_fraction；该次不生成普通追加/副本，派生不递归；周期计数归战斗 |
| laser_charge | 激光来源数×bonus_per_laser，夹maximum_bonus后作为1+bonus乘伤害；不重复乘 |
| endless_beam | 选定一个合法束来源增加最大倍率；主目标失效时保留同一束、蓄力/脉冲钟与冻结链数量，进入await_target，下一段开始才重绑合法主目标与链；不得在本批命中中途重绑。死亡/最终清场中断，普通束仍按B02中断；来源选择稳定 |
| dodge_counter | 概率=min(有效最高暴击率,maximum_dodge)；免本次伤害；反击仅cooldown到期，随机合法武器×(1+counter_damage_bonus)，不能无限反击递归 |
| drone_master | 取启用无人机最高品质ratio，减伤=maximum_reduction×ratio/ultimate_ratio |
| drone_rebuild | 致死时在maximum_stacks内牺牲最低品质、平分稳定ID的可用机；本遭遇禁用该机，加damage_and_defence_bonus，恢复防御/清债；遭遇后撤销禁用和加成不额外治疗 |
| black_hole | period到期进入absorption_duration；吸收双方攻击，累计友方raw，结束按damage_multiplier伤害敌方；派生不递归；计时归战斗 |

具体传说常量及品质ratio全量在小表内容账；固定规则页说明与实现冲突时列D，不能把说明字符串当执行开关。

## B07 生命周期与快路径边界

| 边界 | 战斗处理 | 表现处理 |
|---|---|---|
| 普通新波 | 保持允许在途弹体/源快照；敌人新ID，原死目标不复活；波次结束必须通过Progression | 不因换波截断允许继续的弹道 |
| 最终清场 | 本次遭遇进入既有完成流程，清理该清理的载体；奖励仅一次 | 爆炸/掉落/清场反馈保持原顺序 |
| 暂停/隐藏 | 暂停不推进逻辑；页面隐藏不暂停游戏 | 暂停按现有视觉策略；隐藏停无关绘制 |
| 换装/升级 | 保留既已出生快照，之后攻击读新参数；容量按05；旧债务不能丢 | 原载体保持外观，更新装备局部 |
| 读档/重开/重铸 | 整个旧会话失效，重建actor/flight/RNG与新状态绑定 | 断开旧引用、清理旧特效；不继续调用旧Game |

现行native准入仅低负载或rich15、finite标量，拒绝手动异空间和大部分强化分支；可用分支白名单目前是proficiency B2、repeat B1/B3。native并非完整玩法证明。新内核要补齐表中全部功能，统一大数；不能保留“不支持就转旧GDS战斗”的最终架构。保留已有快路径直到同工作量替代证明，未支持功能在开发版本明确不可验收，不假装删玩法。

保留SpaceCombatPresentation、retained常驻表、MultiMesh、shader clock/12-float实例布局等有效机制；更换接口时测量跨语言调用/分配/上传量，禁止每步全场Dictionary转换。GPU shader处理位置/形状/颜色，不读写权威生命。native内部运动是当前命中规则所需，不以“纯表现”名义挪走结算条件。不得未经证据将native运动或批次改成GDScript逐弹更新。

## B08 敌方独有字段与边界常量

mon.equipment按安装顺序展开武器及数量；enemy_weapon_base只用于Excel声明允许的缺行/空字段继承，编译时生成完整武器，不在运行遇错误才取代码默认。敌我武器参数有各自单位，不能用玩家成长行替换敌武器基值。armourType/shieldType=0中性、1能量、2物理；0不代表随机类型。

reactiveReduction启用时，当前命中与上一齐射窗口相差>0.16秒才换窗；距前窗<=2.2秒时层数+1、最多3，否则归0；同窗不叠。原伤×(1−0.2×层数)，随后进入干扰/护盾/体管线。首窗0层；每敌独立，死亡清除，显示层数和倍率只读。0.16/2.2/3/0.2尚为代码常量，移入Excel保留当前值供审阅，不从intelMechanics文案生成数值。

现行干扰和击杀爆炸关联强化派生：敌人interference在原伤上乘1+值；jewelExplosion在死亡后以该敌maxHP×值影响相邻目标，走同一伤害管线，派生标记防止重复触发。历史jewel前缀不意味着复活旧镶嵌系统；没有当前有效来源的遗留字段删去，不能因旧字段可序列化就给新敌增加技能。是否仍有有效配置入口列D14，未决期间不补回旧成长。

每次死亡先完成原命中的唯一归属，再结派生、掉落与波次。异常actor引用/已死目标不产生第二次伤害或奖励；事件中的HP损失按实际夹界值，overkill单独可选诊断，禁止负HP统计放大。A-BTL必须覆盖盾极小余量、完全匹配抗性、反应装甲同窗/超窗/重置、派生导致另一敌死亡四类交叉场景。
