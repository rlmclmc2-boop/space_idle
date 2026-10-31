# 全游戏实现来源核查（2026-10-31，静态）

审核主体：单独 Astra high，独立源码/Git/文档来源核查。没有运行游戏、构建、性能测试或独立复测；没有修改生产代码/实际游戏资产/Excel，也没有合main。下述“吻合”只指所列行为与来源可对应，不是功能、视觉、数值或性能验收。

覆盖按真实系统目录而非抽样挑模块：15个src/systems所有者、Session/Main/CombatSetup、foundation四宿主、native Amount/战斗核/retained表现/磁盘接口、config_tools发布、实际UI及保留呈现脚本。每个系统均追过核心命令、提交/恢复或读取边界和成形/重组提交；所有五制作源相对main的生产文件差异已盘点，native在六源字节相同。不是逐行证明每条公式、全部合法状态或全部资源依赖均正确；未决和未覆盖明确列出，不称“全游戏已验收”。

证据等级：E1为本线程父转原用户消息；E2为当前规范/工作簿与固定源码；E3为旧文档/提交/作者记录。E2/E3不能伪称原用户原话，尤其不能压过E1撤回。现存规范也可能有未决项；没有具体冲突证据的模块不能统称“按旧文档做错”，更不能自动删功能。

## 固定来源

|源|固定SHA|
|---|---|
|main|`e3b38d7b6d8256f6031e1b086c7db7812b6a441f`|
|equipment|`bb4c7bceb39ef9c8f014662bd767ebca9008bde5`|
|reactor|`519fd7ee82b5c54785bd53b4e36e50f768b6b6de`|
|planet|`a40cbae14204f68254f46e0b2a69bb51ac5d00aa`|
|host|`5df3d3dd59cf4fcd427f0fb9e719ad3a0a9e6969`|
|backend|`c38f1c2b06478d1d8b6e98b8571240e693e296fc`|

以上是分别读取的快照，后续HEAD/WIP可能变化。equipment运行81744e5a；planet运行662952f7。最新保存纠正c38位于backend，资源实现仍f924。制作分支未互相整体集成，不能混版本拼验收。

## 覆盖矩阵

|系统|当前源码（固定Git/行）|读到的关键行为|有效依据|关键引入/恢复/重组提交|分类与结论|
|---|---|---|---|---|---|
|战斗出生、即时炮、导弹/光束/派生|[addons/native_battle/src/combat_execution_kernel.h:128](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/addons/native_battle/src/combat_execution_kernel.h#L128)；[src/combat_setup.gd:5](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/combat_setup.gd#L5)|出生快照、generation、主/派生触发门控；即时炮与飞行载体区分；连锁机会独立、反馈取走后清空。|02§3–7、05§5（E2）|[22241120](https://github.com/rlmclmc2-boop/space_idle/commit/22241120c54b631d5f3b321151230b151e74fb19)成形，[9e6d3e34](https://github.com/rlmclmc2-boop/space_idle/commit/9e6d3e34acee0f5ec8e9ab5d4a114596e289b015)规则补齐|六源native相同；身份模型有A2差异，不能称全部命中规范已实现。|
|敌盾、受击、死亡与重建|[addons/native_battle/src/combat_execution_kernel.h:1142](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/addons/native_battle/src/combat_execution_kernel.h#L1142)；[addons/native_battle/src/combat_execution_kernel.h:1298](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/addons/native_battle/src/combat_execution_kernel.h#L1298)|受击/延期结算后盾甲双零才尝试重建，失败终止；重建消耗符合条件无人机、恢复防御。|02§4盾甲双零/重建；13 M1（E2）|[6d1b7780](https://github.com/rlmclmc2-boop/space_idle/commit/6d1b7780989a4f4e0c5ef4fb092d0d68c815fb9f)纠正只看装甲判死；[7f77acf6](https://github.com/rlmclmc2-boop/space_idle/commit/7f77acf6cffd5b1a11b147a8d38dafea3424ccb8)敌盾出口|该受击链吻合当前规则；换型链另见A3，不将两者混为同一路径。|
|战场统计、掉落与表现|[src/systems/battle.gd:374](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/battle.gd#L374)；[src/systems/battle_statistics.gd:18](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/battle_statistics.gd#L18)；[addons/native_battle/src/combat_execution_kernel.h:2394](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/addons/native_battle/src/combat_execution_kernel.h#L2394)|native只给已发生结果，宿主登记掉落、统计实际盾/甲损失；静态船/真实炮口与retained绘制分工。|01结果顺序、02§8、05战斗核；M1（E2）|[c6282ef6](https://github.com/rlmclmc2-boop/space_idle/commit/c6282ef6b317ed67fe277a7369acab3f647f463d)统计归属；[de1a96ae](https://github.com/rlmclmc2-boop/space_idle/commit/de1a96ae8b43cd5d650972ee861efe7b65abd9df)真实光束口|未找到撤回后恢复旧战斗实现的具体证据；不据源查代替视觉/性能验收。|
|装备槽、报价/成长、换装|[src/systems/equipment.gd:311](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/equipment.gd#L311)；[src/systems/equipment.gd:620](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/equipment.gd#L620)；[src/systems/equipment.gd:622](https://github.com/rlmclmc2-boop/space_idle/blob/bb4c7bceb39ef9c8f014662bd767ebca9008bde5/space-battleship/src/systems/equipment.gd#L622)|Q取整/低级特例、付费与奖励等级区分、批量顺序验资；main仍锁同槽，装备已零锁。|03§1、M2当前免费立即换/切回；全局数量规则（E1/E2）|[ee9173ec](https://github.com/rlmclmc2-boop/space_idle/commit/ee9173ec6e78e9d47e98355061e687f8cdfbef67)Owner重组；[4dd4f123](https://github.com/rlmclmc2-boop/space_idle/commit/4dd4f1238ad59517965409b58eb52fb3acb14438)去换装锁|A4分支未集成；不是main证明锁仍获准。首防御槽换型见A3。|
|反应堆分配、购级与舞台|[src/systems/reactor.gd:112](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/reactor.gd#L112)；[src/ui/reactor_scene.gd:648](https://github.com/rlmclmc2-boop/space_idle/blob/519fd7ee82b5c54785bd53b4e36e50f768b6b6de/space-battleship/src/ui/reactor_scene.gd#L648)；[src/systems/reactor.gd:335](https://github.com/rlmclmc2-boop/space_idle/blob/519fd7ee82b5c54785bd53b4e36e50f768b6b6de/space-battleship/src/systems/reactor.gd#L335)|main单级/直接分配；工作分支整组金额预览、直接接纳、数量循环与MAX；519f分件R3及整数报价。|03§2、M3、14 reactor；D10原用户无需确认/还原（E1）|[526c6e56](https://github.com/rlmclmc2-boop/space_idle/commit/526c6e565270e44b7d43cd9fa92de4a4383c4e87)继承draft；[3264858b](https://github.com/rlmclmc2-boop/space_idle/commit/3264858bab136d504eefb938e7582035702ecd60)分配计划；[519fd7ee](https://github.com/rlmclmc2-boop/space_idle/commit/519fd7ee82b5c54785bd53b4e36e50f768b6b6de)R3|旧文档“确认/还原”错误已删；当前直接接纳并非缺确认缺陷；根协调者16:06对519f整页检查退回，原组返修；不是仅待原独审或已验收。|
|科研投入/项目/完成|[src/systems/research.gd:298](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/research.gd#L298)；[src/ui/research_panel.gd:20](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/ui/research_panel.gd#L20)|单资源工作、自动选择、投入草稿apply/reset；按可支付工作片扣款、完成清工作、不把尾段推进另一项目。|03§3、M4、research分册（E2）；D10仅反应堆不可扩删科研草稿|[526c6e56](https://github.com/rlmclmc2-boop/space_idle/commit/526c6e565270e44b7d43cd9fa92de4a4383c4e87)draft；[411cfa9b](https://github.com/rlmclmc2-boop/space_idle/commit/411cfa9b47f614fb0fea2aff7b189fa66f8dc03a)输入刷新；f924整数服务进度|规则来源可对到现行03，未找到明确被撤后恢复证据；服务整数是A5跨分支差异，AI设备映射D3尚未定。|
|船员指派/经验/自动操作|[src/systems/crew.gd:170](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/crew.gd#L170)；[src/systems/crew.gd:211](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/crew.gd#L211)；[src/systems/crew.gd:299](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/crew.gd#L299)|成员唯一占用、目标/容量校验、任务工效按岗位读取；equipment/research/enhancement/reactor自动命令；完成经验二分升级。|03§4、crew分册/M6（E2）|[63ddd481](https://github.com/rlmclmc2-boop/space_idle/commit/63ddd48104ba9cc47fd3666a1a8fcaba5fcd102d)世界系统；[911ab0d0](https://github.com/rlmclmc2-boop/space_idle/commit/911ab0d0da795f06803243c41c2519f544e39c2b)当前前置|hightech_scientists/jewel_auto为兼容岗位键，未发现独立旧科学家/宝石玩法被重新实例化；不可仅凭键名删。|
|强化与宝石边界|[src/systems/enhancement.gd:85](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/enhancement.gd#L85)；[src/systems/enhancement.gd:145](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/enhancement.gd#L145)；[src/ui/enhancement_panel.gd:18](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/ui/enhancement_panel.gd#L18)|六效果顺位/三节点路径、强化等级与额外级；×10可买可负担部分；repeat第二节点B保选择不启第二代。不存在独立宝石装备Owner。|02§5、03成长/M5；所有数量控件统一规则（E1/E2）|[526c6e56](https://github.com/rlmclmc2-boop/space_idle/commit/526c6e565270e44b7d43cd9fa92de4a4383c4e87)draft；其后Owner移交未改两购买键|A6六源仍两直接执行键且无具名MAX出口；完整×1/×10/MAX需求已恢复，待原组实现。不能从保留晶体图集复活旧宝石系统。|
|星球探索/建造/领取|[src/systems/planet.gd:315](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/planet.gd#L315)；[src/systems/planet.gd:166](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/planet.gd#L166)|先推进已解锁施工，再探索并开放；ready释放船员、领取转built，built贡献，自动下一任务不吞尾段时间。|03§5、planet分册；D11环带整体/可选差异（E1/E2）|[63ddd481](https://github.com/rlmclmc2-boop/space_idle/commit/63ddd48104ba9cc47fd3666a1a8fcaba5fcd102d)Owner；662952f7当前R17运行|A7原地表强制布局文案过时已清；R17站/炉及整体未完，不把方向认可当六类资产通过。|
|星系蓝图/建造/交通/收益|[src/systems/galaxy.gd:233](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/galaxy.gd#L233)；[src/systems/galaxy.gd:99](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/galaxy.gd#L99)；[src/ui/galaxy_panel.gd:42](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/ui/galaxy_panel.gd#L42)|按真实蓝图节点/前置、先探索后施工、升级期间旧级效果、定期产出；galaxy_map保单viewport与实际模型，交通只表现。|03§6/M8、galaxy契约和当前Excel（E2）|[63ddd481](https://github.com/rlmclmc2-boop/space_idle/commit/63ddd48104ba9cc47fd3666a1a8fcaba5fcd102d)Owner；[29be6f54](https://github.com/rlmclmc2-boop/space_idle/commit/29be6f541a4ff06e84959338e43879f310015202)后台空账本贡献修复|后台读出口/贡献修复尚未全部集成；旧PNG说明“现用”失效，不代表应该回退GLB。旧资产README断链已清。|
|超空间挂机/手动/奖励/重铸|[src/systems/hyperspace.gd:793](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/hyperspace.gd#L793)；[src/systems/hyperspace.gd:961](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/hyperspace.gd#L961)；[src/systems/hyperspace.gd:984](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/hyperspace.gd#L984)|任务状态与固定奖励分离；待领阻止再领/覆盖；手动历史/挂机时长、重铸保留筛选按当前ID；仓容检查后接纳。|04、hyperspace分册、03重铸（E2）|[a0398be6](https://github.com/rlmclmc2-boop/space_idle/commit/a0398be6d42f137f8c94489e0a1cb360219e08e8)stage5；f924奖品恢复/整数补齐|未找到明确已撤任务链被恢复证据；新整数奖励/energy为A5，旧文本先引用a83已纠正。|
|无人机装备/改造/过滤/传说|[src/systems/hyperspace.gd:561](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/hyperspace.gd#L561)；[src/systems/hyperspace.gd:622](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/hyperspace.gd#L622)；[src/game_session.gd:984](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/game_session.gd#L984)|舰型容量1–5另受全局上限；传说/终极/Higgs约束，保护/筛选；随机改造预览和operation指纹幂等提交。|04、C1、14超空间（E2）|[a0398be6](https://github.com/rlmclmc2-boop/space_idle/commit/a0398be6d42f137f8c94489e0a1cb360219e08e8)核心；后续预览ab6/4c1只读接口|这些随机/操作指纹不是D9配置身份绑定，保留；未凭同名hash扩大删除。|
|经济、掉落、连续结算与大数|[src/systems/economy.gd:254](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/economy.gd#L254)；[src/systems/resource_amounts.gd:3](https://github.com/rlmclmc2-boop/space_idle/blob/c38f1c2b06478d1d8b6e98b8571240e693e296fc/space-battleship/src/systems/resource_amounts.gd#L3)；[addons/native_battle/src/amount_value.hpp:14](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/addons/native_battle/src/amount_value.hpp#L14)|一个Amount(m,e)表示所有量；掉落冻结出生/领取规则；main碎片两位小数、chrono按帧小数；后台累计整数费用/收益/已付服务进度。|06 Amount、01收入窗口；resources契约原用户所有实际资源整数（E1/E2）|[22241120](https://github.com/rlmclmc2-boop/space_idle/commit/22241120c54b631d5f3b321151230b151e74fb19)经济；[a83ad9c8](https://github.com/rlmclmc2-boop/space_idle/commit/a83ad9c83aebdfc18ac98f4f784aeb16eca16da4)整数；[f9244a30](https://github.com/rlmclmc2-boop/space_idle/commit/f9244a30ad1843128aaa0a620c4dc3e4866685b2)奖励/chrono退点|A5是完整闭包与窄接差异；通用Amount/速率/进度不是待删小数资源。静态核不等整体经济数值正确。|
|解锁、航程、驻守、重开|[src/systems/campaign.gd:255](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/campaign.gd#L255)；[src/systems/campaign.gd:276](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/campaign.gd#L276)|gate0开放、reached严格越过阈值/cleared集合；出击有盾或甲容量；死亡/驻守/旅行由Campaign持有。|01流程/03、unlock工作簿（E2）|[871d9433](https://github.com/rlmclmc2-boop/space_idle/commit/871d9433e3c79aa076201b6f832a4d6e55c5d5ad)所有者重组；[528e6636](https://github.com/rlmclmc2-boop/space_idle/commit/528e6636a21c1dd0bfc14b2669993886731e1f46)提交后通知|未发现旧“仅有装甲才活”残留在出击/受击主链；换型双零另问A3。|
|时间、暂停、离线与停止态|[src/game_session.gd:427](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/game_session.gd#L427)；[src/game_session.gd:474](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/game_session.gd#L474)；[src/systems/economy.gd:35](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/economy.gd#L35)；[src/systems/run_state.gd:7](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/run_state.gd#L7)|固定1/60、每帧64步预算保积压；墙钟与业务时分开，焦点/加速/暂停有独立边界；离线只入账、状态不可用挡命令。|01时间/离线、06恢复（E2）；整数服务进度（E1）|[46777916](https://github.com/rlmclmc2-boop/space_idle/commit/46777916fe18650eb8494e88e442c7bceab1f58c)chrono；[9490a580](https://github.com/rlmclmc2-boop/space_idle/commit/9490a580d2c5c84a0f75a131d26c9f4b5930717f)候选/离线；f924服务退点|未把离线恢复成全业务模拟；D9不删除候选完整性，A5chrono仍需各组精确集成。|
|保存/导入/设置/编解码|[foundation/host/save_files.gd:28](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/foundation/host/save_files.gd#L28)；[foundation/host/save_files.gd:70](https://github.com/rlmclmc2-boop/space_idle/blob/c38f1c2b06478d1d8b6e98b8571240e693e296fc/space-battleship/foundation/host/save_files.gd#L70)；[src/game_session.gd:315](https://github.com/rlmclmc2-boop/space_idle/blob/c38f1c2b06478d1d8b6e98b8571240e693e296fc/space-battleship/src/game_session.gd#L315)；[foundation/host/state_codec.gd:44](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/foundation/host/state_codec.gd#L44)|A/B代际+pointer/checksum/payloadHash，StateCodec保大整数；设置独立原子发布；当前后台不写/不要求/不比较configHash。|06、D9原用户删除保存配置绑定（E1）|[a65327c2](https://github.com/rlmclmc2-boop/space_idle/commit/a65327c25adb0d752fc5c393f77703497ab1882a)删除→[0822763b](https://github.com/rlmclmc2-boop/space_idle/commit/0822763bd9f2779dbda0faec1e3643b1bc888f0e)/[9490a580](https://github.com/rlmclmc2-boop/space_idle/commit/9490a580d2c5c84a0f75a131d26c9f4b5930717f)/[51d3bdf3](https://github.com/rlmclmc2-boop/space_idle/commit/51d3bdf3160b4a5e5c382cdff25cb05b694b5f3d)恢复→[c38f1c2b](https://github.com/rlmclmc2-boop/space_idle/commit/c38f1c2b06478d1d8b6e98b8571240e693e296fc)纠正|A1确认旧规范恢复已撤需求；后台定向符合，main/四组未合且旧测试断言未清。|
|配置读取/Excel编译发布|[src/game_session.gd:67](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/game_session.gd#L67)；[config_tools/compile.py:570](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/config_tools/compile.py#L570)；[foundation/host/hyperspace_config_contract.gd:5](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/foundation/host/hyperspace_config_contract.gd#L5)|直接JSON→Dictionary并检查参数/模块；compiler校工作簿/外键/范围，临时回读后os.replace；source/semantic/outputHash在报告中。|05/06直接读取与真实校验保留；09指向当前Excel（E1/E2）|[de0c3f9c](https://github.com/rlmclmc2-boop/space_idle/commit/de0c3f9cb96030d14096a6ea4c7449bea3f49a3f)删除旧包装；[b2224c06](https://github.com/rlmclmc2-boop/space_idle/commit/b2224c062a88ab13ff2b702bb75b145f13910ac1)重建compiler；c38改validator旧称谓|未发现运行ConfigBundle查询包装；compiler校验不是save gate，不因同名Hash全删。恢复依据仅commit+06，无每条原用户批准证据。|
|公共UI、设置与模块入口|[src/ui/bridge_theme.gd:79](https://github.com/rlmclmc2-boop/space_idle/blob/5df3d3dd59cf4fcd427f0fb9e719ad3a0a9e6969/space-battleship/src/ui/bridge_theme.gd#L79)；[src/main.gd:860](https://github.com/rlmclmc2-boop/space_idle/blob/5df3d3dd59cf4fcd427f0fb9e719ad3a0a9e6969/space-battleship/src/main.gd#L860)；[src/main.gd:67](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/main.gd#L67)|Main创建实际系统页；公共壳独立导航、余额行与资源身份，3c37接真实输入/选择状态；5df精确组合81744装备与519f新B01，组合待原整体审核。|13/M1–M10、14、最新R3方向与两键/透明图标/数字规范（E1/E2）|[059ac56b](https://github.com/rlmclmc2-boop/space_idle/commit/059ac56b16492a970d066e2c8d8456579866009f)材质；[3c3719bf](https://github.com/rlmclmc2-boop/space_idle/commit/3c3719bf59a7b00971b1d107ed591d34407710a3)真实选择/hover|A4/A5/A6/A8差异不得拼为同版完成；未重新视觉审或认领旧通过。|
|通知、教程、档案与保留脚本|[src/systems/tutorial.gd:23](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/tutorial.gd#L23)；[src/systems/notifications.gd:23](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/systems/notifications.gd#L23)；[src/ui/archive_panel.gd:20](https://github.com/rlmclmc2-boop/space_idle/blob/e3b38d7b6d8256f6031e1b086c7db7812b6a441f/space-battleship/src/ui/archive_panel.gd#L20)|教程跟真实成功事件，seen/read分别保存；档案消费原Owner记录；现役脚本含星球/星系/共享几何/retained表现，不另建旧Game/BattleGame。|01/05、13不常驻教学/M10（E2）|[2b77cccf](https://github.com/rlmclmc2-boop/space_idle/commit/2b77cccfbe330d4b62a811008742a258c4ba9603)引导；[57cd5b58](https://github.com/rlmclmc2-boop/space_idle/commit/57cd5b5890c22d9b592143f5853619244b782360)通知持久化|源码来源与现行规则可对上；旧教学文案/视觉仍属G8制作缺口，不把保留脚本名字当废弃代码。|

## 具体发现

### A1 已撤保存配置绑定被旧规范恢复；后台已纠正，尚未合main

原始用户2026-10-24T17:56:55Z（Sentinel_da0fdca3e4a08191af3fe519639ded13）：“ConfigBundle：加载数据包并提供查询。 这也没用”。助手18:26:22Z（Sentinel_84c92ffc4ca8819186ac3d9ab0ac6213）明确建议删除保存配置hash绑定、保留其余三项，用户18:28:03Z（Sentinel_2a63d9f07fd08191a498c80d09b3403b）：“确认”。本轮再明确“不用保留吧,显然这块就是做错了啊”“旧文档本来只当参考用,却完全按照旧文档重新做了啊”。

de0c3f9c删ConfigBundle查询包装；a65327c2删SaveFiles配置身份（不是一次删除所有校验）。0822763b恢复信封configHash必填/写入，9490a580恢复Session按磁盘文本比较，51d3bdf3冻结会话hash且构造后再比。082同次11沿旧03/05/06/07并写“候选会话验证与当前配置相同”，是可核恢复依据；没有后续原用户重新批准这层绑定的证据。玩家即使只修改可兼容配置文本也被拒档，维护者又被旧测试引导恢复错误。

c38f1c2b只删SaveFiles必填/写入与Session计算/传参/前后两处相等门槛；旧信封额外字段忽略、可选第五参数忽略。slot checksum、payloadHash、版本/代际、StateCodec、HyperspaceConfigContract、各域恢复/native准入保留。该生产diff静态符合用户裁定，没有看见把配置有效性或payload完整性一并删掉。作者27项真实Writer/Session检查是作者证据，本Astra不复测，也不扩大成M10/全游戏通过。main及四制作分支仍有绑定。

遗留：foundation/tests/_save_files_probe.gd:113、_stage6_page_probe.gd:268/282、_stage6_session_probe.gd:139仍断言configHash存在/匹配；后台c38明确未更新。它们是已失效断言，原后台应删/改对应断言或将纯历史探针隔离，不能继续进现行检查入口。保存第五兼容参数不构成门槛，不要求本次顺手扩删调用。生成报告的semantic/source/outputHash和改造operation指纹不是D9对象。

### A2 C4规范身份模型与实际核不一致；缺少裁定依据

02§7/05§5写父AttackId、命中复合HitId、独立EmitterId及触发位集；06写native next_ids含actor。实际Attack没有AttackId/parent；Flight有serial/source_uid/句柄，派生权限为bool及共享Instance；native persistent_state的attack水位为flight_serial、emitter为event_serial，actor由宿主Campaign等保存。take_results清feedback和退役/generation防重复仍存在，但不能说已经实现规范要求的持久身份链，也不能据此断言已造成重复伤害。这个差异源自e3e5e92b架构规范与继承执行核间的落差，后续旧审明确未豁免，未核到用户选定的最小身份表示。

需问用户的实际取舍：是否要求可查询/可保存的“直接父攻击ID＋独立攻击/发射身份”，用于追溯派生与检查点；还是接受当前来源/句柄/载体水位并把文档收敛到这套真实边界？不自动加完整祖先链，也不为清文档删除规范要求。玩家层面目前未证实差异导致伤害错误；维护层面审计/恢复ID口径不一致。

### A3 首防御槽换型双零：规范未决，代码已选择立即撤退

03§1允许合法换型，仍明确“换型本身导致双零是否立即判死”待定。main game_session.gd publish_equipment_refit:853–889在接纳后调用campaign.retreat_if_dead（884），campaign.gd:474–477检查defence_depleted并转死亡撤退；不走native受击finish_player_hit→try_rebuild。所有工作源保留同一调用。该宿主路径自f5b156e5/871d9433重组后延续，528e6636使提交后通知更明确；没有原用户裁定该换型边界的证据。

需问用户：战斗中首槽护盾/装甲换型使当前两者都为0时，是否立即死亡撤退，或先按受击链尝试重建，或另定换型准入/后续受击判死？这是玩家可触发的行为选择，不能由旧实现默认确定。本次不改代码、不把受击双零重建规则撤回。

### A4 装备免费立即切回：主线/支线不同，不能把旧锁写回规范

main _equip_admission仍因game_time<switch_ready_at拒绝，equip_slot设now+_cooldown。4dd4f123在装备分支删除门槛并置0；最新版7dfa继续保留。当前03/M2规则是免费点即换、立即切回，故main旧锁属于未集成，不是“最新决定保留冷却”。影响玩家操作，与同一核其他武器冷却无关。详见下方六源矩阵；不自动把整棵装备分支覆盖后台/反应堆等。

### A5 全局整数规则只有后台完整闭包，各UI窄接不能冒全局完成

main economy.collect_drop保留碎片roundToCent、部分倍率结果小数，Session chrono按帧小数服务；f924基于a83改为最终费用/持有/实际转移整数，连续收益/消费保留非钱包进度。equipment7dfa只取helper及装备/Economy验资必要边界；reactor519f取helper与反应堆报价；host5df在3c显示兼容上窄接B01报价/helper，仍无Session/Research/Hyperspace闭包；planet整组Owner试合已撤回。原用户要求实际值和展示都整数，源码/合同当前不是统一发行版。影响资源支付/奖励/读取与UI判断；不能只去.0或在UI ceil掩盖未接Owner。

### A6 强化两购买键仍违背现行统一交互；文稿也有过时指令

main及五工作源enhancement_panel.gd:18–19都是“购买1级”“最多购买10级”直接执行，与用户全局“一个按钮切换x1,x10,xmax，另一个按钮负责购买”不符。用户需求完整包括MAX，不能按现有Owner能力缩成×1/×10。

**本次整理错误及纠正：**928f的M5和本报告曾写“不自行新增MAX”，这是用代码现状缩减需求，现已纠正；不是用户后来减少/增加需求。M5与强化分册现统一写×1→×10→MAX循环键＋独立购买键。固定数量业务的现有合同不在本次重写，也不把既有“最多10可部分成交”当作替代MAX或覆盖其他合同的新决定。

具体实现缺口：六固定源强化UI均未接统一模式；六源Enhancement均没有具名MAX预览/执行方法。后台c38只有enhancement.gd:185 purchase_preview(count)、196 purchase(count)、351 _quote_purchase，Session:980 enhancement_purchase_preview(count)。原负责组须补真实MAX报价/数量、执行时重验和成交回执及前端接线，不由UI自行算一个大count假装完成。本线程只列缺口，不实现或自定算法；继承来源526c6e56，未核到消费完整新规则的提交。

### A7 旧设计稿/资产文字冒充现行入口，部分代码本已按新边界

旧反应堆asset interface要求1364×1200、BattleGame、双列主管；旧宝石README称jewel.image独立装备映射；星球旧地表强制分工与用户后续环带整体矛盾；资源/武器asset README指向已删除scripts/main.gd、ART_GUIDELINES、测试入口。05§5.1还把已退役native_execution_compiler/session的2^53与分支拒绝写成“现有”，02把battlefield/presented_battle_game/game写成main入口，并要求迁到不存在的battle_rules.xlsx；当前实际是Battle/native与game_rules/battle_geometry。此类实现正确但文稿陈旧的命令本轮一并纠正，不能据旧待补清单重写已存在算法。这些不能继续命令实现。当前源码实际有新Owner、B01/R17和native边界，不能为了“遵照文档”回滚。D10无需确认/还原、D11可选不同星球设计已有原用户文字，本轮清掉旧命令，保留有效数据/装配/许可证。当前AI设备映射D3等尚未定稿，未擅定具体美术。

### A8 制作入口反复叠“当前”，旧完成/依赖会覆盖新退回或新接入

取回装备7dfa入口顶部已有R3实机，后段仍写未实施、等公共材质和换装锁；B01519f最后段才说明同版最终视频，前段缺片与旧packed通过并存；公共3c37接口存在曾被误作真实选择节点已接入。旧状态不等于当前真实障碍。当前入口已按最新固定源重写，并把保存用资料物理移出；07加入每次接替核旧指令/旧状态/已否决方案/过期依赖、主体+版本+范围的唯一规则。bb4c记录原独审限定可交用户、根16:10已实际发三图；父线程随后补充用户16:24已退回7dfa：舰名牌侵台、控件贴边/行内关系、等级弱、顶部倍率须同步下槽，当前原组返修，不能再写待用户；整体5df已在3c公共源装入81744/519f且七生产文件blob与供应方相同，四张同版组合作者图不代替模块验收。父线程同时补充根协调者16:06对B01 519f整页检查未通过，单路升级裁字/核心材质/少态排版均需原组返修；5df组合所用两模块已有退回，不获默认通过。上述审核主体、固定被退版本及返修状态已更新入口；新WIP未读取，不冒称已修。当前制作/未提交WIP仍归原组，不将本整理快照强盖到更新现场。

## 未覆盖与不能作的推论

没有读取个人存档/各原组未提交WIP，没有现场运行和任何新实机/性能/故障测试，没有逐项验证每个Excel数值或所有传说/分支组合。源文件/关键命令链的覆盖是全系统来源盘点，非每条算法正确性的证明。未取得原始聊天的规则只写规范/提交依据，不能称用户曾批准；只有上列具体冲突转问，不泛化删除全部继承系统。

所有生产代码保持原字节。本轮仅同步当前规范、清入口与隔离保存资料；D9定向修码由原后台完成，其余发现不自动进入全游戏修复。原main/制作分支仍需消费文档清单；独立文档分支发布不等于已把其他分支清完。

## 六源差异矩阵

|源|同槽冷却门槛|配置身份拒配|强化两个直接购买键|资源完整闭包状态|
|---|---|---|---|---|
|main|仍有|仍有|仍有|未接|
|equipment|已去|仍有|仍有|窄接装备/验资/helper|
|reactor|仍有|仍有|仍有|窄接反应堆报价/helper|
|planet|仍有|仍有|仍有|完整试合撤回|
|host|已去|仍有|仍有|公共显示兼容＋B01报价/helper|
|backend|仍有|已去|仍有|f924完整候选；非全游戏验收|

## 本轮现行规范固定来源

当前规范固定提交`ee802997f84a3627f8f92bdd76fd93ad94676207`，以下只交叉定位规则，不导航历史：

- [01-runtime.md](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/game-design/01-runtime.md)
- [02-combat.md](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/game-design/02-combat.md)
- [03-progression.md](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/game-design/03-progression.md)
- [04-hyperspace.md](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/game-design/04-hyperspace.md)
- [05-architecture.md](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/game-design/05-architecture.md)
- [06-data.md](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/game-design/06-data.md)
- [07-verification.md](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/game-design/07-verification.md)
- [13-art-interaction.md](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/game-design/13-art-interaction.md)
- [14-ui-contracts.md](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/game-design/14-ui-contracts.md)
- [review/conflicts.md](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/game-design/review/conflicts.md)
- [contracts/resources.md](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/game-design/contracts/resources.md)
- [art/modules/enhancement.md](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/game-design/art/modules/enhancement.md)

[完整源码文件/blob差异清单](implementation-source-inventory.json)覆盖六固定源，每个真实系统在上表有对应行为/来源/关键提交；库存不代替逐行正确性证明。

## 本轮规范补正边界

审核状态与强化MAX错误已按父线程补充纠正；13§2.4新增制作前统一布局约束。该增补只规定制作方法和整页约束，未新增游戏代码结论；不继续已取消的项目历史追查，不运行复测。原矩阵仍严格绑定所列固定源码，不能代替原组新返修WIP。
