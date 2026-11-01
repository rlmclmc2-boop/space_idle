# 公共壳制作交接

制作规范见[13](../../../game-design/13-art-interaction.md)，反应堆三段控制区及工作语义见[M3](../../../game-design/art/modules/reactor.md)。

## 当前运行源与依赖

- 分支 `design/clear-zone-host`，运行源 `9034af815abc0883ba47e4df21c15163a4515c30`，工作区 `/workspace/space_idle`。
- 用户已认可24db2a9c的共同分面方向，当前实施中。公共材质、顶轨/导航、输入/按钮及默认主题已在原绘制路径替换。
- 模块最小公共新源为 `src/ui/bridge_theme.gd` 与 `assets/ui/public_shell/faceted-controls.svg`；沿用现有字体/图标依赖。`operation_plate(padding,"dark")`配合dark文字角色；默认light及板面.state保留现有装备消费。其他壳体资源、宿主专属文件见下方消费清单。
- 装备保持e845操作结构；反应堆运行资产仍5ae32e28，新成套造型与控制区由原线程制作；星球新线程固定交接尚未收到。

## 当前证据与消费索引

独立归档 `archive/design-docs-before-cleanup-20261031@f39f13ecbc67d251a50001723a5fb5270af59e56:modules/public-ui/faceted-popup-panel-20261101/`：

- `README.md`、`consumption.json`：倍速及公共继承菜单改用同一切角板面，当前模块消费路径。
- 7张1440×900原屏及同尺寸JPEG，实际展示倍速展开/高亮/确认/关闭与舰船选择展开/关闭；作者已看完整画面。舰船菜单从公共默认主题读到板面，运行正常。

## 下一项与实际依赖

1. 反应堆/星球原组取当前BridgeTheme和同源图集，沿既有节点适配成套主体与控制区；装备已在共享组合接用公共材质，操作结构保持不动。
2. 接入各组成套资产固定源，在同版完整页面判断造型、材质、操作区和公共边界；保留装备操作结构和现行战场空间。
