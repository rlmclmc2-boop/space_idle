# 40模板独立只读审查

> 最终收口：已只读复核父端Lv1直接/后备解析小修，并独立运行Python14拒绝＋2合法重排验证通过。该直接JSON API边界已闭环；没有剩余当前40模板数据/实现阻塞。新20数值门槛仍未验收，补偿建议未执行。

审查快照f0162524a8d1839e505859718923c57f0c4dc53d，base b3767d1452ab0a4c100f3bc4f26d51c7113a6c0f；配置SHA256acb8a969bc0f576070d713e1e0d79ed57c0fdd1e71e73f6ea8e67b452602c83a。本轮没有运行战斗、矩阵或长期测试，没有改正式源表/代码/分支；仅内存解析与畸形校验复现，产物写在独立审查目录。

## 结论

40模板的实际数据配对正确；原20的数值、防御、成长与关卡保留。现有32样本足以证明物理输出变体真实进入既有防具响应链，也证明部分旧前档失败已转胜，不能把新增20称为最低档已验收。发现一处validate_projection直接API与运行时解析不一致的可复现边界；正常XLSX导入会预先规范化而避免它，因此不构成当前40源候选的发布阻塞。

## metadata独立API边界（正常源导入已避免）

`tools/import_workbook.py:validate_attack_pairs`从equipment[name][0]读取dmgtype（base fallback也取[0]），而`scripts/database.gd:34–58`的equip(key,1)寻找level==1，`enemy_weapon:105–119`再对空值做enemy_weapon_base/base fallback。不过`convert_sheet(equipment):86–98`在正式导入时过滤所有非Lv1行、检查重复并排序，正常XLSX来源因此只留下Lv1，当前源导入没有此错配。

独立私有内存复现：复制laser_mon原行到数组头部并设level2、type1；把原Lv1行type改2。validate_projection仍接受，运行equip(laser_mon,1)会选type2，与energy_attack声明冲突。当前12畸形测试未覆盖此直接JSON边界。若validate_projection也承诺独立验证非导入器规范化JSON，建议使用和运行时一致的Lv1选择规则，显式行与base后备行都覆盖；添加“非Lv1头行不能遮蔽错误Lv1”的拒绝用例，以及合法重排行接受用例。若其契约只接受导入器规范化投影，则可明确该前提，无需为了当前40有效源候选扩大修复。本审查未擅自修源码。可选metadata缺省兼容、双向配对、目标/防御/槽位/挂点数检查本身未发现当前数据违例。dmgMultiple未纳入防御身份是合理边界，未来火力补偿需另授权，不应被防御克隆约束误阻。

## 独立数据与范围核对

- 17文件diff没有scripts游戏攻击实现、视觉资产或资源改动；新增导入校验、CACHE_VERSION8→9确保重导时采用新校验。原有API无需增加参数或分支。
- 对base JSON逐项核对全部旧enemies/groups，均完全相同；新60敌、20group。20旧battle_design剥去新增4元字段后与base完全相同，新变体group/enemy为+1000逐槽映射。
- 克隆敌除id/des/equipment外全部字段与原敌一致，包括health、size、armourType、盾四字段、drops及当前dmgMultiple。所有原挂点laser_mon、变体cannon-mon，防御身份没有从输出类型倒推或更换。
- 旧equipment所有数值、成长、费用未变，只两敌方行des更明确。其余JSON业务区全部与base相同，source_files仅路径更新；levels没有自动加入新组，星系/星球等也未修改。
- 独立调用只读read_changed_file解析mon、monGroup、equipment、battle_design四XLSX，与对应JSON逐项相等，正式validate_projection接受当前数据。
- 实际显式laser_mon=type1/dmg20/cd0.5/速度20；cannon-mon=type2/dmg40/cd1/速度20。两者显式值不被enemy_weapon_base覆盖。18对逐舰ceil后的raw DPS相同，elite_neutral2/4物理低约0.214%；不是所有逐帧到伤/首发/触发次数一致。
- 美术契约正确区分进攻type、HP armourType、盾shieldType及max_shield。counter仍指玩家攻击优势；boss_physical_physical_attack的两段不能合并推断防御/攻击。metadata是可选导入标注，实际效果仍读取db.enemy_weapon；已有美术读字段足够，不需要该候选改渲染或RNG。

## 测试证据的真实性与限制

Python正式12畸形通过日志已读；独立重算源投影与克隆/旧数据不变，不把此称新增战斗运行。GDScript最终日志`runtime/test_enemy_attack_pairs-final.log`为230检查0失败；源码先真实解锁盾，再从模板取实际weapon，走fire→tick_projectiles→hit_player，用等raw100隔离减伤，覆盖现值0.5和私有0.25、带盾/无盾。此前漏盾解锁的211检查2失败日志保留，修复夹具未改生产规则。230检查覆盖当前40各挂点类型，但只有代表配对做归一化伤害响应，不能说40模板均完整战斗验证。

当前32行=16原+16物理、5对，唯一键/seed1701/speed1/Presented/原生critical/最终配置均匹配，输入没有武器或敌人override。24胜8败。独立16对照在paired16-independent.csv，只有双方获胜才计算TTK差。全部共同获胜的目标档TTK相同；6个前档从败转胜：精英光束、物理Boss、能量终极各1，加精英中立1的laser/cannon/longLaser三项。精英中立1 missile+0仍败（物理存活21.416667秒、原能量17.05秒，不是通关）。

|配对/武器|前档变化|物理前档余甲/盾|目标档原→物理余甲|目标档TTK|
|---|---|---|---|---|
|elite_longLaser/beam|+0败→胜21.233333|1773/480|2696→3579|18.15|
|boss_physical/beam|+1败→胜35.166667|2595/0|3000→5090|29.85|
|ultimate_energy/cannon|+2败→胜70.566667|4423/54|4340→6737|60.016667|
|elite_neutral1/laser|+0败→胜25.516667|263/0|1324→2675|21.4|
|elite_neutral1/missile|+0仍败|0/0|1659→2185|20.183333|
|elite_neutral1/cannon|+0败→胜28.433333|556/54|2422→2741|21.416667|
|elite_neutral1/beam|+0败→胜20.7|1461/120|3016→3340|18.466667|

普通laser+0/+3原物理均胜9.8/5.683333；余甲相同，物理余盾少91/45，恰好展示盾尚完好阶段物理更耗盾，并非所有阶段物理都更弱。

## 防具响应预期与门槛移位

减伤0.5、单能盾S+单复甲A、忽略恢复/取整/触发时，纯能量承受raw预算=2S+A，纯物理=S+2A。该固定构筑A约2S，因此物理总预算约多25%；其盾更早耗尽，但较大的装甲池承受物理减半。这是既有防御克制预期，不是新增规则bug。等raw100真实路径检查支持这个分层关系。

样本目标档实到raw也并未系统下降：elite beam两版10200；Boss物理12760对能量12540；终极15576对15180；中立beam10452对9990。物理收到更多raw仍余甲更多，不能把当前门槛变化简单归咎变体原始DPS低。实际首发/周期0.5→1、有效hit刷新、恢复间隔、阵亡次序与取整共同影响结果，不能把25%全当唯一因果。

若目标只是让不同防具有价值，这种门槛变化可以是预期结果；若另要求克隆配对仍有相同最低升级门槛，则上述样本说明物理版对该固定盾甲构筑的有效威胁偏低，需另作数值校准。当前status=paired_template_pending和继承min_upgrade只是待调目标，未构成已验收事实。

## 仅新抽样变体的补偿建议（未执行）

不建议统一提升全部新20，更不改原20、玩家成长、防御身份或敌数量。普通laser当前目标+0已胜，无前档失败目标，不必为这次门槛补偿改它；其他15未抽样配对不能凭5对推定需同倍率。

理论×1.25只作静态EHP等价参照。利用物理获胜轨迹已到达raw D及剩余等效池R=2×余甲+余盾，冻结命中轨迹、恢复额度和取整后，耗尽预算的估算倍率为1+R/D：精英beam前档1.3355、Boss1.3469、终极1.4816；中立三胜前档laser1.0361、cannon1.0937、beam1.2574。目标档同估算最紧中立missile约1.3841，其余目标档更宽。这些是解释性预算，非可验证的胜负阈值：改火力会改变盾耗尽、恢复受限及终局时机。

若后续获授权只做一次最小定向候选，可围绕下列相对当前dmgMultiple范围讨论：

|仅新组/敌ID|候选倍率范围|当前→候选每敌dmgMultiple范围|
|---|---|---|
|elite_longLaser_physical_attack，2062/2063|×1.30–1.35|7.5→9.75–10.125|
|boss_physical_physical_attack，2087|×1.30–1.35|11→14.3–14.85|
|ultimate_energy_physical_attack，2090|×1.45–1.50|6.6→9.57–9.9|
|elite_neutral1_physical_attack，2067/2068/2069|×1.25–1.30|0.1→0.125–0.13；12→15–15.6；5.5→6.875–7.15|

这些范围不是批准参数或通过承诺，下缘仍可能无法压回前档；尤其终极×1.25未必足够。中立较小侧船受ceil影响不严格按倍率增长。若实际选择一个候选，每组仅复核其原前档/目标档；中立保留四武器相邻档；不得因理论建议启动盲循环或全矩阵。本轮不执行。

另一个证据限制：原探针失败后begin_retreat清空enemies，按剩余enemies汇总incoming_raw_by_archetype会得到空字典；这不是“失败没受伤”。本报告只在获胜记录上使用D，失败胜负/存活时间不受此汇总限制影响。

最终判断：原20保留、40实际配对/正常源导入/API美术范围可接受；未发现当前数据或生产攻击规则阻塞。metadata独立JSON验证的Lv1边界已披露，不夸大成当前源候选缺陷。新增20的平衡门槛明确未验收，5对样本和补偿预算不能扩大为40完整验收。

审查纠正：最初即时消息将非Lv1行序问题视为源导入缺陷；随后检查convert_sheet确认旧高等级行被过滤，已主动向父端更正影响范围。本报告保留可复现的直接API差异，不再把正常XLSX导入描述成易受影响。

## 父端小修后的最终收口

父端在f016252之上修改import_workbook的直接装备与base后备解析，均显式查找level==1；CACHE_VERSION提升10。独立检查diff与测试，先前私有JSON复现已由新增畸形用例覆盖。直接行用完整validate_projection检验合法/非法重排；base后备用validate_attack_pairs独立API检验（为触发fallback临时省略enemy_weapon_base.dmgtype，而正式完整schema要求该字段，故没有伪装成完整源投影用例）。

独立执行PYTHONDONTWRITEBYTECODE=1 python3 test/test_enemy_attack_pairs.py，14畸形拒绝＋2合法重排通过；日志python-final.log。没有重跑230 Godot检查或任何数值样本：本次修复只影响导入校验，四源投影、现有配置与游戏运行实现未变。配置SHA仍acb8a969bc0f576070d713e1e0d79ed57c0fdd1e71e73f6ea8e67b452602c83a。审查时import_workbook.py SHA256=1fe65c8af4cb8d7736cfeab338220f158ee65a3f9ceb18e7a08dfb832598db34；test_enemy_attack_pairs.py SHA256=982b02a16b7909db21afd9f788cc592cbdaac2a1b62883720ad70258d4ef223b，补丁当时尚未另commit。

此次发现应明确记录为直接JSON校验API一致性修复，不是40个XLSX模板原来实际输出错误。结构/来源/进攻防御身份/美术契约审查收口可接受；新20最低档仍待后续授权校准，不能把这一结构接受当作40模板全部数值验收。
