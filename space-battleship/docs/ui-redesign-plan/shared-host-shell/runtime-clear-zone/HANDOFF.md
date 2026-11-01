# 公共壳制作交接

制作规范见[13](../../../game-design/13-art-interaction.md)，反应堆控制区内容口见[资产契约](../../../game-design/art/modules/reactor-asset-contract.md#宿主安装与三段控制区内容口)。

## 当前运行源与依赖

- 分支 `design/clear-zone-host`，运行源 `3c63dc9a`，工作区 `/workspace/space_idle`。
- 用户认可的共同分面方向正在实施。公共主题源 `9034af81`；最小消费文件为 `src/ui/bridge_theme.gd` 与 `assets/ui/public_shell/faceted-controls.svg`，沿用字体与图标依赖。默认light板面、dark板面及板面.state兼容现有调用。
- 装备保持main e845操作结构。反应堆运行资产仍5ae32e28，新成套主体由原组制作；三段控制区内容口已固定73caec37，供其按真实空间落位。
- 星球接入f32317a3的v8四模型及四脚本/材质闭包；公共六文件已由原组消费，宿主planet_panel保持当前安全区和深色操作台。受控星球1／探索240／征服／四设施已建。

## 当前证据

独立归档 `archive/design-docs-before-cleanup-20261031`：

- `f39f13ec:modules/public-ui/faceted-popup-panel-20261101/`：公共倍速与舰船选择切角弹层。父已亲看两张整屏确认轮廓遗漏闭合，保留这一局部结论。
- `d2282abf:modules/public-ui/planet-v8-shared-20261101/`：13张1440×900原屏及同尺寸JPEG、8件同源blob及公共保留件清单、驱动/导入/运行日志。作者已亲看总览、四设施详情、人员、探索/征服展开滚动、关闭/下拉及装备返回完整画面；公共边界与主体留白保持。建筑灰块感和设施辨识仍由原组制作。

## 星球接入状态

原组f32317a3已消费4e16d9fe公共材质与布局，本组合只取其`assets/planets/facilities_v8/*.glb`四模型、`scripts/planet_facility_scene.gd`、`planet_orbital_spine.gd`、`planet_visual.gd`、`planet_spine_opaque.gdshader`。公共main、导航、装备、主题和面板未覆盖，8件逐blob与固定源一致。对外继续提供当前公共六文件，原组模型/动画WIP独立。

## 下一项与实际依赖

1. v8同壳组合已形成，按本版完整画面继续公共适配；原星球组继续建筑材质和设施辨识，后续固定新运行源再精确消费，不等美术终验才接入。当前不是用户最终确认稿。
2. 反应堆最新原组交接19092a64仍在制作新分面主体和三段机台，尚未安装新运行纹理或原生控件布局。公共材质及内容口73caec37已可消费，下一组合依赖其成套运行闭包。
3. 新主体到位后继续完整组合检查造型、材质、控件落位与公共边界；保留装备操作结构和战场空间。当前操作台可按本版整页反馈继续修订，不以按钮共源替代整页判断。
