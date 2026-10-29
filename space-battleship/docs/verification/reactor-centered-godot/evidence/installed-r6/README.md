# 反应堆 R6 嵌入工作口视觉候选

此版回应 R5 浮动高反光金铜框、工作口重复、底部工作台狭窄与信息同权重的退回意见。四个工作口直接嵌入舱壁，每个模块只在这一处呈现工作动画；模块名在口上沿，比例滑杆在下沿。中央核心、四向短接与相邻受光保持已认可方向。底部采用装备工作台参照的整宽暖象牙面：等级、容量、费用、数量选择、主升级、均分依次分层。成功显示青绿反馈，超额拒绝显示红色反馈；Owner 的命令、报价和错误码未改。

Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:99`/Mesa llvmpipe、正式主场景 1440×900、1×：[四路运行](four-active.png)、[零负载与 MAX 报价](zero-load-max.png)、[×10 报价](quote-ten.png)、[成功反馈](success-feedback.png)、[超额拒绝](direct-rejected.png)、[直接接纳后](direct-applied.png)。[12 帧连续片段](flow-1x.mp4)为 808×835 内容区加 1 像素编码填充，6 fps、无插帧；第 6 帧无 R5 中出现的解锁引导遮挡。首末帧平均 RGB 差分依次为核心 12.32、武器口 7.63、盾甲口 34.63、炼铁口 22.83、凝聚口 30.88、短接 5.41。该差分只证明片段内画面变化，不代表硬件性能。

[截图驱动](capture-driver.gd.txt)/[日志](capture-runtime.txt)通过公开 Campaign 恢复入口临时开放模块，并通过公开 Economy 入账供费；非自然关卡进度。均分成功、超额拒绝保留实际 25% 份额、随后直接接纳到 0% 均由 Owner 返回。[真实鼠标驱动](mouse-driver.gd.txt)/[日志](mouse-runtime.txt)确认嵌入工作口及标签没有挡住武器滑杆，点击后 Owner 实际接纳 3%。[连续帧驱动](flow-driver.gd.txt)/[日志](flow-runtime.txt)在截图前检查引导不可见，结尾 `running=true, paused=false`，工作光 `active_frames=9, field_updates=45`。ALSA 无声卡回退是本机环境。

此处仅交视觉候选，尚待整体视觉审查。共享整体宿主、导航、资源栏、右侧战场仍归整体组；本候选不合 main。
