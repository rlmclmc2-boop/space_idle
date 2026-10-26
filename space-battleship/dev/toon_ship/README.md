# Toon 模块化战舰素材

本目录保留舰体、武器 GLB、源素材、挂点清单及独立表现脚本。旧 Toon 预览场景、preview.py、启动命令和验收脚本已删除，本目录没有可运行的预览或测试入口。当前游戏入口是 `src/main.tscn → src/main.gd`；本目录保留内容不代表已接入当前场景。

`manifest.json` 保存挂点和外形边界。坐标采用 Godot Y-up，前方为 -Z；`WeaponMountNN` 对应原槽位 NN−1。`player_hull.glb` 以及 `hulls/`、`weapons/` 保留原模型；`source/` 保留可编辑源素材。资源溯源沿用现有文件，不再提供已删除构建脚本的运行命令。

`ship_view.gd`、`hybrid_layout.gd` 和各武器 VFX 脚本保留模型装配与表现实现。它们不构成本轮玩法、存档或性能验收结果；后续接入与验收另行安排。
