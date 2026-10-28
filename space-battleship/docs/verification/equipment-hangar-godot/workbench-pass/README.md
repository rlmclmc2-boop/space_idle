# 用户退回后的装备台打磨候选

固定源码 **7a7d5d3e3a6446745200c0f69a83f16dcf496e6e**，原目录 `/workspace/space_idle`、分支 `implement/equipment-hangar-godot`。本批承接用户退回318f/9794视觉后的六项要求，替代90dd状态记录作为当前制作候选；旧限定复核属于历史，不代替本批审查。未合main，不自判视觉通过。唯一规范入口仍为game-design/README，要求已写入现有 [M2](../../../game-design/art/modules/equipment.md)，本目录仅记录实施/证据。

## 本轮实图

- [新布局与巡洋舰比较](candidate/03-cruiser-cannon-comparison.png)、[左台长MAX与完整费用](candidate/19-long-max-multi-resource.png)、[实际冷却与安装区留白](candidate/09-switch-cooldown.png)。
- [真实新局Frigate](candidate/01-starter.png)、[部分解锁Frigate](candidate/25-partial-unlock-frigate.png)、[全部装备解锁但仍只有Frigate启用槽](candidate/31-frigate-full-equipment-dormant-slots.png)。
- [Heavy新增合法空槽](candidate/26-heavy-new-empty-slots.png)、[GUI直接安装](candidate/27-heavy-direct-empty-install.png)、[Heavy五武器/三防御全装](candidate/28-heavy-all-equipped.png)、[第三防御卡独立选择](candidate/29-heavy-third-defence-selected.png)。
- [Destroyer左右成对挂点](candidate/30-destroyer-paired-mounts.png)、[批量实际部分成交](candidate/12-batch-partial-result.png)。21–24系列保留槽终端/竖候选/数量键的normal/hover/pressed/focus同版实图，真实初始未解锁disabled见01。

均为真实Godot 4.7.2根视口1440×900原像素，未裁切、缩放、拼接。原始 [操作记录](candidate/operations.json)、[四项原保护回归](regression/runtime.json)、驱动/日志与逐文件hash见 [manifest.json](manifest.json)。

## 落地内容与实际依据

顶部浅色标题贴片已完全移除，舰名字样直接落在原机库梁上；标题矩形(35,104,236,30)，首槽终端位于x294以后，不相交。没有把原贴片简单换成深色卡。左升级台使用沿原金属内缘的新设备面材，分对象/等级梁、主值浅凹区、资源账区及动作台沿；所有文字、金额和控制仍为真实Godot控件。新 [upgrade-console.svg](../../../../assets/ui/equipment/hangar/upgrade-console.svg)为手写几何/渐变源，无烘焙内容，来源/hash见 [sources.json](../../../../assets/ui/equipment/hangar/sources.json)。正式舰体、武器、槽机壳与支承PNG均未改。

右侧保留现装/候选及直接替换思路，安装按钮改到(524,812,244,36)，向内收并上移；按钮底848，连同原native材质约3px下阴影至851，相对本图金属内框地面约y868仍有可见留白，左右也各留出空间。比较/冷却区重新排布，未挤压费用。长MAX主值仍27px，右缘408、距金属分隔x478约70px；Label下缘718、费用标题起点737。两费用行完整显示1.145×10^39铁和2730简并物质，金额17px未缩；完整所有者主值1.55622014967727e43仍可悬停查看。空槽tooltip显示空槽，避免暴露Null；余额转可支付后清除旧不足资源tooltip。

**主动空槽只读核查：** equipment.gd:620–648接受非首防御槽空ID，且直接替换无需先卸空；705–725换大舰自动新建合法空槽；747–758空槽不生成native贡献；591–595的装甲计数经game_session.gd:835/952/956输入强化记忆。所以不能宣称主动卸空没有玩法效果或删除其底层接口。未发现换装、解锁、换舰流程以主动卸空为必要前置。本轮按用户要求仅移除本页常驻“卸下”动作；Equipment接口、panel_equipment空ID选项、03合法空槽/首防御/休眠规则均保持。新开启空槽可直接选合法候选并安装；空槽未选装备时显示“选择装备”，不会显示“已装备”。

**槽位与装备解锁分开验证：** 真实新局未改进度、钱包或配装，Frigate只有1武器/1防御，只有初始装备开放。部分状态经Campaign受控restore为最高到达2、仅cleared1，Equipment实际开放导弹，舰炮/护盾/长激光仍锁，启用终端仍为同样2张。全装备开放取cleared1–99/进度100受控状态，随后真实change_ship/native接纳；不是自然赚取进度或用户存档。全装备开放的小Frigate仍只启用2槽；从Heavy缩回后6个后部槽保留内容/等级且dormant，未绘制成空槽或锁装备。

**大小舰与挂点：** 原通用卡位把2/4炮舰首槽放在顶中，不贴左右正式挂点对；本版按现有manifest的2/4个挂点成左右对布局。Heavy原第3防御卡/标记与第2重叠，现有独立卡位及标记。实际覆盖Frigate、Destroyer、Cruiser、Heavy；每张启用卡互不相交，实际武器锚点逐项核正式manifest+当前显示变换，native武器存在性与实际装备/空槽一致。Heavy8卡逐一真实GUI点击并核当前comparison的equipment_id，新增武器4空槽经真实按钮直接装舰炮。防御无武器manifest几何，本页三枚防御标记只是独立可辨UI锚点，未伪称是native武器挂点。武器炮口、碰撞及正式尺度均不改。

## 真实操作与原四项保护

操作驱动 `EQUIPMENT_CAPTURE_COMPLETE failures=0 records=35`。35包含业务、状态和布局记录，不是35笔交易。原武器/防御+1/+10/MAX都用原Amount核实际spent与钱包、实际count与付费等级增量；候选浏览不安装、实际换装锁拒绝与10游戏秒到期、资源不足所有者拒绝、批量部分成交/遮挡/关闭重开保持均保持。报价、MAX、费用和成交全由原所有者提供，无UI业务算法/假响应。交互状态仍用初始化缓存材质，真实鼠标hover/press及实际Control焦点记录保持，未扩完整键盘导航验收。

四项同版回归 `REVIEW_RUNTIME_COMPLETE failures=0`：

- 活战斗game_time3.1167→4.70，95次经济移动通知，槽位/选项/比较/MAX读取全0；仍66次battle draw与3次正常统计更新，节点增删0。另一定时移动窗口98通知亦0读取；没有冻结业务或全量样式重建。
- 原舰桥免费武器80/防御20各恰1条comparison依赖通知，current/upgrade/candidate真实改变且等于所有者，没有额外点装备刺激刷新。仅回归既有接口，没有反应炉/共享宿主实施。
- 两侧原生已生成且已拥有金额的掉落，仅经验证受控保存置于逻辑x32/540后实际点击移除并核钱包；空白边带不拾取。632×900区域内原0.9375双轴等比投影/拾取变换保持。
- [未知回执](regression/batch-unknown.png)仍保持未确认；拒绝、未提交、已接纳缺明细均不从空purchases推断0成交/等级保持/确认余额。边界案例是实际Control呈现输入，未伪造native财务或致命故障；真实部分成交另有所有者回执。

本批正式两runner均在固定源码提交后、独立全新/tmp设置与存档目录启动，前置检查无recovery；原始source标签/hash逐项绑定7a7d5d3e。既有Godot/native/config环境复用 [environment.md](../environment.md)，无重搭环境。预览在本地preview保留，不冒充正式同版图；之前所有失败窗口及旧缓存未清理。

剩余边界：新材质/构图、标题与安装真实留白、Heavy第三防御布置仍由根审和原独审判定，不用断言替代视觉通过；未覆盖本批未运行的Battleship四炮布局、全姿态、全长值组合、完整键盘导航、长期性能或Windows/DPI。未修改main/业务/config及其他模块，未合main，无环境/审批阻塞。执行者 `/root/equipment_visual_replacement` 未实际上下文压缩，固定交付后不自行启动新批。
