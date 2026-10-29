# 反应炉 R5 工作腔实机视觉候选

用户退回此前 [R1 大空读面候选](../direct-control-r1/README.md)的整体实机视觉后，本候选在同一 808×835 反应堆内容区重做四个仪表和中央操作台。四件透明资产以较窄的深青金属与少量象牙受光代替厚米色框；工作腔成为主体，下面只留模块名称/效果倍率小读窗。中央操作台改为同材质外壳承托暖象牙信息面、深青按钮和独立反馈灯牌，字体/价格/数量层级参照已认可装备工作台。核心和舱室的已认可方向、四向短接、滑杆比例、直接分配、×1/×10/MAX 与 Owner 命令保持。新的局部材质和动效按实际有效 load 工作；核心向四路投出受控的邻近受光，不铺满舱室。

Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:99`/llvmpipe 下的同版 1440×900、1× 正式主场景：[四路运行](four-active.png)、[零负载](zero-load-max.png)、[超额拒绝](direct-rejected.png)、[直接接纳后](direct-applied.png)、[×10 报价](quote-ten.png)。[内容区连续 12 帧](flow-1x.mp4)以 6 fps 播放，无插帧。首末帧平均 RGB 差分：核心 10.82，武器腔 4.87，盾甲腔 15.29，炼铁腔 9.50，凝聚腔 15.02，短接 4.87；证据仅说明短片内可见变化，不代表硬件性能结论。

[同版截图驱动](capture-driver.gd.txt)/[日志](capture-runtime.txt)通过公开 Campaign 恢复入口开放反应堆与凝聚、公开 Economy 入账供费，并退出引导提示。均分、超额拒绝、直接分配仍由 Owner 接纳或拒绝；未自然推进关卡。[真实鼠标驱动](mouse-driver.gd.txt)/[日志](mouse-runtime.txt)核新工作腔覆盖层没有阻挡武器滑杆输入，Owner 实际接纳至 0%。[批量界面驱动](bulk-driver.gd.txt)/[日志](bulk-runtime.txt)核 MAX=0 保留钱包资源订阅 ID、入账后自动刷新、×10 一次成交及 MAX 一次成交。[连续帧驱动](flow-driver.gd.txt)/[日志](flow-runtime.txt)结尾为 `running=true, paused=false`，Stage 工作光 `active_frames=6, field_updates=54`。日志内 ALSA 无声卡回退属于本机环境。

此处提交可审实机候选，尚无用户对此版视觉的验收结论。整体宿主、导航、资源栏与右侧战场仍属共享整体组，当前图仅证明反应堆内部在该宿主中的呈现，不将共享壳视为本组改动。Owner 批量源仍沿已固定候选，不在这次视觉重做中改算法或价格。
