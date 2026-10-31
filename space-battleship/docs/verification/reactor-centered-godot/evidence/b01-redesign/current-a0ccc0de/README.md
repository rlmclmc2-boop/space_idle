# B01 当前资产版：作者整屏与连续动态

资产源码固定于 `implement/reactor-centered-godot@a0ccc0de`，证据截取时工作树仅新增本目录证据，未改运行资产。使用 Godot 4.7.2、既有本地 native 绑定、桌面 1440×900、正常 1×；均分正载由 Reactor Owner 接纳。八张 `reactor-r9-controlled-{1,2,3,4}-{zero,active}-1440x900.png` 是同一版完整整屏。

1/2/3/4 路属于**受控模块数预览**：`reactor-r9-controlled-author.gd` 仅在预览进程中收窄 `reactorModules` 参数，并通过包装发布函数为不显示的路补中性因子；每次从零分配开始，再由 Owner 均分，截图前核对 Owner 模块数、负载和控制行数。它们证明整套设备/管路/控制行的显隐和读序，不能证明自然解锁流程。没有把该参数改动写入游戏配置或生产代码。

`reactor-r9v-final-1x-250frames.mp4` 从同版四路正载主游戏窗口实时录制，1440×900、30 帧/秒、250 帧、8.3667 秒。录屏由 `reactor-r9v-final-author-preview.gd` 在游戏启动与正载均分后发出 marker，再由 `reactor-r9v-capture.py` 使用 X11Grab/FFmpeg 启动。[运行摘要](capture-summary.txt)记录正常 1× 连续推进约 10.28 游戏秒及 274 个 active frame；录屏本身会占用资源，不能当目标硬件性能报告。第 2/5/9 秒整屏帧另存为 PNG，方便直接比较炉液、盾场和晶柱增长。

这些是作者制作证据。整页视觉独立判断、自然解锁、混合零/正切换、极低正载、公共组合及目标硬件性能仍未验收；本目录不记录通过结论。
