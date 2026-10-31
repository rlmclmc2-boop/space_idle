# 站体承力墙装甲：局部制作候选

接续 `889120d` 四节点候选和[原版 0–12 秒证据](../natural-motion-889120d/README.md)。在站体 Blender 源模型的实际压力墙外侧加入分段维修装甲、下部受力肋和贯通口两端的宽幅装甲面及检修槽；环道中央通道仍开放。这是几何与材质一起做的站体局部修改，未触及其他设施归属或运动。旧连续片段属于改动前 `889120d`，不作为此候选的连续运动证据。

Godot 4.7.2、2048×768 的同版累计 built 对照：[站体](planet-station-armor-1.png)、[站＋炉](planet-station-armor-2.png)、[再加工坊](planet-station-armor-3.png)、[完整态](planet-station-armor-4.png)，均为相位 0。取图脚本和输出见 [首尾脚本](capture.gd)、[首尾日志](capture.log)、[中段脚本](capture-middle.gd)、[中段日志](capture-middle.log)，校验见 [SHA256SUMS](SHA256SUMS)。已逐张原尺寸复看：四阶段归属正常，贯通口未堵塞，双承力墙更可辨，前端暗面有暖色结构层次；下腹的深灰体量仍明显，整体四节点材质与细节密度仍需继续协调。四张固定相位图不能替代其他角度、自然施工过程或连续相位验收。

受影响侧向角补了站单建与完整态各两张：[25° 单建](planet-station-side25-1.png)、[25° 完整](planet-station-side25-4.png)、[70° 单建](planet-station-side-1.png)、[70° 完整](planet-station-side-4.png)，脚本与日志见 `capture-side25.*`、`capture-side70.*`。25° 可见承力墙沿环侧连续且口端装甲仍留出通道；70° 时站体大部被真实球体遮挡，仅顶冠可见，不可拿它判断入口形体。它们也是受影响角的局部图，不证明整圈。

新版候选的[0–6 秒模拟连续片段](local-motion/README.md)另存 25 张同版原图、脚本、日志与短片；它只核完整态局部相位，不是墙钟自然运行或自然建设态。
