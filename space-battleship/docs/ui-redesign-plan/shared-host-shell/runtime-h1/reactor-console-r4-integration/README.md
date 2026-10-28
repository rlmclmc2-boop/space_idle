# 反应堆厚体读控 R4 × 当前共享宿主

原组固定来源 `17710fc787431c569b930cf952fe5c8dd094f18f`：[厚体读控母入口](https://github.com/rlmclmc2-boop/space_idle/blob/17710fc787431c569b930cf952fe5c8dd094f18f/space-battleship/docs/verification/reactor-centered-godot/evidence/console-mount-r4/README.md)与[下两路首行净空最终窄修](https://github.com/rlmclmc2-boop/space_idle/blob/17710fc787431c569b930cf952fe5c8dd094f18f/space-battleship/docs/verification/reactor-centered-godot/evidence/console-mount-r4/edge-line-clear/README.md)。原反应堆 Astra 已亲看最终三图，认可下两路首行、底边与倒角净空；此前认可的厚体承载、核心、光路及按钮结论保持。此处只交共享组合的必要接入，不扩大原组视觉结论。

## 文件级装配

精确取入原组 `reactor_stage.gd` 的 R4 控件坐标与最终下两路读数净空、四件 `*-control-3d.png`、中央 `central-console-front.png`/SVG 及四张可编辑 ImageGen 来源图；这些文件逐字节同源，哈希见 [source-identity.json](evidence/source-identity.json)。`reactor_scene.gd` 保留原组读控、三行原生文字、主控坐标与命令绑定，仅加回现有宿主的上下文 caption、焦点离页和独占端口。源分支旧 `main.gd` 没有取入，未替换本分支公共壳、装备、星球、已审顶部退出与输入/收起修复。原组资产之外的历史 centered-v1 板材及未被本场景消费的早期 lip 素材不进入本组合。

外根仍 808×900，内容 SubViewport 为 (0,65)/808×835；现有战场投影仍从 (855.875,0) 以 0.9375 显示。反应堆业务、Session、钱包和 native 无源码改动。

## 同版正式场景证据

Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:99` 的 1440×900 正式 `main.gd`/Session。[三设备命令前](evidence/three-before-command.png) · [三设备运行](evidence/three-active.png) · [四设备运行](evidence/four-active.png) · [四设备收起](evidence/four-collapsed.png) · [四设备恢复](evidence/four-restored.png)。四设备运行、收起和恢复整屏已亲看。[16 项必要接入记录](evidence/observations.json)全部通过；[临时驱动](evidence/driver.gd.txt)及[实际运行日志](evidence/runtime.txt)留存。Godot 4.7.2 编辑器资源导入退出码 0，运行日志无脚本/资源错误；仅有 Xorg VSync 和无声卡 ALSA 回退提示。

临时驱动通过公开 Campaign 恢复口开放反应堆及凝聚，再通过原组刷新口更新；夹具触发的引导通知按现有路径退出。三/四设备各一次均分预览与确认只核宿主命令接线，不代表自然开放、收入或购级。没有注入预算或强推游戏时钟。短时画面和诊断不代表原组连续动作/极端金额、全部窗口/DPI、自然全链或 V0。当前组合待原布局 Astra 审共享接入，不合 main。
