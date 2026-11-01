# 公共壳制作交接

制作规范见[13](../../../game-design/13-art-interaction.md)，反应堆控制区内容口见[资产契约](../../../game-design/art/modules/reactor-asset-contract.md#宿主安装与三段控制区内容口)。

## 当前运行源与依赖

- 分支 `design/clear-zone-host`，运行源 `cb0d0206`，工作区 `/workspace/space_idle`。
- 用户认可的共同分面方向正在实施。公共主题源 `9034af81`；最小消费文件为 `src/ui/bridge_theme.gd` 与 `assets/ui/public_shell/faceted-controls.svg`，沿用字体与图标依赖。默认light板面、dark板面及板面.state兼容现有调用。
- 装备保持main e845操作结构。反应堆运行资产仍5ae32e28，新成套主体由原组制作；三段控制区内容口已固定73caec37，供其按真实空间落位。
- 星球接入固定结构源ef1fd9ee的11件运行闭包；宿主planet_panel保留y65起点。受控星球1／探索240／征服／四设施已建。

## 当前证据

独立归档 `archive/design-docs-before-cleanup-20261031`：

- `f39f13ec:modules/public-ui/faceted-popup-panel-20261101/`：公共倍速与舰船选择切角弹层。父已亲看两张整屏确认轮廓遗漏闭合，保留这一局部结论。
- `340d82f0:modules/public-ui/planet-v7-structural-shared-20261101/`：3张1440×900原屏及同尺寸JPEG、同源blob清单、运行驱动与日志。作者已看星球四设施、装备返回和星图返回整页；y65及隐藏焦点清理断言成立，导入与运行未见资源/脚本/着色器报错。

## 下一项与实际依赖

1. 星球原组以当前固定结构继续主体材质。当前本地按钮仍从 `planet_panel.gd::_theme/_paint_button/_material_style` 读取旧 `assets/ui/planet/control-materials.png`；按角色替换为公共 `BridgeTheme` 原绘制入口，保留页签选中、下拉箭头和原操作结构，不再叠层。当前浅色建筑与旧细描边控件尚未形成整套风格。
2. 反应堆原组消费公共材质与已固定三段内容口，交成套主体及控制区固定源；整体继续精确接入并看完整组合。当前旧设备不能作为新方向验收稿。
3. 后续完整画面共同检查造型、材质、控件落位与公共边界；保留装备操作结构和战场空间。
