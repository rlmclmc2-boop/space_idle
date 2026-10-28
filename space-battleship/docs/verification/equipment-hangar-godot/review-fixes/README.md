# 装备原独审四项修订

固定源码 **94040a18b6616af78fa52c07986331d2e943d4f3**，基线 `63a455419e7a481297392fbbb357523645903673`。同一执行者、原工作区与 `implement/equipment-hangar-godot` 分支，未合main。用户确认的机库、正式资产和操作结构保持。根线程已转交原独审的具名定向通过结论，范围见下；真实图已交用户，当前等待用户验收。

[最终同版装备图](operations/15-final-cruiser.png) · [真实批量部分成交](operations/12-batch-partial-result.png) · [未知回执显示](batch-unknown.png) · [真实运行期原始计数](runtime-active-after.json) · [操作回执](operations/operations.json) · [hash/来源](manifest.json)

## 具名审阅结论与冻结状态

根线程转交确认：证据提交 **12c3f87ae67be66f908a29d2462e0786b827968a** / 运行源码 **94040a18b6616af78fa52c07986331d2e943d4f3** 的以下四项阻塞已由原独审定向复核通过：

- 未知提交回执保持未知，不以空purchases推断零成交、等级保持或确认余额。
- 运行期经济移动通知按真实钱包依赖过滤，并保留真实余额变化的报价刷新。
- 无支付武器/防御供能分配的比较依赖失效与返回更新。
- 右侧统一等比投影，以及共用变换下的实际拾取和边缘定位。

相关原+1/+10/MAX、直接换装/冷却、批量部分成交及关闭重开保持回归结论保持。该结论只关闭上述具名阻塞及对应定向回归；长期性能、全组合、全部姿态、跨平台/Windows/DPI、其他页面与正式发版均未覆盖，不代表整体游戏通过。

根线程已将真实Godot图交用户，等待用户验收。运行源码、资产、配置和原始证据冻结在上述候选；当前仅更新审阅状态，不重跑已过验证、不合main或扩展制作。原未压缩执行上下文、工作区和实现分支保留，等待用户反馈。

## 修订范围

1. **未知提交保持未知。** `_refresh_batch`只在accepted且有已确认purchases时列成交及其余已知未成交槽位。fault_unknown不显示“等级保持”、成交后余额或空purchases=0成交；缺成交明细也不推断0成交。accepted、普通rejected、not_submitted及未知结果分别显示；已确认部分成交仍保留。`batch-unknown.png`与JSON的未知/拒绝/未提交/缺明细案例是**真实Godot Control的呈现边界输入检查**，明确没有伪造一次实际native致命故障或财务执行；正常部分成交另由真实所有者回执验证。
2. **经济通知按实际依赖过滤。** Economy原display_changed仍正常驱动掉落绘制；没有改经济/掉落规则。装备比较只依赖已接纳budget，使用其不可变身份/值过滤同钱包的移动通知。真实余额变化只刷新钱包和所有者comparison/报价，跳过slot_facts与候选选项；槽位/装配/选项/舰型原通知继续保留。
3. **补足免费供能等真实比较依赖。** Equipment自有comparison_changed只使装备比较失效。Session只比较已接纳charged_base的五项实际输入：世界装备额外等级、武器/防御科研、武器/防御供能；发生实际变化后由Equipment在deferred边界合并通知，发布事务及相应接纳先返回。不是Session全局刷新、revision或向UI暴露私有因子；未改反应炉UI/业务。暂停、无冷却、钱包不变时，经原舰桥反应炉“分配”按钮分配武器80及防御20，返回装备后current/upgrade/candidate都与所有者一致且确实变化，各1条定向通知/1次比较读取，未再点装备控件刺激刷新。[武器返回图](free-weapons-return.png)、[防御返回图](free-defence-return.png)。
4. **统一等比投影及拾取。** 右区域仍632×900，原逻辑572×960不变，统一scale=0.9375；实际投影536.25×900，位于(855.875,0)，左右各47.875只显示原根背景。视觉和拾取仍共用SubViewportContainer变换，未改碰撞、舰船尺寸、炮口或Battle代码。真实定时生成的已拥有掉落量，经已验证受控存档仅将位置放到逻辑x32/540，两次从对应根坐标点击都实际移除目标并准确入账；左空白边带误点未拾取。[左缘前](edge-left-before.png)/[后](edge-left-after.png)、[右缘前](edge-right-before.png)/[后](edge-right-after.png)。位置设置是明确的边缘覆盖准备，不冒充游戏自动在该边缘生成；生成、拥有金额和拾取均来自真实所有者。

## 不暂停业务的前后诊断

原始对照为 [runtime-active-before.json](runtime-active-before.json) 与 [runtime-active-after.json](runtime-active-after.json)，均`observers_attached=true`。真实main/Session/native，第5关正常推进、3艘存活敌舰及实际在途攻击存在。业务未暂停，渲染不限帧，画面预算/经济规则不变。每版分别记录真实时间窗和状态，不冒称两次启动随机种子、FPS或完整战斗状态相同。

实际活战斗窗口：基线105次经济通知、1.75游戏秒，slot_facts/comparison各28次；修后96次通知、1.60游戏秒，slot_facts/选项/comparison/MAX四类均0。修后仍有57次battle draw、3次正常统计更新，活跃攻击1→4，不是冻结模拟。详见自动生成的[计数摘要](runtime-summary.json)。基线无独立option/MAX计数字段：其每次full refresh固定调用一次候选选项及一次maximum=true的comparison，以实际refresh/comparison计数和源码调用关系标明，不能伪称旧采集器已有新字段。修后四类读取均有独立计数。

窗口内两版均无配置提交，无节点新增/删除，Battle/kernel/Presentation/Statistics与舰图资源对象保持，敌舰UID1/2/3、generation3保持存活。正常伤害统计、发射、到期和飞行池增长继续；不要求活战斗前后所有池计数或敌舰HP完全相等，也不把正常battle draw当重建。启动及受控进度开放准备阶段有其他既有面板的节点变化，原计数完整保留；“0节点变化”只指明确的观察窗口，未扩称全程序。

真正余额依赖已用两笔未暂停业务的实际拾取验证：每笔1次钱包/比较/MAX更新、0次槽位/选项读取，并与所有者最新报价逐项相等。无支付供能的通知/读取计数和三段主值变化另列于原JSON，既过滤冗余也没有丢失真实依赖。

初步 `runtime-before.json`/`runtime-after.json` 是航行期移动反例，不能代替含敌舰和在途攻击的窗口；其未接齐的observed字段不用于节点/统计结论。`runtime-active-after-defence-nochange.json`保留发现的验证缺口：防御0原本就是0，matches_owner不能证明发生变化。最终改用合法剩余能源20，并断言三段主值确实改变及定向通知恰1次，没有改写旧记录。

## 同版原操作与来源

`operations/`15张均为94040的真实Godot根视口原像素1440×900，没有裁切/缩放/拼图。原+1跨材料、+10/MAX、直接换装、实际10游戏秒冷却、批量部分成交及关闭重开保持回归0失败；原Amount核对实际spent/钱包及实际count/等级，根挂载断言也通过。源码由运行时SHA256绑定固定Git对象。未知边界检查与正常真实财务执行分别记录，不用呈现输入冒充真实致命故障。

基线复现也在同一原工作区：4个运行源码文件临时写为63a的Git对象，单进程取证后finally逐字恢复94040，没有新工作区/worktree；命令与驱动文本保留。运行环境、官方Godot 4.7.2/API/native来源及本地Linux链接修复继续沿用[环境记录](../environment.md)，本批未改原生库或配置参数。

本批没有扩大到其他页面、长期性能、全组合、Windows/DPI或战场美术验收；这些不因本轮定向结果关闭。执行者 `/root/equipment_image_revision_replacement`，尚未实际上下文压缩，无环境/审批阻塞。

同机环境复用：最新本地导入元数据包 `/tmp/space-idle-runtime472/import-metadata-94040a18.tar.gz` 的hash与恢复命令见[local-environment.json](local-environment.json)。元数据归档后已从Git工作树清理，正式素材及配置未改变；仍走标准导入/启动路线。
