# G2 强化深化记录

本批替换原强化范围卡，不恢复旧宝石装备/成长。A直接呈现两条作用顺序，B在战力组上下文中操作相同效果与顺位；共享高效动作。六效果以卡片和分支为主体，按M5设计，不虚构需要拖线的设备。

实际内容：购买G/世界额外B/有效E分别呈现；买1、最多10、实际可购数量/合计碎片报价，默认不足。内部情境资金允许展示最多10实际成交2级；报价是显式样本，不是前端费用公式。成交后保留顺位/分支并等待下次真实报价，不反复套同一报价。

武器熟练/连发/暴击与防御适应/记忆/延迟均显示实际顺位、主效果摘要与三节点门槛/当前路径/是否生效。前移调用既有move_forward含首位与末位互换语义。节点详情为可追踪子路由`enhancement/branch/{effect}/{node}`，先显示A/B实际规则、门槛、当前路径，再保留候选并确认。未满足门槛保留已选路径但禁确认；连发节点2的B不启用第二代连发、不得选择为已启用效果。当前暴击B3说明区分效果触发率与额外暴伤机会。

浏览器定向核对：六效果存在；节点候选不改当前；确认后路径改变；前移改变实际顺序与门槛，旧路径保留；未开放确认禁用；连发节点2B禁选。未做native/游戏测试，没有宣称V5通过。精确动态历史乘数、分支后完整当前效果摘要、已购后的连续报价与实际领域失败接线仍待原线程模型，视觉密度与最终卡片美术仍可修订。

Godot：EnhancementPage → level/quote Controls + 两组ordered effect cards ScrollContainer + BranchDialog。稳定effect id使用`proficiency/repeat/critical/adaptation/memory/deferred`；UI不把规则文档名`memory_material/delayed_damage`当命令键。每卡仅派发move_forward(effect)；选节点保留UI草稿，确认调用set_branch(effect,node,choice)，失败保留实际路径及候选。切页保留effect/node和顺序，收到提供方完整快照后更新门槛/有效状态，不在UI从位置重新计算规则。BranchDialog最终用原生模态焦点/返回规则，关闭回原节点；当前浏览器为浮层工作点演示。符号/边框为前端矢量图形，不复用旧宝石背包资源。

给原线程的最小展示缺口：现行`enhancement_inputs`只是命令准入，没有专用presentation。需要G/B/E、可用性/原因、真实weapon/defence顺序、每效果主门槛/开放/实际效果摘要、三节点门槛/已选/是否生效及禁用原因、买1与最多10的实际成交数量/合计Amount费用/允许性、成交后的刷新快照。全部由Enhancement现行规则提供；不解析published_output的内部数值键来猜语义、不读私有_state、不由UI计费。
