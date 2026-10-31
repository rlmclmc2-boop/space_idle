# 反应堆 R8 四工作口玻璃遮罩候选

承接 [R7](../glass-mask-r7/README.md)。R7 的下两个斜玻璃工作口已修正，上左三路导流的左端与上右盾场网格的右端仍越过玻璃压住象牙壳。本次仅扩充 `installed_work.gdshader` 和 `installed_pulse.gdshader` 共用的 UV 玻璃遮罩：上左在左唇和倒角处渐隐，上右在右唇及上斜的玻璃下沿渐隐；下两个镜像斜边继续保留。遮罩作用于工作材质与动态光的最终 alpha，玻璃内大部分显示面积与运行亮度仍保留。`power=0` 工作层透明，露出底图玻璃和壳体。核心、工作身份、倍率、工作台、反馈和业务没有变动。

Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:99`/Mesa llvmpipe、正式主场景 1440×900、1×：[四口运行](four-active.png)、[零负载与 MAX 报价](zero-load-max.png)。[无遮挡 12 帧内容区片段](flow-1x.mp4)为 808×835 内容区加 1 像素编码填充，6 fps、无插帧。[截图驱动](capture-driver.gd.txt)/[日志](capture-runtime.txt)及[连续帧驱动](flow-driver.gd.txt)/[日志](flow-runtime.txt)对应同版画面。驱动通过公开 Campaign 恢复入口临时开放模块，并通过公开 Economy 入账供费，非自然关卡进度。连续帧结束 `running=true, paused=false`；ALSA 无声卡回退是本机环境。

本次只复核受遮罩影响的 active、zero 与动态片段，R6/R7 的 Owner 直接分配和鼠标证据仍在原目录。这是待原审视觉候选，未合 main；共享整体宿主与右侧战场归整体组。
