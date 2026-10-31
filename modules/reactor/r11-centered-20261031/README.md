# B01 R11：`edf1b016` 同版作者证据

运行资产固定于 `implement/reactor-centered-godot@edf1b0160b920456cfa2763ccd56e536dc4412d6`。这次源码仅改变炉液 shader 的横向移动热锋、热度和运动亮斑；其余模型、端口、界面与 Owner 沿用该分支前版。证据来自本地 Godot 4.7.2 的 1440×900 桌面窗口，没有修改生产配置或 Owner。

八张 `reactor-r11-controlled-{1,2,3,4}-{zero,active}-1440x900.png` 覆盖受控模块数的零载与正载完整整屏。`reactor-r11-controlled-author.gd` 是仅供预览的隔离驱动，证据证明相应数量下的显隐、读控与工作响应，不证明自然解锁。`reactor-r11-edge-{mixed-zero,low-positive,reopened-low-positive}-1440x900.png` 覆盖盾路归零、1% 低正载和隐藏重开；`edge.log` 记载盾路实际负载 0.01，隐藏时相位维持 4.7667，重开后为 5.3。另存 `all-active` 边界起点。

`reactor-r11v-final-1x-250frames.mp4` 为四路正载正常 1× 的完整桌面录屏，FFprobe 读得 1440×900、30 fps、250 帧、实际 8.333333 秒。`reactor-r11v-final-phase-{2,3,4,5,9}.png` 与 `whole-{zero,active}` 为同轮整屏观察。采证脚本及日志随包保存；录屏不能代替目标硬件性能报告。

作者完整复看了视频 250 帧的十张顺序接触表，并看了八态、边界与原尺寸炉体相位图。热锋在炉液表面横向移动，亮度变化比前版清楚，落流可见；但原尺寸整页仍偏向常亮橙色熔体，料嘴到承接池再到右侧排液的连续方向不够清楚，**不记 V3 视觉通过**。盾外场与四机材质是否达到与舱室同一完整设计，仍待独立整页审查。自然解锁、最终公共组合和目标硬件性能未在此包验收。

`SHA256SUMS` 覆盖本目录除自身外全部文件。包独立存于 Git archive，不置入制作树或 Library。
