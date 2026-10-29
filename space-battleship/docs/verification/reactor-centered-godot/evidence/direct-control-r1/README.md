# 反应炉直接分配与运行光候选 R1

基于 `17710fc787431c569b930cf952fe5c8dd094f18f` 的 R4 厚体装配，保留四设备、中央核心和短接。反应炉内部删除“手动/有效”两行，比例嵌入各滑杆；滑动通过 Reactor `allocation_plan_preview` 得到整组目标，再由 `apply_allocation_plan` 实际接纳。均分直接调用 Reactor `distribute`。取消确认/还原，不在界面计算 Amount。名称与增益仍显示在设备读面。

同版 1440×900、1× 整屏：[四设备运行](four-running.png)、[武器调到 0% 后](direct-applied.png)。[808×835 内容区连续 12 帧](flow-1x.mp4)来自同一运行实例，6 fps 播放，逐帧捕获没有插帧。核心、四工作口及四条核心向外短接的材质相位随游戏时间变化；实际帧差分别非零，停止/隐藏时仍使用现有冻结与不更新路径。

Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:99`/llvmpipe。临时驱动通过公开 Campaign 恢复入口开放反应炉与凝聚，用公开 Economy 入账提供有限升级预算；这不是自然进度验证。 [直接操作驱动](direct-driver.gd.txt)和[日志](direct-runtime.txt)：均分返回 `ok=true`，随后武器滑杆置零，Owner 返回 `ok=true`，真实比例 0%、已配 75、剩余 25。[拒绝驱动](reject-driver.gd.txt)和[日志](reject-runtime.txt)：试图把已四路均分的武器调到 100% 时，Owner 返回 `ReactorPlanOverCapacity`，实际比例与滑杆回到 25%，没有接纳超额值。[连续帧驱动](flow-driver.gd.txt)和[日志](flow-runtime.txt)：结束时 `paused=false`，工作光 `active_frames=5`、`field_updates=45`。日志中的 ALSA 无声卡回退来自本机。

这里只核本轮读控、命令及短片的真实运行。×10/MAX 待 Owner 公开精确报价和最大可购数量接口后接入；本候选目前只有真实单次购级按钮。未覆盖自然开放、全游戏或硬件性能。
