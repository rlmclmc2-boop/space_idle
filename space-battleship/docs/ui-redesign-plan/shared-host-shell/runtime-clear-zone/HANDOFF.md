# 公共壳制作交接

制作规范见[13](../../../game-design/13-art-interaction.md)，星球主体见[M7](../../../game-design/art/modules/planet.md)，反应堆控制区内容口见[资产契约](../../../game-design/art/modules/reactor-asset-contract.md#宿主安装与三段控制区内容口)。

## 当前运行现场

- 分支 `design/clear-zone-host`，运行保全基线 `079f2ec9`，工作区 `/workspace/space_idle`。
- 公共主题源 `9034af81`，共用 `src/ui/bridge_theme.gd`、`assets/ui/public_shell/faceted-controls.svg`及现有字体/图标依赖。公共宿主、导航、装备main e845操作结构和战场空间保持。
- panel保留e7591438的ready人员撤回、旧引用清理和命令反馈修复；当前底部操作台、主体安全区和公共材质不因星球主体返工撤回。
- 当前反应堆运行资产仍5ae32e28；三段控制区内容口73caec37可供原组消费。

## 星球最新裁定

用户已否决079f2ec9的星球结构效果，取消该版待用户确认及作者可交付状态。原组三附件的实际发送不构成认可；当前代码/资产仅保全现场，不作为新结构的完成依据。

原星球线程正按用户授权采用或组合参考，以《群星》建筑嵌入环结构及细环大枢纽重做，四设施成为环结构节点，替换宽底座上摆建筑的构成。新固定结构源尚待原组交接。

## 后续接入

1. 先看新固定版本的完整结构，确认环、枢纽、设施的宏观构成确实改变，再精确接入当前公共宿主；材质、颜色或边缘微调不能代替结构变化。
2. 保留公共UI、e7591438修复与原业务接口，不用模块旧宿主覆盖；新结构在总览及不同高度操作台下共同判断主体/操作关系。
3. 星球新结构及反应堆成套新运行源分别交接，独立未完项继续；不重开已完成验证，不合main。

## 有效公共记录

独立归档 `archive/design-docs-before-cleanup-20261031`：

- `f39f13ec:modules/public-ui/faceted-popup-panel-20261101/`：公共倍速/舰船选择切角弹层局部确认保持。
- `a42ad9e0:modules/public-ui/planet-ui-fix-shared-20261101/`：44494e8d UI修复精确消费与原组接口夹具记录，相关代码保持。
