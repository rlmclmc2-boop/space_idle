# 星球 R14 附着修订 × 当前共享宿主

原组固定来源 `597adbdbdbb163d41278d2cc762e390013c4239c`，[R14 原组入口](https://github.com/rlmclmc2-boop/space_idle/blob/597adbdbdbb163d41278d2cc762e390013c4239c/space-battleship/docs/verification/planet-single-side-godot/visual-r14-full-turn/README.md)。星球接替 Astra 已亲看右侧 37 帧和 10 张原 PNG，限定关闭近侧工坊被球面切割的问题；前版站坞分离和下边界的局部结论保持。原组 R14 整圈视频摄于这次修订前，不能作为修后整圈证据。

## 精确接入

相对已接入 R13，只更新 `scripts/planet_facility_scene.gd` 和 `assets/planets/facilities_v5/README.md`，两文件与原组固定 SHA 逐字节相同，[身份与哈希](evidence/source-identity.json)。前者让工坊/精炼厂插画在球缘沿相机方向抬升、缩窄、朝球内收束，并让近侧工坊插画平面渐进移至球面前深度；独立船坞固定服务位下移。模型、原图、球体贴图、根点与接触阴影均保持原组已有内容。本分支未取源旧 `main.gd`、`planet_panel.gd` 或 `planet_visual.gd`；已审公共壳、顶部退出、星球空带延展、输入焦点与收起恢复、装备和反应堆组合保持。

## 同版共享装配观察

Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:99` 的 1440×900 正式 `main.gd`/Session。[t0 原尺寸整屏](evidence/planet-r14-t0.png) · [t2 原尺寸整屏](evidence/planet-r14-t2.png) · [切回原尺寸整屏](evidence/planet-r14-return.png)。三图已亲看。[九项必要接入记录](evidence/observations.json)全部通过，覆盖主场景、15 路由、星球 808×900 与公共 chrome 退出、战场原 (855.875,0)/0.9375 投影、三设施插画创建、船坞枢轴及球面相位推进、切离返回同实例。[临时驱动](evidence/driver.gd.txt)与[实际运行日志](evidence/runtime.txt)归档。Godot 资源导入退出码 0；运行日志无脚本/资源错误，仅有 Xorg VSync 与无声卡 ALSA 回退提示。

驱动经公开模块恢复口临时给予关卡开放和始源星设施建成，并跳过夹具触发的引导；不证明自然解锁/建造。短时共享画面与数值相位不能代替原组近侧 37 帧的视觉判断，也不能外推修后整圈、六星球、泊位环可辨旋转、极端状态或 V0。当前共享组合待原布局 Astra 审，不合 main。
