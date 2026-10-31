# main 最终装备 + R5d 共享壳（2026-10-31）

组合运行源 `design/clear-zone-host@7bdf00627cc895636e37ab71802711e7e68ed408`。最终装备来自已合主线 `main@e845ca58afd39184c3d4c5743021480e393adf74`：相对旧505，`equipment_panel.gd` 仅有空槽选择器 +2px 光学修正；`economy.gd` 同步已合主线的整数钱包/报价/支付归一。`equipment.gd`、`resource_amounts.gd`、`resource_visuals.gd` 与 main 同 blob；公共 `main.gd`、主题、数字和 ZoneShell 保留本组后续源。R5d 来自 `implement/reactor-centered-godot@0c2abe55b8084ee0d73a229b615300ba64c7b19e`，仅取两运行文件。

Godot 4.7.2，当前原生主入口 1440×900，gl_compatibility。`equipment-final-empty-controlled` 是经 Owner 合法 Cruiser 换舰后的空槽及真实公共壳整屏，非自然进度；`reactor-four` 为同版四路；`reactor-one-controlled` 为隔离 Owner 的单路真零，非自然解锁；`equipment-return-after-reactor` 核返装备。导入/运行无脚本错误。本人只做受影响宿主观察，最终空槽本身的原组独审/main 证据见 `archive/design-docs-before-cleanup-20261031@1dabd9d6` 的 `modules/equipment/20261031-main-e845ca58/`，不冒本组合整体审或模块全链/性能。星球仍旧 ac5 返回对照、品质退回。
