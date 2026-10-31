# R4l 反应堆分件返修证据（原审待看）

- 运行源码：`implement/reactor-centered-godot@3b2c31e2e1b525d7c8ffc1fc4935dc5b2f31f284`；公共主场景原分支 `main.tscn`，共享 R3 材质固定来源 `design/clear-zone-host@6e0e86c80d7cc7ee4f8623fca929c2f4828b6215`。本包仅归档此版实机，不是用户视觉验收或目标硬件通过。
- 环境：Godot 4.7.2，Xorg `:99`，Mesa llvmpipe/OpenGL3，1440×900，游戏正常 1×；四路均分各25%，本包录屏为窗口采集 25fps H.264、250帧、10.000秒。受控 1/2/3 路只在隔离 Owner 参数副本内换可用模块，非 Excel 自然开放。临时 native gdextension 仅运行时，未进入生产提交。
- 源层：`reactor_stage.gd` 独立核心图/动态场/三维约束转子/夹臂、四个独立设备、四条物理壳和管腔流；native Panel/Slider/Button/报价不烘入舞台。此版撤掉像圆形按钮的独立 lens 样片；少态左右共用完整浅金属承托，升级键 89px 保 glyph 净空。

## 当前实机图与连续动态

[真实连续片](continuous-10s-1440x900-25fps.mp4)，SHA-256 `ba6ab727637941e88e893577fbb1bbb4967372e08bfc2975772ffdc335a973db`；[驱动](continuous-driver.gd.txt)、[Godot 日志](continuous-runtime.txt)、[ffmpeg 日志](continuous-ffmpeg.txt)。已实看0、2、4、6、8秒整页，以及0.2秒步长全片接触表；核心/夹臂/四设备/四管独立运动、UI/nav稳定，所看无引导遮核心。视觉原审及用户确认**未取得**，旧 `519` 录像不替代本片。驱动末尾 `wall_seconds=35` 是遗留硬编码文字，片长以 ffprobe 10.000秒为准。

|受控模块数|真零|工作态|鼠标提交|
|---|---|---|---|
|1 炼铁|[整屏](controlled-1-zero.png)|[整屏](controlled-1-active.png)|[整屏](controlled-1-manual.png)|
|2 武器+炼铁|[整屏](controlled-2-zero.png)|[整屏](controlled-2-active.png)|[整屏](controlled-2-manual.png)|
|3 武器+盾甲+炼铁|[整屏](controlled-3-zero.png)|[整屏](controlled-3-active.png)|—|
|4 全部|[整屏](controlled-4-zero.png)|[整屏](controlled-4-active.png)|—|

[受控驱动](controlled-driver.gd.txt)、[运行日志](controlled-runtime.txt)记载 10 个预期 ZERO/ACTIVE/MANUAL 事件和 Owner 接纳；无脚本错误。该图证当前源的状态呈现与两路原生拖拽，不证明自然 1/2 路开放、用户机性能、最终视觉通过。

## 当前架构下性能诊断

上次实际向用户报告的是旧 packed 源 `051cbd0d+6d0ee146` 软件同实例正序 `31.29→32.33`、`31.61→32.23 fps`；本版分件源、材质、UI 与场景已变，**不可跨版求差或声称消除用户约10fps损失**。

本版[生产缓存开关同实例驱动](performance-cache-driver.gd.txt)与[原日志](performance-cache-runtime.txt)，Godot 4.7.2/Xorg/Mesa/OpenGL3，1440×900、正常1×、四路各25%、不录屏，2.3秒预热后四窗各约6秒；战场自主推进，不是同一冻结战斗帧：

|正序|原层 fps / mean / p50 / p95 ms|同视口缓存 fps / mean / p50 / p95 ms|
|---|---|---|
|A1→B1|34.04 / 29.38 / 28.341 / 34.372|33.98 / 29.43 / 28.415 / 34.585|
|A2→B2|32.33 / 30.93 / 29.758 / 35.878|34.00 / 29.41 / 28.394 / 34.535|

缓存保持所有动态/刷新/Owner 控件，仅将不变底图、已启用管壳与console在可用集合变化时一次合成，再作为原舞台视口第一层绘制。第二稳态短窗 Canvas draw calls `27→22`（[诊断日志](performance-draw-info.txt)；首冷窗阶段不稳，不作FPS结论）。[A同相位整屏](performance-uncached-samephase.png)与[B同相位整屏](performance-cached-samephase.png)RGB差异0；[1路](cache-count-1-uncached.png)/[缓存](cache-count-1-cached.png)与[4路](cache-count-4-uncached.png)/[缓存](cache-count-4-cached.png)舞台纹理RGB各0（[切态驱动](cache-count-driver.gd.txt)）。窗口收益不稳定，不能把+1.67单窗写成产品保证；无目标机硬件 profile，用户性能验收仍未成立。先前外层双视口原型约+3fps但边缘差126620像素，已淘汰，**非产品**。
