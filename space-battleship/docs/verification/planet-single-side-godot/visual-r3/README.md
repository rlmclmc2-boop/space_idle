# 星球 R3 视觉修订：完整周期候选，待独审

## 最终船坞与完整周期实机候选

依独审对前三张图的反馈，只加强船坞的开放承重结构：两侧暗色剪力腹板、暖色纵梁、泊位接触垫与框架节点；球面、稀疏云和其余三座建筑保留。Blender 4.3.2 源与 GLB 同版重导出，之后用官方 Godot `4.7.2.stable.official.ed1daf0bf` 重新导入并运行。最终实机原图见 [默认](evidence/final-01-default-planet1.png)、[设施展开](evidence/final-02-facilities-planet1-ready.png)、[领取后船坞](evidence/final-05-planet1-claimed.png)。这些是最终几何的图，替代下文检查点的前三张作为视觉复审输入；不自行宣布品质通过。

最终同版运行用实际球面累计相位达到 **1.05009685 圈**停止，墙钟178.968秒、361个帧样本，驱动正常退出。轨迹覆盖地表设施背面转入转出、轨道站 `z=-3.07…+3.07` 的前后运动、侦察船从年龄0抵达到174.87并出现前后两种绘制层。递归遍历 GLB 内的 `MeshInstance3D`，排除接触阴影；四类建筑在首帧均有非空屏幕 AABB，整段保守 AABB 与上方操作控件相交记录为0。AABB 是辅助数值，实际遮挡和画面质量仍由原图与视频独审。

交付 [完整轨道视频](evidence/final-full-surface-orbit.mp4)（1440×900、2fps、361帧、按采样序编码）、[逐帧原始轨迹](evidence/final-motion-poses.jsonl)、[摘要](evidence/final-motion-summary.json)、[驱动](evidence/final-motion-driver.gd.txt)、[运行日志](evidence/final-motion-runtime.txt)、[操作记录](evidence/final-operations.json)及 `final-key_*.png` 11张未经加工的关键原始 PNG、[终点原始 JPEG](evidence/final-frame-end-1p05.jpg)。[SHA256清单](evidence/final-sha256.json)核对归档字节。其余361张原始JPEG在本执行环境 `/tmp/planet-r3-motion-final2/motion-frames/`，未进Git。视频按每帧0.5秒播放，**播放时长180.5秒不是引擎实际经过时间**；实际墙钟与相位逐行见轨迹。JPEG/PNG帧读取编码合计13.489秒墙钟；没有设置引擎帧帽、强推时钟，也不由采样推断用户CPU/GPU性能。当前仍待原独审R3视觉判断。

本次实际发生上下文压缩，依父线程要求保全原工作区供替换执行者继续。R2 `a91f65b4` 的真实下拉、设施父子层级、补人后施工增长、重铸可见落点、4.7.2环境分项已认可；其球面和建筑视觉被否定。R3 保留这些业务/交互代码，不重写契约。

已实际完成：两张新 imagegen 原始地图及提示词；四套重新整理的 Blender/GLB；稀疏云带/大地形、连续暖色建筑主体、细开放船坞、嵌入支脚与曲面接触阴影；轨道站三维深度修正；侦察船轨道引导与其位置共用同一椭圆参数。原组已批准的操作结构不变。导航/共享宿主后续交整体线程 `01a18207-893a-750e-9898-48786a8c40c7`，本阶段无新增宿主改动。

## 已有实机与准确范围

官方 Godot `4.7.2.stable.official.ed1daf0bf`、项目固定 API/native，同 R2 的 Linux llvmpipe/Xorg。1440×900 客户区、808×900模块，仅桌面宽屏。R3完整21张实际操作预览运行已结束，无脚本错误，固定夹具及真实OS鼠标驱动见 [驱动](evidence/preview-driver.gd.txt)、[操作](evidence/preview-operations.json)、[运行日志](evidence/preview-runtime.txt)。本检查点归档 [默认](evidence/01-default-planet1.png)、[展开待领](evidence/02-facilities-planet1-ready.png)、[领取后](evidence/05-planet1-claimed.png) 三张未加工原始 PNG。它们用于审查新球面/建筑，不宣称视觉通过。预览之后又统一侦察船引导椭圆与轨迹参数；该最后修改通过 [脚本检查](evidence/script-check.txt)，尚无对应最终运行图。

180.468秒墙钟长采样已实际完成327帧，但只积累0.533900圈表面相位，**没有覆盖完整自转周期**。PNG读取/写盘拖慢处理，在此机器不能把墙钟等同游戏/视觉时间。且包围盒函数只遍历直系子节点，漏掉 GLB 嵌套 MeshInstance3D，所得空相交列表不能作为净空通过。保存 [原始摘要](evidence/incomplete-motion-summary.json)、[原始轨迹](evidence/incomplete-motion-poses.jsonl)、[驱动](evidence/incomplete-motion-driver.gd.txt)、[日志](evidence/incomplete-motion-runtime.txt)，特意保留错误原文供复查，本说明覆盖其任何可能误导表述。未归档大量重复原帧，原机仍位于 `/tmp/planet-r3-motion/motion-frames/`。没有引擎限帧，也没有据采样报告CPU/GPU性能。

## 接续步骤与运行现场

1. 修采样：递归遍历 MeshInstance3D，排除接触阴影；以实际表面累计相位≥1.05圈停止，墙钟仅作安全上限。可把视频采样降至约2Hz并用高质量JPEG减少写盘开销，关键帧仍保存原始PNG；记录采样负担，不设置引擎帧帽或强推时钟。
2. 在最终源码重跑真实4.7.2，检查完整表面转入/转出、轨道站前后关系、侦察船抵达及稳定绕转和控制净空。实际图/视频决定可见结果，数值仅辅助。然后交原独审判断球面/建筑品质，不以本检查点当验收。
3. 累计征服详情已按固定所有者候选完成 [只读消费与同版验证](conquest-consumer-plan.md)；本条原检查点计划已执行，不私读/自算。

引擎 `/tmp/planet-godot472/Godot_v4.7.2-stable_linux.x86_64`；native `/tmp/planet-native-472/planet.gdextension`；构建/API `/tmp/planet-native-472/`；Xorg `DISPLAY=:91`。每次独立夹具使用单独 `XDG_DATA_HOME/XDG_CACHE_HOME/XDG_CONFIG_HOME`。驱动经 `--path /workspace/space_idle/space-battleship --script /tmp/planet-r3-motion-driver.gd` 启动；生成配置在项目 `generated/config.json`（不交Git）。系统默认 godot 是4.6.3，不可当最终引擎。OS鼠标辅助 `/tmp/planet-os-input.py`。当前仅独立临时保存目录，不含个人存档。

未发生拒绝/授权阻塞。尚未完成的是完整周期采样及最终视觉复审，非业务重写。未合 main。
