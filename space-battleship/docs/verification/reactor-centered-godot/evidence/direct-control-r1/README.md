# 反应炉直接分配与运行光候选 R1

基于 `17710fc787431c569b930cf952fe5c8dd094f18f` 的 R4 厚体装配，保留四设备、中央核心和短接。反应炉内部删除“手动/有效”两行，比例嵌入各滑杆；滑动通过 Reactor `allocation_plan_preview` 得到整组目标，再由 `apply_allocation_plan` 实际接纳。均分直接调用 Reactor `distribute`。取消确认/还原，不在界面计算 Amount。名称与增益仍显示在设备读面。批量后台仅定向取入 [Owner 候选 `aaba6683`](https://github.com/rlmclmc2-boop/space_idle/commit/aaba6683829ca11606003690224a1be9ea16080c) 中 `src/systems/reactor.gd`，文件 SHA-256 与其证据清单相同；Owner 实现仍待原双审。

同版 1440×900、1× 整屏：[四设备运行](four-running.png)、[超额拒绝](direct-rejected.png)、[武器调到 0% 后](direct-applied.png)、[×10 精确报价](bulk-ten.png)、[MAX 报价](bulk-max.png)。[808×835 内容区连续 12 帧](flow-1x.mp4)来自同一运行实例，6 fps 播放，逐帧捕获没有插帧。核心、四工作口及四条核心向外短接的材质相位随游戏时间变化；实际帧差分别非零，停止/隐藏时仍使用现有冻结与不更新路径。

Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:99`/llvmpipe。临时驱动通过公开 Campaign 恢复入口开放反应炉与凝聚，用公开 Economy 入账提供有限升级预算；这不是自然进度验证。[同版直接操作驱动](direct-driver.gd.txt)和[日志](direct-runtime.txt)：均分返回 `ok=true`，先尝试超额，Owner 返回 `ReactorPlanOverCapacity`、实际比例仍 25%，界面提示“分配超过可调容量”；随后武器滑杆置零，Owner 返回 `ok=true`，真实比例 0%、已配 75、剩余 25。[真实鼠标驱动](mouse-driver.gd.txt)和[日志](mouse-runtime.txt)从原尺寸 `x50,y315` 点击武器滑杆，Owner 同样接纳到 0%，比例覆盖层未阻挡输入。[拒绝驱动](reject-driver.gd.txt)和[日志](reject-runtime.txt)补核滑杆回到 25%，没有接纳超额值。[连续帧驱动](flow-driver.gd.txt)和[日志](flow-runtime.txt)：结束时 `paused=false`，工作光有持续更新。日志中的 ALSA 无声卡回退来自本机。

[批量界面驱动](bulk-ui-driver.gd.txt)和[日志](bulk-ui-runtime.txt)核同版 Owner 接口：无钱 MAX 为可购 0 级、按钮禁用且保留资源订阅 ID `2`；入账 1000 铀后同一 MAX 选择自动刷新为可购 11 级，再选 ×10 报 550 铀并一次购入 10 级，MAX 在当前余额下报可购 1 级并一次购入，等级 1→11→12。报价/数量来自 Owner，点击时 Owner 再求 MAX；界面无金额计算或逐级循环。[字体实际轴驱动](font-driver.gd.txt)和[日志](font-runtime.txt)读回反应炉本地 NotoSansSC 正文字重 400/按钮字重 600，使用与[已认可装备工作台](https://github.com/rlmclmc2-boop/space_idle/blob/90a19067af420f8b8b556efe9329da2591614f3e/space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-h1/equipment-623-integration/evidence/equipment-normal.png)相同的数值 OpenType `wght` 轴和深青按钮状态。

这里只核本轮读控、批量接线、命令及短片的真实运行。未覆盖自然开放、全游戏或硬件性能，Owner 源候选仍待原双审。
