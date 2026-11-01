# 公共壳制作交接

制作规范见[13](../../../game-design/13-art-interaction.md)，反应堆控制区内容口见[资产契约](../../../game-design/art/modules/reactor-asset-contract.md#宿主安装与三段控制区内容口)。

## 当前运行源与依赖

- 分支 `design/clear-zone-host`，运行源 `859ae9c7`，工作区 `/workspace/space_idle`。
- 用户认可的共同分面方向正在实施。公共主题源 `9034af81`；最小消费文件为 `src/ui/bridge_theme.gd` 与 `assets/ui/public_shell/faceted-controls.svg`，沿用字体与图标依赖。默认light板面、dark板面及板面.state兼容现有调用。
- 装备保持main e845操作结构。反应堆运行资产仍5ae32e28，新成套主体由原组制作；三段控制区内容口已固定73caec37，供其按真实空间落位。
- 星球接入固定结构源ef1fd9ee的11件运行闭包；宿主planet_panel保留y65起点。受控星球1／探索240／征服／四设施已建。

## 当前证据

独立归档 `archive/design-docs-before-cleanup-20261031`：

- `f39f13ec:modules/public-ui/faceted-popup-panel-20261101/`：公共倍速与舰船选择切角弹层。父已亲看两张整屏确认轮廓遗漏闭合，保留这一局部结论。
- `340d82f0:modules/public-ui/planet-v7-structural-shared-20261101/`：星球固定结构WIP的同壳接入记录。

- `dc6557c2:modules/public-ui/planet-common-controls-20261101/`：六张1440×900原屏及同尺寸JPEG、源码blob、驱动与日志。作者亲看三类抽屉、持续选中页签、禁用键、真实点击下拉展开及装备返回；原控件已改公共材质，抽屉保留13px内距。

## 下一项与实际依赖

1. 星球按钮公共适配已完成：移除旧图集裁图缓存、私有按钮状态和圆角菜单主题，原节点消费BridgeTheme；不等待新建筑。结构仍为WIP；最新原组交接07835400正在按新概念重做建筑与环，待其固定运行源再精确取入。
2. 反应堆最新原组交接19092a64仍在制作新分面主体和三段机台，尚未安装新运行纹理或原生控件布局。公共材质及内容口73caec37已可消费，下一组合依赖其成套运行闭包。
3. 新主体到位后继续完整组合检查造型、材质、控件落位与公共边界；保留装备操作结构和战场空间。当前公共适配未发现其他可独立修正项，不追加无依据微调。
