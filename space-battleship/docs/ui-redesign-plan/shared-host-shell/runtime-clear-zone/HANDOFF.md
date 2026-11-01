# 公共壳制作交接

制作规范见[13](../../../game-design/13-art-interaction.md)，反应堆控制区内容口见[资产契约](../../../game-design/art/modules/reactor-asset-contract.md#宿主安装与三段控制区内容口)。

## 当前运行源与依赖

- 分支 `design/clear-zone-host`，运行源 `e7591438`，工作区 `/workspace/space_idle`。
- 用户认可的共同分面方向正在实施。公共主题源 `9034af81`；最小消费文件为 `src/ui/bridge_theme.gd` 与 `assets/ui/public_shell/faceted-controls.svg`，沿用字体与图标依赖。默认light板面、dark板面及板面.state兼容现有调用。
- 装备保持main e845操作结构。反应堆运行资产仍5ae32e28，新成套主体由原组制作；三段控制区内容口已固定73caec37，供其按真实空间落位。
- 星球已同步85db1e02的v12四模型及环脊脚本；公共六文件已由原组消费，宿主planet_panel保持当前安全区和深色操作台。受控星球1／探索240／征服／四设施已建。

## 当前证据

独立归档 `archive/design-docs-before-cleanup-20261031`：

- `f39f13ec:modules/public-ui/faceted-popup-panel-20261101/`：公共倍速与舰船选择切角弹层。父已亲看两张整屏确认轮廓遗漏闭合，保留这一局部结论。
- `320ebd17:modules/public-ui/planet-v12-shared-20261101/`：13张1440×900原屏/JPEG、5件同源blob清单、运行记录及作者整页结论。另有同版6秒/180帧/30fps离线1×动态、7原尺寸关键帧、180帧总览；视频和小于768KiB分片的顺序/哈希见`video-parts.json`。画面源码为ee5377bf；父已看总览及同版动态5fps抽帧，共同风格仍在制作，本轮不交用户成品确认。

- `a42ad9e0:modules/public-ui/planet-ui-fix-shared-20261101/`：精确消费44494e8d的panel修复及原组FakePlanet/FakeCrew接口夹具复核，8组UI断言输出OK。当前不是新增视觉或真实Owner自然流程结论。

## 星球接入状态

原组85db1e02已消费4e16d9fe公共材质与布局。本次只更新四件`assets/planets/facilities_v8/*.glb`及`scripts/planet_orbital_spine.gd`，五件逐blob同源；其后panel已逐blob同步44494e8d，保留公共材质/底台/安全区，补ready人员撤回、旧引用清理和命令反馈；main、导航、装备和主题保留。动态来自当前共享宿主的固定业务快照、四设施已建/探索未派遣待机运动；引擎固定30fps离线生成，非实时性能结论。

## 作者整页判断（ee5377bf实图）

读序为公共身份/余额→行星与四设施→底部设施选择/效果，主体与操作区归属清楚。泊位停靠船、制造舱及指挥核形体已可区分，状态区和操作台间留白保持。13整屏与180帧总览已看，未见当前采证范围内越界或跳切。仍可见大块均质装甲、设备与舰船描边强度不同，具体制作要求已写入M7“与现有舰船统一的制作要求”，原星球组按外轮廓→主壳/暗侧/内腔→中尺度装甲分件落实，整体组继续按整页判断。

## 下一项与实际依赖

1. 当前不交用户作成品确认。星球原组从67d1b4ce消费 `docs/game-design/13-art-interaction.md` §2.1及 `docs/game-design/art/modules/planet.md`“与现有舰船统一的制作要求”和操作布局段；仅文档差异，不覆盖模型/源码WIP。新固定运行源继续精确消费，再看同版完整组合。
2. 当前反应堆组合资产仍5ae32e28；公共材质及三段内容口73caec37已可消费，待原组交新成套运行闭包后接入。
3. 新主体到位后继续完整组合检查造型、材质、控件落位与公共边界；保留装备操作结构和战场空间。当前操作台可按本版整页反馈继续修订，不以按钮共源替代整页判断。
