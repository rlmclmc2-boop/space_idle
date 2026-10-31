# 装备逐点击影响范围

基线 `7a4c3cf2`：[原始计数](evidence/performance-before.json)；修正 `d2bb4cb9baf7cbb2033b4afbf7839213fcbf1fa4`：[原始计数](evidence/performance-after.json)。同一执行线程、同一4.7.2/native/config/正式main路线，没有另开复测线程或改其他模块。

每次运行均通过正式Session/所有者验证受控存档状态，以真实start_sortie进入第5关，等到真实敌舰和在途攻击存在后，使用原有用户暂停隔离一次点击。暂停的是业务时间，Godot和BattleView仍正常不限帧绘制，没有减少表现预算或改业务换取计数。两版沿用相同本地验证设置；这不是长时间全效果FPS基准，也不声称两次启动的随机种子或整个战斗状态逐字相同。重点是**每次动作自身前后**对象和队列是否被替换。

记录每个节点instance ID、按钮normal StyleBox对象ID、标签文本、Battle/kernel/Presentation/Statistics对象ID、各舰图资源ID、敌方缓存数组身份、native workload_metrics/persistent状态及通知次数。既有原生只读查询用于观察，没有额外消费take_results、伤害回执或统计事件。驱动代码见[evidence/performance-driver.gd.txt](evidence/performance-driver.gd.txt)。

## 局部冗余与修正

基线没有全节点重建，但`_refresh`每次都为5槽、4候选和3数量控件重建normal StyleBox，并请求整个装备场景draw；冷却每0.1秒还重新查询完整比较/MAX。这是本次新面板的局部冗余，已直接修正。

现在槽卡与候选使用呈现签名跳过无差异更新；付费等级只改该槽文字，不重建其选中边框。数量只更新旧/新选中样式。只有舰体/有效挂载装备身份变化才请求机库主体draw。冷却仅读取实际slot_facts并更新文字，跨过到期边界才重新查询所有者准入。固定键的`presentation_counts`仅为呈现诊断计数，不作为状态或规则来源。

| 实际动作 | normal样式对象替换：前→后 | 装备主体draw：前→后 | 修正后必要影响 |
|---|---:|---:|---|
| 同武器类别槽选择 | 12→2 | 1→0 | 旧/新两槽选中边框，1次当前比较查询 |
| 数量选择+10 | 12→2 | 1→0 | 旧/新两个数量样式，1次真实报价/比较 |
| 待装舰炮浏览 | 12→2 | 1→0 | 两候选状态，1次同口径比较，未提交 |
| 批量打开 | 0→0 | 1→1 | 原有模态显示及GUI顺序重排引发一次引擎draw；无业务发布 |
| 批量关闭 | 0→0 | 0→0 | 原有模态隐藏，无业务发布 |
| 实际+1 | 12→0 | 1→0 | 1槽文字、1次比较；钱包/报价及结果按实际更新 |
| 实际+10 | 12→0 | 1→0 | 同上，未更新其他槽卡/候选/数量样式 |
| 实际MAX | 12→0 | 1→0 | 同上，MAX数量与成交仍由原所有者搜索 |
| 实际换装 | 12→2 | 1→1 | 1槽、两候选，必要挂载图像与1次配置发布 |
| 暂停中冷却UI约0.7秒 | 12个末态样式均被替换→0 | 7→0 | 7次冷却事实读取，0次完整比较/MAX重查 |

无差异空闲12帧：0刷新、0比较读取、0槽/候选/数量更新、0装备draw。上述每个动作均**0节点新增、0节点删除**；打开/关闭操作没有重建整个批量台。跨武器/防御类别只保留各类别实际候选控件，不把类别变化造成的必要选项变化说成全局重建。

## 升级到战场的实际范围

三次真实购级，各有 `slots_changed=1`、`wallet=1`、`loadout=0`、`ship=0`、`statistics.changed=0`（暂停中没有新伤害），`configuration_commit_delta=0`；Battle保存的属性差异都只有 `weapons["weapon:1"]`，没有改变无关武器/防具。每次均保持Battle/Kernel/Presentation/Statistics对象、节点及舰图资源对象；敌方数组身份及内容保持；已有1个实际在途攻击、flight_slots/active_capacity/feedback_capacity、encounter/attack/drop身份与历史保持。

真实路径为：

1. [Equipment._submit_levels](../../../src/systems/equipment.gd)保留实际变动槽；`values(..., changed_only=true)`只消费待接纳变动槽。
2. [Session.publish_equipment_levels/_commit_values](../../../src/game_session.gd)调用既有付款/原生发布及接纳；钱包和槽位通知在接纳后各一次。
3. [Battle.commit_values](../../../src/systems/battle.gd)调用native `set_player_values`，按差异更新保留的_values；不经过`commit_player`、模型加载或表现初始化。
4. [native set_player_values](../../../addons/native_battle/src/combat_execution_kernel.h)按id/key/generation找到既有来源，更新必要base/付费等级/出生配置或防具容量。没有clear_encounter、整场池清空或重载舰图；已出生攻击保留出生快照。

源代码路径与实际对象/队列计数相互印证。资源对象未被替换的计数是运行观察；没有声称对每一次ResourceLoader调用做全引擎追踪。模型读取仅在Battle初始化，机库舰图也在构造时保留强引用，没有逐次点击重载。

换装的必要区别：本次有 `loadout=1`、`configuration_commit_delta=1`，仅 `weapon:1`的身份/属性发生变化，native新来源调度使emitter序号14→15；encounter和attack序号、无关敌舰和现存飞行池保持。原生对被卸下来源的自有持续光束可能按既有规则退役，并过滤失效来源队列，这与清空全场不同；本次保留的是实际已飞出的导弹。没有在UI重写该规则。

BattleView每个动作仍绘制约5帧，冷却观察期约30帧；正常`queue_redraw`、GPU上传和伤害统计随模拟推进的变化不是模型/场景/池重建。本次没有修改BattleView/native或降低刷新频率来取得数字。

## 原始失败及限制

基线原始JSON保留1条失败：旧驱动错误要求“换装后所有persistent字段完全相等”，而实际仅新来源emitter增加1。修正后的诊断对换装保留必要emitter变化，仍严格检查encounter/attack、历史、敌舰和飞行池。没有改写基线记录或称它当时已0失败。修正版11动作0失败，最终同版装备操作检查另为0失败。

当前证据覆盖上述受控的逐点击因果范围，不关闭长期战斗、全舰型/全装备/多敌人组合、GPU压力、DPI或跨平台性能。未发现需要跨模块重写的缺陷，本批只消除装备呈现自身的无关更新。
