# 公共壳制作交接

制作规范见[13](../../../game-design/13-art-interaction.md)，反应堆三段控制区及工作语义见[M3](../../../game-design/art/modules/reactor.md)。

## 当前运行源与依赖

- 分支 `design/clear-zone-host`，运行源 `b28a0be19139298bd666df040be317fa1dcff2bf`，工作区 `/workspace/space_idle`。
- 用户已认可24db2a9c的共同分面方向，当前实施中。公共材质、顶轨/导航、输入/按钮及默认主题已在原绘制路径替换。
- 模块最小公共新源为 `src/ui/bridge_theme.gd` 与 `assets/ui/public_shell/faceted-controls.svg`；沿用现有字体/图标依赖。`operation_plate(padding,"dark")`配合dark文字角色；默认light及板面.state保留现有装备消费。其他壳体资源、宿主专属文件见下方消费清单。
- 装备保持e845操作结构；反应堆运行资产仍5ae32e28，新成套造型与控制区由原线程制作；星球新线程固定交接尚未收到。

## 当前证据与消费索引

独立归档 `archive/design-docs-before-cleanup-20261031@f0667cd900007d017a911cd3caeda4ba50d0c339:modules/public-ui/faceted-public-implementation-20261101/`：

- `README.md`、`consumption.json`：公共源、模块最小消费及宿主专属路径。
- `public-states/` 14张、`select-states/` 5张1440×900原屏与同尺寸JPEG；覆盖本轮改变的公共状态、资源弹层、装备板面/选择、舰船页及倍速实际展开确认。作者已看完整画面，导入/check-only及最终运行正常。

## 下一项与实际依赖

1. 将固定公共源交反应堆/星球原组消费，沿既有节点适配；按父级对当前公共实图的反馈继续打磨。
2. 接入各组成套资产固定源，在同版完整页面判断造型、材质、操作区和公共边界；保留装备操作结构和现行战场空间。
