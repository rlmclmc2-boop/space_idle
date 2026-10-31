# 已验收装备的最小正常main接入候选

用户已授权装备合入main。本候选按固定方案 `ba144b7983f35cabed04aee970b9a3c48a5bce56` 制作，先推非main交原Astra核范围，根放行前未推main。

原远端main：`e93c221239a10d377b2ca89dd395ebcfa99c9819`。候选源码：`d5b73e930b046fcc6997a6cf18fcc885d76284e0`。原装备固定源码 `6233dc6ea25bac9a0dfcbc6a8d7b0673e8f24f06`、[原证据9ed2090d](https://github.com/rlmclmc2-boop/space_idle/blob/9ed2090dcee8fb1d90d61846e92e6b1f94622332/space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/README.md)保留。共享 `90a19067af420f8b8b556efe9329da2591614f3e` 只作已审接入参考，未合其H1父链或顶部共享缝适配。

## 准确范围

运行/项目6文件、正式机库素材与来源5文件，逐文件blob/SHA256见[source-identity.json](source-identity.json)。

- equipment_panel.gd和systems/equipment.gd整文件逐字同6233；记录/最近结果/Toast/回执tooltip已删除，Owner原始结果、当前等级/费用/资源/冷却及批量未知/失败状态保留。
- game_session.gd只摘四个装备方法及publish_equipment_refit/_publish_research/publish_reactor/publish_world的比较依赖通知，共27新增行。未取超空间、科研预览、强化等源分支增量；Economy/native/config不变。
- main.gd以e93为底参照6233轻量装配：1440×900客户区，左808×900正式装备；原572×960逻辑战场在右632×900容器中均匀0.9375投影，输入同变换。旧舰桥仍原layer10/旧模块构造，删除旧七参装备重复实例。伤害模式遍历及原战场overlay跟随逻辑视口。
- main额外只做正常承载必需的显隐/输入：打开旧舰桥前调用prepare_host_hide，独占时拒绝；旧舰桥显示则隐藏装备，关闭恢复同一实例并释放隐藏焦点。Batch/OptionButton占用时禁舰桥入口、透明控件拦右侧鼠标；main Space与CampaignView G共用只读UI门控（批量/菜单、旧舰桥、引导/危险确认及可见焦点）。直接点击原暂停按钮仍按显式鼠标动作处理。
- Session替换保留原close/save、逐子节点queue_free、重建_show_session流程，只在旧装备释放前调用prepare_host_hide(true)收回其Popup/焦点。未改旧模块内部。CampaignView只取80e5463f的可选ui_gate注入5行差异。
- project.godot仅两尺寸字段。新增直接消费资产仅hangar-console.png及import、README、原生成prompt和sources；未消费的支架/终端实验图不合入。

[完整适配差异](adapter.patch)可直接审main/Session/CampaignView/尺寸hunks。没有shared_host.gd、ReactorScene/Planet新场景、公共C概念、Economy或其他模块内部改动；没有独立旁路启动入口。

## 同版实际运行与图

复用原environment.md所载Godot4.7.2、native库、Xorg :99和全部缓存，临时独立设置/存档。正式main.tscn/Session/native真实启动，解析exit0，运行exit0：`EQUIPMENT_MAIN_MINIMAL_COMPLETE failures=0`。26项定向观察见[operations.json](operations.json)，[原驱动](capture-driver.gd.txt)、[原日志](runtime.log.txt)、[解析日志](check.log.txt)。

4张1440×900真实根视口整屏已逐张实际view_image：

1. [正常装备入口](01-normal-equipment-entry.png)：808×900装备及原右战场，装备UI/Owner按认可版本。
2. [原舰桥打开](02-original-bridge-equipment-hidden.png)：装备隐藏、旧舰桥及原模块入口保留，无遮挡交互。
3. [一次真实批量后的当前等级/独占](03-batch-current-levels-exclusive.png)：原等级列表与Owner相同，舰桥入口禁用。
4. [关闭批量并返回装备](04-equipment-return.png)：同一装备实例/正常等级费用。

检查包含实际Input.parse_input_event鼠标由右屏坐标转换到(286,480)逻辑坐标，误差<1px；572×960逻辑尺寸及0.9375等比未变。常态真实G驻守切换与Space暂停/继续有效；Batch阻Space/G、桥入口和右侧鼠标，OptionButton实际打开后拒绝路由隐藏、force收回；原舰桥与文本焦点阻游戏快捷键，返回后无隐藏焦点；一笔真实GUI批量accepted且当前等级与Owner一致。临时预算通过Economy公开restore恢复，非自然收入验证。

首轮驱动在打开桥后留下open Button焦点，Space合法激活该UI按钮关桥，使后续G/设置查询实际落在已关闭桥上，产生2项驱动顺序失败。原始[日志](diagnostics/first-runtime.log.txt)、[操作](diagnostics/first-operations.json)、[驱动](diagnostics/first-driver.gd.txt)、[当时图](diagnostics/first-bridge.png)保全；只修驱动在测试桥门控前释放焦点，运行源码不变，重取同一4图。未因驱动失败添加运行补丁。

## 验证边界与待审

本次仅隔离接入所需解析/接口/显隐/焦点/快捷键/等比输入/一次批量，不重复原装备全保护、全舰装配、未知故障矩阵、完整Session存档替换、长期性能、Windows/DPI、真实三资源或自然收入验证。Session完整替换仅源代码核保原流程，未冒充实测；真实第三费用仍无生产来源，未造fixture。native及所有旧模块内部不变，不需重编native。原装备/旧证据不冒充本候选重跑。

原工作目录/workspace/space_idle，原装备分支implement/equipment-hangar-godot@9ed2090d完整保留；同目录集成分支integrate/equipment-main-20261029，不新worktree/clone，不reset/force、不删缓存。候选待原Astra与根放行，不自判通过、不先推main。未实际上下文压缩，无运行任务或权限阻塞。
