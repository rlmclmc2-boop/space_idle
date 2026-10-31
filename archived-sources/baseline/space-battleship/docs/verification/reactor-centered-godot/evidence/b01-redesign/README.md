# 反应堆 B01：当前制作入口

## 目标与唯一批准依据

以[用户批准B01修订图](https://github.com/rlmclmc2-boop/space_idle/blob/73ee39c08b03ff6a4845f7d317baf4cdedc92874/space-battleship/docs/verification/reactor-centered-godot/evidence/b01-redesign/approved-b01.png)为方向：上方核心、四种设备、短接供能与下方完整控制区一起制作。用户2026-10-30 12:02–12:04（UTC+8）要求按图同时改面板和上方主体，并拿图对照成品。四路控制集中同一控制区，四色条只表达已配/总量；等级、费用、数量循环、独立升级与均分保留。

用户看过三段旧1×片后已退回管光、实体接口、核心水波和控制区贴边；要求独立核心、四设备、独立接口与真双层管路。旧packed/Astra局部视觉通过均不再代表此新结构通过；不合main。

## 固定源与现场

| 项目 | 本次可核快照 |
|---|---|
| 分支/文档源 | `implement/reactor-centered-godot@73ee39c08b03ff6a4845f7d317baf4cdedc92874` |
| 新结构源码 | `4f107f6e`建立可组合舞台；`e02fe186`加资产装配防重复裁切；73ee仅澄清历史标签 |
| 新结构 | 独立舱壁、核心、四机体、四路shell/front透明实体层、弧长UV管腔光、独立转子/钳臂及控制台壳；旧整图+live-material不再实例化 |
| 原生控制修订 | `e2b58e6a`均分入内腔、费用对齐、执行拒绝才短提示；其旧背景图只证控件，不证新管路 |

## 当前一步与完成标准

**当前一步：**围绕新结构完成核心约束/产能、沿真实管腔定向输送、设备回应及端口遮挡的整模块修订。按已生效Owner负载驱动；零载无工作光，未开放部件隐藏，暂停/隐藏/重开沿既有生命周期。

完成标准：当前资产的1/2/3/4路零/工作态、受影响交互、完整整屏与正常1×连续片属于同一固定源码/资产版本，原审按批准图及实际整页判断连接、材质、控件和运动，不能只清旧问题清单。随后继续可独立的R3面层与资源契约精确接入；未闭合范围不写成完成。

## 证据覆盖与剩余依赖

- [八态日志](https://github.com/rlmclmc2-boop/space_idle/blob/73ee39c08b03ff6a4845f7d317baf4cdedc92874/space-battleship/docs/verification/reactor-centered-godot/evidence/b01-redesign/modular-controlled-runtime.txt)及[当前四路整屏](https://github.com/rlmclmc2-boop/space_idle/blob/73ee39c08b03ff6a4845f7d317baf4cdedc92874/space-battleship/docs/verification/reactor-centered-godot/evidence/b01-redesign/modular-controlled-4-active-1440x900.png)覆盖受控1/2/3/4路零/工作态，1/2路真鼠标拖动回读；不证明自然开放。
- [10秒新结构运动预览](https://github.com/rlmclmc2-boop/space_idle/blob/73ee39c08b03ff6a4845f7d317baf4cdedc92874/space-battleship/docs/verification/reactor-centered-godot/evidence/b01-redesign/modular-preview-10s-1440x900-25fps.mp4)录于最后资产再生成之前，仅证明当时运动；当前最终贴图连续片缺失。日志`wall_seconds=35`是硬编码文字，不能当实测时长。完整版本/hash见[历史新结构记录](HISTORY.md#用户返修二可组合-b01-舞台的当前实现与验证边界)。
- 新架构尚无可比性能配对，目标机约10fps损失未证明消除。旧31–32fps软件渲染短窗属于旧packed舞台，不能移植到新结构；性能报告按[07](../../../../game-design/07-verification.md#全项目性能优化报告的用户基线)追溯最近实际送达用户的指标。
- R3共同面层/完整状态依赖[整体入口](../../../../ui-redesign-plan/shared-host-shell/runtime-clear-zone/README.md)；整数Owner源为`f9244a30`，消费者尚需核范围，不混入旧公共壳代码或扩大只读复核结论。
- 用户明确取消确认/还原，分配操作直接沿原所有者提交，见[已关闭D10](../../../../game-design/review/conflicts.md#d10)。预览/接纳分离仍有效，不恢复旧确认控件或控制台。

[完整历史](HISTORY.md)保留265行过程及各版本图/片/性能。旧“末节/当前packed/待新图确认”不再是接替指令。
