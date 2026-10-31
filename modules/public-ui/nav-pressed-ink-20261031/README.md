# 导航原生按住态字底修复（2026-10-31）

运行源 `design/clear-zone-host@0049ed4c0d911ed31117f1317fffee1a07eeff1f`，仅修改 `src/ui/zone_shell.gd` 对现有导航子 Label/TextureRect 的颜色状态；`BridgeTheme` 已让未选中 pressed 背景使用浅色 `nav-active.svg`，但原子节点只按 selected/disabled 上色，按住前仍浅字/浅青图。现使用原按钮的 `button_down`/`button_up` 信号复用现有深墨，禁用时清 held 标记；没有额外覆盖控件或模块内改动。

同一主入口 Godot 4.7.2、1440×900。`timeline.json` 含同一进程 36 个连续已绘制帧（69–104，无编号缺口）的事件/路由/显隐/焦点、文字与图标颜色。这里只归档受影响的 12 张原尺寸帧：装备→反应堆和反应堆→装备各含普通、hover、按住两帧、释放后选中/恢复。按下帧 6 的供能和 21 的装备，子字与图均为 `#0d2533` 落浅面；两次释放帧 8/23 路由正常切换。作者已在原屏看过这两张及 hover/释放前后，当前受控状态字图可辨。

这只验证原生鼠标受影响按住状态。旧缺陷的逐帧原图仍在 `archive/design-docs-before-cleanup-20261031@f00b609a` 的 `modules/public-ui/e845-r5d-continuous-20261031/`，不改其 blob。本版尚待既有独立整体审；36 帧采屏耗时不是目标 FPS/性能数据，也不外推键盘/触屏、模块全态或星球。
