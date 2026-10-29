# 装备最终删减与批量等级修正 × 当前共享宿主

原组固定运行源码 `6233dc6ea25bac9a0dfcbc6a8d7b0673e8f24f06`，[原组最终证据入口](https://github.com/rlmclmc2-boop/space_idle/blob/9ed2090dcee8fb1d90d61846e92e6b1f94622332/space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/README.md)。用户明确不需要“记录和最近结果”；原组已删除入口、Popup、短反馈层和批量成交明细展示，保留当前等级、报价及必要失败/未知状态。原装备 Astra 已亲看最终两图并核调用链，对删减与批量等级刷新限定通过，未见新增 P1/P2；本页只记录共享组合接入。

## 文件边界

从原组取入最终 `equipment_panel.gd`，包含工作台排版、用户要求的删减，以及批量列表在 Owner facts 刷新后同步的 P2 修正。仅加回当前共享宿主的顶部静态机库背景延展和 `set_shared_host` 重绘，[固定源码 SHA 与组合 SHA](evidence/source-identity.json)、[准确顶缝差异](evidence/host-seam.patch)可复核。原组额外的未消费实验素材未取入；本分支公共壳、反应堆、星球、Session、Owner、native、配置及战场源码均未改。Owner 原始结果、`last_result` 和 `command_finished` 保留供系统调用，界面不再展示最近结果或记录。

## 同版必要接入

Godot `4.7.2.stable.official.ed1daf0bf`、本地 native、Xorg `:99` 的正式 `main.gd`/Session，1440×900 原窗口。[普通整屏](evidence/equipment-normal.png) · [一次真实批量后当前等级整屏](evidence/equipment-batch-levels.png) · [切回整屏](evidence/equipment-return.png)。三图已亲看。[11 项观察](evidence/observations.json)全部通过：启动、808×900 模块与顶缝、无记录 UI、原战场投影、批量独占/force 清理、真实一次批量成交后显示等级与 Owner facts 一致、切到反应堆并返回同一装备实例。[临时驱动](evidence/driver.gd.txt)与[运行日志](evidence/runtime.txt)归档。Godot 资源导入退出码 0；运行日志无脚本/资源错误，仅有 Xorg VSync 与无声卡 ALSA 回退提示。

驱动通过 Economy 公开恢复口临时给予足够预算，跳过夹具触发的引导，只核一笔真实批量命令后的共享装配；不证明自然收入、完整批量交易/扣费、三资源报价、极端金额、全部窗口/DPI 或 V0。旧 ce70 的回执 Popup 共享组合结论只属于旧实现，本版已按用户要求删除。当前组合待原布局 Astra 审，不合 main。
