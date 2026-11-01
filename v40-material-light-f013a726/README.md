# 星球细环资产 v40：建筑材质与受光

- 资产源码：`wip/planet-thread-resume-20261101@f013a72609aaba77ac666874a3108eae89dc1395`。
- 批准稿：`archive/planet-resume-20261101@032b2f184da0932574b1e08fc091c294cc397875:approved-design-20261101-thin-orbit/planet-ring.png`，SHA256 `453078f9be47b45d1cffb809352470feb21f769fc18d5fdfeb640f4cf602e572`。
- 同版整页 `main-page.jpg`，完整建造 `stage-4.jpg`，逐建 `stage-1.jpg` 至 `stage-3.jpg`，90 帧/6 秒正常速度 `normal-speed-6s.mp4`，Blender 概念 `concept.jpg`，同球径图稿与游戏并置 `approved-vs-game-subject.jpg`。
- 指挥台加厚两层占用舱体及可见窗带；制造工位加暗色装配井、边唇与暖色点灯；船坞加深色停靠航道与落地灯。四设施按建造状态显隐的局部灯、较低环境光和主灯使内腔与装甲面明暗分离。批准细双轨、建筑位置、独立建造、轨道电车及现有 UI/业务接口保留。
- Blender 构建及四 GLB 导出完成；Godot 4.7.2 导入、整页、四阶段与动态捕获成功。日志没有脚本/解析错误。导出器提示 Draco 压缩库缺失但 GLB 正常导出；无声卡环境的 ALSA `ERR_CANT_OPEN` 导致音频回退为 dummy。逐建由内存视觉夹具设置，不代表自然解锁。
- 作者判断：在实际页面尺寸下两层指挥窗、前方暗色工作空间和暖色工位光可辨；绘画稿的建筑面板密度和星云气体细层仍较丰富。本版是视觉候选，未获用户终验或 main 合入授权。
