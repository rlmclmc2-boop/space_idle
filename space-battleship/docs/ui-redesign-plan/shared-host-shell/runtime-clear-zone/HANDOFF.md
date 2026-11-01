# 公共壳制作交接

制作规范见[13](../../../game-design/13-art-interaction.md)，反应堆控制区内容口见[资产契约](../../../game-design/art/modules/reactor-asset-contract.md#宿主安装与三段控制区内容口)。

## 当前运行源与依赖

- 分支 `design/clear-zone-host`，运行源 `4e16d9fe`，工作区 `/workspace/space_idle`。
- 用户认可的共同分面方向正在实施。公共主题源 `9034af81`；最小消费文件为 `src/ui/bridge_theme.gd` 与 `assets/ui/public_shell/faceted-controls.svg`，沿用字体与图标依赖。默认light板面、dark板面及板面.state兼容现有调用。
- 装备保持main e845操作结构。反应堆运行资产仍5ae32e28，新成套主体由原组制作；三段控制区内容口已固定73caec37，供其按真实空间落位。
- 星球接入固定结构源ef1fd9ee的11件运行闭包；宿主planet_panel保留y65起点。受控星球1／探索240／征服／四设施已建。

## 当前证据

独立归档 `archive/design-docs-before-cleanup-20261031`：

- `f39f13ec:modules/public-ui/faceted-popup-panel-20261101/`：公共倍速与舰船选择切角弹层。父已亲看两张整屏确认轮廓遗漏闭合，保留这一局部结论。
- `b85a5461:modules/public-ui/planet-subject-clearance-20261101/`：九张1440×900原屏及同尺寸JPEG、源码与六文件消费清单、鼠标驱动/日志。作者亲看设施、人员、征服展开/滚动与关闭等整页，状态区、主体和操作台有分离留白。模型仍为结构WIP。

## 星球原组接入

从本分支4e16d9fe按文件差异消费：`src/ui/planet_panel.gd`、`src/ui/bridge_theme.gd`、`assets/ui/public_shell/faceted-controls.svg`、同目录`stepper-down.svg`、`stepper-pair.svg`、`stepper-pair-disabled.svg`（均位于space-battleship）。字体和radio图标沿用现有依赖；逐blob清单见上述归档`consumption.json`。此交付已包含9fd深色材质/操作台和本次安全区，不取宿主main、导航或模型目录，保留原组新建筑及并发WIP。

主体上缘取状态条/选择器实际下缘最大值+24，下缘为操作台实际上缘-24，整组共用适配；短反馈计入状态区。新建筑尺寸到位后按其可见轮廓校准，不把本次简模检查当成新建筑完成。

## 下一项与实际依赖

1. 星球公共适配已推进到深色底部操作台：保留三页签及业务接口，原节点共源；标题身份与操作分栏，长正文在260px区域滚动，主体使用模块完整宽度。父已认可底部台方向；本次补主体安全留白，完整候选交父级重新判断。结构仍为WIP；最新原组交接07835400正在按新概念重做建筑与环，待其固定运行源再精确取入。
2. 反应堆最新原组交接19092a64仍在制作新分面主体和三段机台，尚未安装新运行纹理或原生控件布局。公共材质及内容口73caec37已可消费，下一组合依赖其成套运行闭包。
3. 新主体到位后继续完整组合检查造型、材质、控件落位与公共边界；保留装备操作结构和战场空间。当前操作台可按本版整页反馈继续修订，不以按钮共源替代整页判断。
