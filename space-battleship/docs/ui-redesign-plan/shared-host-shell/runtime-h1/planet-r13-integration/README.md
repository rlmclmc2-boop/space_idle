# 星球 R13 三设施 × 现有共享宿主

原组固定来源 `f4e6280db55cf72de5ec4b7bd52e530735d969b8`，依次包含 [R11 工坊](https://github.com/rlmclmc2-boop/space_idle/blob/f4e6280db55cf72de5ec4b7bd52e530735d969b8/space-battleship/docs/verification/planet-single-side-godot/visual-r11-workshop-camera-plane/README.md)、[R12 精炼厂](https://github.com/rlmclmc2-boop/space_idle/blob/f4e6280db55cf72de5ec4b7bd52e530735d969b8/space-battleship/docs/verification/planet-single-side-godot/visual-r12-refinery-work-cycle/README.md)及 [R13 船坞](https://github.com/rlmclmc2-boop/space_idle/blob/f4e6280db55cf72de5ec4b7bd52e530735d969b8/space-battleship/docs/verification/planet-single-side-godot/visual-r13-shipyard-service-cycle/README.md)。R11 已获原星球独审限定通过；R12/R13 内部视觉仍由原审判断。此处只交共享装配，不据整屏记录批准组内造型或动作。

## 接入范围

从原组逐字节取入 `planet_facility_scene.gd`、facilities_v5 三栋 GLB、对应可编辑 Blender 来源及构建脚本、九张 illustrated 来源图和模型统计。运行时仍用原 `GantrySlide`/`ToolArmSweep`、`IntakeWheelLeft/Right`、`CraneSlide`/`DockCollarSpin` 枢轴。准确文件哈希及与源提交一致性见 [source-identity.json](evidence/source-identity.json)。

本次没有取原组 `main.gd`、`planet_panel.gd`、`planet_visual.gd`；它们在源分支仍是旧宿主。本分支既有公共壳、已审顶部退出与星球静态背景上沿延展保持，装备回执和反应炉 R4 保持原组合。星球业务、贴图、转动和战场几何未改。

## 同版必要观察

使用 Godot `4.7.2.stable.official.ed1daf0bf`、既有本地 native、Xorg `:99` 的 1440×900 原窗口。正式 `main.gd` 场景启动成功；通过原模块公开恢复口临时给予关卡开放与始源星四设施建成，再由顶部实际鼠标入口进入星球。临时跳过该夹具触发的引导通知，仅为到达装配画面；不证明自然解锁或建造。

[t0 整屏](evidence/planet-r13-t0.png) · [t2 整屏](evidence/planet-r13-t2.png) · [切回整屏](evidence/planet-r13-return.png) · [观察记录](evidence/observations.json) · [驱动](evidence/driver.gd.txt) · [运行日志](evidence/runtime.txt)。三张均为同一次正式场景运行的 1440×900 原图，已亲看前两张。九项观察全部通过：主场景、15 路由、临时夹具、星球 808×900/共享 chrome 退出、战场原投影、三设施图层创建、船坞枢轴与球面相位继续推进、切离与返回同实例。Godot 编辑器导入以退出码 0 完成，未见脚本/资源错误；运行日志有 Xorg VSync 与无声卡 ALSA 回退提示，无脚本/资源错误。

这些是本组合的短时接入证据，不覆盖三栋各自 20 秒循环、整轨净空、六星球、自然经营链或全窗口/DPI。R12/R13 内部视觉结论继续由原星球 Astra 审；原布局 Astra 仅审此共享组合。未合 main。
