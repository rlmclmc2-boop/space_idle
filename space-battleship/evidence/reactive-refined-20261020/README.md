# Reactive 父确认细化稿战场导入

源图为父通过 e9e8da87b96ba8a191b0ba275a344f4733279ba4 交接的 `art_sources/enemy-fleet-20261019/reactive-refined-approved.png`，不使用旧三块装甲源图替代。仅替换 reactive 静态舰体，保留其他七舰及所有生产 scripts/data/config_excel/addons。归一化只清理 alpha 边缘、等比缩放及居中，不重画。

`ordinary-eight.png` 为实际 main.tscn 原始1372×883窗口截图，reactive 在第二排第一格；保存关闭、QA保持血量，实际交火后暂停并清理瞬时弹道和浮字以观察舰体。单格114.4×133.333、舰体fit上限90.4×79.333维持原值；reactive旋转后包围框86.653×79.333，未为外圈缩船。外圈、中心判定、编队实现与数值均未改，编队重设计继续暂停。

资产alpha/比例/组件/配置/几何检查通过；其余7舰逐字节未变；266项实际场景检查0失败，103次开火/109次命中，中心误差小于0.000004逻辑单位。本地Godot4.6.3 Linux/GDS。未合main，视觉协调性由父及用户审核。
