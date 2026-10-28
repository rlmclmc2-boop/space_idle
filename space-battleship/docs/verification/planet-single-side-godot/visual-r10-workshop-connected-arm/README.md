# R10 工坊滑座与机械臂连接返修候选

R9 的独立视觉审确认机械臂不再丢帧、工坊主形保持，但指出象牙滑座在工作循环中离开横梁：第 00 帧悬空，第 10 帧降到后墙前方，第 13 帧又升回。原因是原单张机械臂图把滑座和下方工具画在一起，运行代码移动了整张图。

本轮只修这处连接。运行时用 `AtlasTexture` 从**同一张未修改的原 RGBA 图**取上方滑座和下方工具；滑座随原 `GantrySlide` 只沿横梁水平移动，下方工具仍使用原 `ToolArmSweep` 工作行程。向下伸出时，深蓝色伸缩连接段补足两层之间的开口。两层维持 R9 的相机前置深度和透明优先级，球体深度测试仍开启。原工坊主体图、3D 锚点、地表随转和游戏时钟未改。

请独立审查 [20 秒原尺寸循环](evidence/workshop-cycle.mp4)，重点看滑座是否始终贴合静态横梁、下方工具是否保持连接并有可读的工作动作。对应 [20 张连续 1440×900 实机帧](evidence/frames/)的墙钟采样是 `135.611–155.612s`；视频 1fps 仅为证据采样，不代表引擎帧率。关键原帧：[00](evidence/key_00.png)、[10](evidence/key_10.png)、[19](evidence/key_19.png)；第 [13 帧](evidence/frames/frame_13.jpg)也保留。数值轨迹见 [operations.json](evidence/operations.json)，滑座水平位置约 `±0.30`，工具枢轴高度约 `1.54–2.24` 模型单位。视觉连接结论仍由审者从原图和视频裁定，不以枢轴数值替代。

主场景由官方 Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:91`、Mesa llvmpipe 运行；启动错误为空，原业务夹具加载成功。归档了[驱动](evidence/driver.gd.txt)、[运行日志](evidence/runtime.txt)、[资源导入日志](evidence/godot-import.txt)、[入口脚本检查](evidence/script-check.txt)和 [SHA256SUMS](SHA256SUMS)。本候选只覆盖代表工坊，不为其他建筑或更大范围验收背书。
