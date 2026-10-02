# 美术读取契约（不引入美术实现）

发布基线b3767d1已有下列运行数据；本40模板候选仅添加可选配对元数据。美术独立验收，不依赖本候选合入。

|语义|读取来源|注意|
|敌方实际进攻类型|`enemy.equipment[].name` → `db.enemy_weapon(name).dmgtype`|1能量、2物理；逐挂点解析，不能从组名/counter推断。现发布20组均laser_mon；候选物理配对组cannon-mon。|
|敌方生命抗性|`enemy.armourType`（mon.xlsx同名列）|0无类型抗性、1能量、2物理；这是承受玩家攻击的身份，独立于敌方输出。|
|恢复盾能力|源表`shield/shieldType/shieldRecovery/shieldDelay`；运行`max_shield/shield/shieldType`|能力存在看`max_shield>0`；当前强度看`shield/max_shield`，不能因当前盾为0就判为无盾模板。容量受生命倍率缩放。|
|恢复盾时间|`shieldRecovery`为每秒最大盾量比例，`shieldDelay`为有效命中后游戏秒延迟|每次有效命中刷新；连续有效光束周期压制恢复。无固定低伤吸收层。|
|舰体尺寸|`enemy.size`（mon.xlsx `size`）|1–6既有尺寸身份，不等于挂点数/伤害类型。|
|组主题|`battle_design[group].tier/counter`、`group_id`及monGroup `description/slots`|tier normal/elite/boss/ultimate；counter是玩家优势武器/所克敌防御主题，不能作为敌方开火类型。15槽三排五列，空槽保留；旧10槽仍支持。|
|候选配对标签|`pair_id/attack_variant/attack_type/paired_group_id`|40候选新增，energy_attack/physical_attack及1/2只标敌方输出；原版和变体保相同防御身份。旧数据没有这些字段，读实际武器即可。|

美术只读取现有状态，不为识别效果改变武器、伤害/抗性、恢复时序、size、目标选择或RNG。主题角色和攻击/防御是独立轴；例如`boss_physical_physical_attack`前半是原主题，后缀是新增输出变体，具体抗性仍以字段为准。
