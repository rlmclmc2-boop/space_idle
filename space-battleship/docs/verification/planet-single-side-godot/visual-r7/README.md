# 星球 R7：R6 视觉退回后的三设施窄修候选

R7 根审继续退回主造型；分层美术路线的首个工坊代表候选与原尺寸短周期见 [R8 工坊](../visual-r8-workshop/README.md)。本页图和视频仍是 R7 对照，不证明 R8 通过。

对照 [R5 认可造型](../visual-r5/README.md)和 [R6 退回的实机图](../visual-r6/README.md)，本次只修改精炼厂、工坊、船坞的 Blender 几何及 GLB。工坊拆开封闭屋壳，留宽工作湾、粗龙门和伸入湾内的机械爪；船坞增加单侧高主脊的正面象牙护甲，两座不等长悬臂保持开放；精炼厂明确双矿斗、中央炉舱与前伸入料带，炉顶有大块琥珀窗口。仍用暖象牙、深蓝结构、少量青灯及大块明暗。可编辑来源在 `art_sources/planet_facilities_v5/build.py` 与三份 `.blend`；运行资产在 `assets/planets/facilities_v5/{refinery,equipment,shipyard}.glb`。

实际画面由官方 Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:91`、Mesa llvmpipe 的 `1440×900` 正式主场景生成。始源星夹具经真实 GameSession 放开并建好四设施以展示候选，正常游戏时钟、地表转动和战斗继续推进；没有引擎限帧或强推时钟。

- [近侧进入](evidence/key_0000.png) · [近侧中段](evidence/key_0020.png) · [近侧离开](evidence/key_0039.png)：未经裁切的原始整屏 PNG。另有夹具进入后的 [已建设施单帧](evidence/05-planet1-claimed.png)。这些是真实运行图，仍请以原图判断 80–120px 轮廓、朝向和贴地观感。
- [连续工作视频](evidence/representative-working.mp4)：从 [40 张相邻原始 JPEG](evidence/frames/) 按 [实际采样间隔](evidence/sequence.txt)编码，视频约 `21.16s`。原始轨迹墙钟 `135.484s` 到 `156.256s`，跨度 `20.772s`。视频采样约 2fps，不代表游戏帧率或性能。
- [逐帧轨迹](evidence/operations.json) · [驱动](evidence/driver.gd.txt) · [运行日志](evidence/runtime.txt)：工坊 `GantrySlide` x 从 `-0.237746` 到 `0.040647`，`ToolArmSweep` y 转角从 `0.246747` 到 `-0.227189`；精炼厂双轮相向转和散热板开合、船坞吊机平移和泊位环转也在同一片段改变。九枢轴命名和原运行代码未变；这些数值只支持运动检查，视觉判断请看画面。

[Blender 导出日志](evidence/blender-build.txt)、[Godot 导入日志](evidence/godot-import.txt)及 [Godot 4.7.2 入口脚本检查](evidence/script-check.txt)已归档。`src/ui/planet_panel.gd` 另收窄共享宿主模式绘制，使原本 `y=65..90` 的本地浅色标题底板退出；独立面板仍绘制原 `0..90` 标题区。真实 H1 宿主挂载由整体组负责，本页不宣称 H1 整屏通过。

只复看本次受影响的始源星近侧代表机位与连续片段，没有重复全六星采样。R7 是交视觉根审的候选，不以 pivot 或几何 AABB 替代用户美术验收。证据文件哈希见 [SHA256SUMS](SHA256SUMS)。
