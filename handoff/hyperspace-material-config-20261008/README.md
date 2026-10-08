# 常规异空间材料与采集器配置交接

基于本线程e3cdefd，独立分支tutorial/crew-idle-efficiency-20261008；没有跟入未完成核心。仅改权威hyperspace_config.xlsx、结构投影schema、hyperspace_config.json、模块UI文字及Python导入校验。不改drone_rewards/forge/system/state/hyperspace_commands/game.gd。原玩家存档与游戏进程不动，未启动/复测GUI。

## 给BUG的准确接口

- material_unit_scale：正整数，默认10。作用于完整常规材料公式：material_base_reward+floor(max(0,level-material_reward_start_level)/material_reward_level_step)，再含原补给倍率。探索材料、拆解常规材料返还、所有以四种材料计价的改造消耗统一按此换算。表内基础奖励、拆解基础值、forge_costs基础消耗、modernization_cost_base等仍保留旧单位，运行时只应用一次scale；不能再将这些原值另乘10造成×100。四种材料来自现有路线：degenerate_matter/glueball/antiproton/zero_point_energy。
- ultimate_core_probability：有限[0,1]，默认0.002，即成功探索实际0.2%。应独立抽样，不能塞进相对权重再归一化，不受幸运/材料倍率/采集器影响。quality_weights.ultimate_core旧兼容项0.1保持原值，BUG必须从品质权重抽样中排除它，并使用本新概率字段；本配置提交尚未让旧核心获得新概率。
- hanging_modules.hyperspace_charge保留ID、等级/经验等旧存档身份；显示名“异空间采集器”，effects=['hyperspace_material_income']，effect_growth仍0.1。每架已装采集器提供(1+g)^L−1加成，同类沿现有方式相加，整体材料乘1+sum(bonus)，最终向下取整。只影响常规探索材料产出，不给究极核心倍率，也不把拆解产生的挂设副本数乘10。全局等级与加成读取由BUG现有聚合路径处理。
- ultimate/restore_ultimate两项ultimate_cores=1原样保留。究极核心奖励个数与消费不缩放，也不吃采集器。

举例（配置算式，不是实机掉落）：level5/8/200的旧基础为1/2/66，换算后10/20/660；200级原后期材料倍率4得到2640。单Lv2采集器=21%时最终floor(2640×1.21)=3194；两个相同Lv2为42%，得到3748。gold拆解原5份常规材料应返50，但挂设副本仍按原5份数量；改造add_affix原1份常规材料应花10，究极改造仍花1核心。

## 权威投影与检查

基础参数新增两个字面量行；挂设成长仅hyperspace_charge effects_note改为新材料标识。固定规则_兼容说明中旧effects/0改材料效果，移除旧容量effects/1只读行；schema同步映射，不留越界数组路由。首次投影检查发现该旧effects/1路由导致IndexError，修正权威说明/结构后通过；没有删断言或放宽校验。

已实际运行两本权威工作簿read_bundle完整投影校验：输出hyperspace_config与提交JSON完全一致，其他全部输出与现有仓库JSON一致。非法scale(0/负数/小数/bool/inf)和概率(负数/>1/bool/nan)拒绝；概率0/1/.05及scale7有效。核对工作簿原单元格只变采集器说明及撤销的能量路由，费用/拆解/品质权重数值均保持原值。UI合同检查通过，diff检查通过。没有运行游戏掉落测试或用日志推断实机效果；实际经济×10、核心0.2%、采集器与旧档迁移由父整合BUG代码后验收。

完整基础×10应对每个层级成立，高层不等比例缺陷不能用只改base_reward掩盖。runtime hyperspace_config.gd新字段验证归BUG核心负责，本线程只加权威Python导入验证。
