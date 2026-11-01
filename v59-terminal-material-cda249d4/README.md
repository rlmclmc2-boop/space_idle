# 星球细环 v59：服务屋面和端舱材质分区

- 固定资产源码：`wip/planet-thread-resume-20261101@cda249d4dc8f63e0869a37be28422756980c3732`。唯一批准图：`archive/planet-resume-20261101@032b2f184da0932574b1e08fc091c294cc397875:approved-design-20261101-thin-orbit/planet-ring.png`，SHA256 `453078f9be47b45d1cffb809352470feb21f769fc18d5fdfeb640f4cf602e572`。
- 船坞压力罩、外服务门及部分服务舱顶采用暖色主甲；制造舱部分屋面与原冷色次甲交替。入口两侧一体压力壳的下半部以冷色承力材料过渡到上部暖甲，暗腔仍开放。此为大面材料区划，不改变设施体量、轨道半径或交互接口。
- `main-page.jpg` 为 1440×900 完整实机页；`stage-1..4.jpg` 为同源逐建阶段；`normal-speed-6s.mp4` 是 90 帧、15fps、6.000 秒正常速度动态；`approved-vs-game-subject.jpg` 为等球径批准图并置；`front-material-before-after.jpg` 在相同截图坐标对照 v58 与本版前两设施。
- Blender 4.3.2 构建/导出、Godot 4.7.2 导入/整页/逐建/动态完成。Godot 无脚本或 Shader 解析错误；运行环境无声卡出现 ALSA 报错。逐建使用内存视觉夹具，不代表自然解锁。
- 作者判断：船坞入口暖主甲与暗泊位、端舱下半部在整页更易区分，制造屋面与工作区读序保持。材质变化稳定，但绘画稿的大尺度环境反射、局部表面纹理与整体光影丰富度仍超出当前实机表现。本版不代表用户终验或 main 合入授权。
