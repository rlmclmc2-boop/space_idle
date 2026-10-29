# 反应堆直接读控 R1 · 共享组合接入

共享运行基线 `90a19067af420f8b8b556efe9329da2591614f3e`；反应堆来源 `8ef154a3b6bbfb722d27e740ae61a53d450e49d1`，其原组入口为 [直接分配与运行光 R1](../../../../verification/reactor-centered-godot/evidence/direct-control-r1/README.md)（在源提交）。原反应堆 Astra 已限定核可字体/按钮、直接比例分配、×10/MAX 与预算刷新、单行光学位置和动态；本页只记录共享装配，不升级原组结论。

## 精确来源与边界

- `src/systems/reactor.gd` 与 `src/ui/reactor_stage.gd` 和来源 `8ef154a3` **文件级 SHA-256 相同**，分别为 `90ab8a194f34deb6fbabf5b19081702774e28032eff5273fac49952f70e3ce34`、`ee7e8e896acbf2c60116b0e68fab88b9fd040502d2f61c7998e58d07ce3c8a2e`。
- `src/ui/reactor_scene.gd` 移入来源直接读控、报价及视觉逻辑，并保留当前共享宿主 `set_shared_host` 上下文、焦点释放、收起接口；等级/未知状态继续更新宿主标题。
- `src/main.gd` 仅改反应堆构造的 `can_pay` 注入及 `purchase_preview(count)` / `purchase_max_preview` 报价回调。来源分支的旧 `main.gd` 没有被合入。共享顶带、退出、输入门控、装备、星球及战斗投影保持当前组合；公共界面概念 V2 尚未实装。

## 同版实机证据

Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:99` / llvmpipe、1440×900 正式 `main.gd`/Session：[四设备运行整屏](evidence/four-running.png) · [直接将武器分配到零后](evidence/direct-applied.png) · [×10 报价整屏](evidence/bulk-ten.png) · [MAX 报价整屏](evidence/bulk-max.png) · [同一实例短动态](evidence/flow-1x.mp4)。短片为 12 帧、6 fps 的原尺寸捕获后编码；帧哈希各异。图与短片使用同一接入源码。

[11 项必要接入观察](evidence/observations.json)通过：启动、临时公开 grant 后 Owner 刷新、共享路由/上下文、原战场投影、公开预算入账、一次均分、一次滑杆直接分配、×10/MAX Owner 报价及工作光持续更新。[临时驱动原文](evidence/driver.gd.txt)和[运行日志](evidence/runtime.txt)留存。日志没有脚本/资源错误；ALSA 无声卡回退与 Xorg VSync 提示来自本机。

临时 grant 和 1000 铀入账用于固定画面，不代表自然开放/收入。这里未扩测极端预算、完整矩阵、自然战斗或全游戏，也未评价新的公共界面概念；原组内部及 Owner 算法的独审边界仍按原入口。此组合交原布局审共享区域和切换视觉，**不合 main**。
