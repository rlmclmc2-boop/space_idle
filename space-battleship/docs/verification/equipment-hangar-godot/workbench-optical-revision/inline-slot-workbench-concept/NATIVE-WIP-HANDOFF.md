# 矩形卡与原生接入 WIP：实际压缩交接（2026-10-30）

原工作区 `/workspace/space_idle`，分支 `art/equipment-materials-main-20261029`，基线 c60539e51097e41ec7801e20731fa810b94fda5f。本次已实际平台压缩，按父指令在自然项保全后停止，供替换者原地续作。没有等待用户授权：用户已要求矩形完整卡、属性单行、逐项不足费用红色、费用拥挤省名保图标数字并悬停0.5秒提示，且已批准修改后接入实机。未合main。

## 当前实改

- `build-rectangular-cards.py` 与63–83同名SVG/PNG已更新，另84点击不足反馈、85资源悬停示意，共23张。完整90px卡位于94px行内；费用不凸出，属性单行，保共同字体/环境/舰武/公共截图几何。`rectangular-card-manifest.json`是新源账本。只实际看过新静态63/82/83/84/85，余18张尚待完整查看；旧 `host-return-*`、`review-current-group.html`、`SHA256SUMS`保留旧版快照，不能当新卡校验/审结论。
- `src/ui/equipment_panel.gd` 已原生重写逐槽卡、即时免费本地下拉切换/切回、独立数量循环和购买、Owner报价/逐费红、0.5秒资源提示、短暂不足提示、部分行被动身份、焦点保护、unknown停机保护。共同字体400/500/600使用整数OpenType tag。原代码备份在/tmp同目录equipment-before-inline-native.gd。
- `assets/ui/equipment/hangar/inline-short.png`、`inline-tall.png`直接来自已认可短长环境源，无新生成。`src/systems/equipment.gd`去同槽10游戏秒换装锁并把旧字段归零，保留兼容字段；规则03/05/14同步，其它战斗规则/config未改。

## 真实已运行证据与边界

`wip-inline-native.gd`为本次真实main.tscn/Owner/native/config GUI驱动；不是独立复测线程。`wip-inline-native-operations.json`和`wip-inline-native-full.log`记录最后完整流程 failures=0：2/5/8、即时免费切回、真实扣费和本地同步、paidLv19/MAX444、单双不足红、0.5秒提示、部分行和滚动底部、局部选择与强制隐藏、真实Owner未知回执保护。后者显式注入publisher失败以获得Owner fault_unknown，不冒充自然原生故障。后期状态为受控真实Owner恢复，不声称自然解锁。完整流程末退出有4 ObjectDB/2资源警告。

最后随后补了MAX NoChange下真实材料准入区分，并调整驱动退出清理；`wip-inline-parse.log`解析通过，但这两项后没有再跑完整流程。替换者应核驱动是否已含MAX材料禁用断言，当前不声称该新增断言已执行。最后修正下拉图标/文本后完整流程已跑，但更新后的下拉截图尚未再目视确认。

当前截图`wip-inline-native-*.png`及视频`wip-inline-native-wip.mp4`都是旧main宿主WIP：没有正式公共导航，右战场仍旧几何，不能当同版正式宿主交付。已实际看过早2、早不足、中5、长MAX、tooltip、底部及修正前下拉。图像文件保留原输出，不美化。

## 精确剩余与依赖

1. 公共宿主整体主责：已向根提出最小闭包接入协调。整体b178ec391b941ac6888bff9b90f11809f4cf3b63相对本分支main约355行、BridgeTheme约209行，zone_shell274行且main依赖新reactor闭包，不能只复制三文件。需整体给最小可用Git闭包或在其正式宿主窄接本组候选。已证正确几何：模块0..808，导航808..855.875，有效战场855.875..1392.125等比.9375。没有私改main/战场。
2. 继续同一执行者原生修订：核最后MAX材料准入与退出清理、实际目视更新下拉及全部静态态，必要时修正；不能把当前failures=0外推到最后补丁。
3. 正式公共宿主接入后才固定同版完整2/5/8顶底/真实长MAX实机截图和操作视频、完成受影响交互审阅，提交根/原审。不自判通过，不重开独立测试线程。
4. 新旧静态账本/审阅页/校验清单尚未统一；应在新整组实际查看后更新。旧3946静态通过不覆盖本次矩形卡和原生实现。
5. 未见的更长Lv/名称/额外资源仍需同域真源，不编第三资源。无用户授权阻塞、权限拒绝或未知执行结果。

## 可复用真实环境

Godot `/tmp/space-idle-godot472/Godot_v4.7.2-stable_linux.x86_64`；native `/tmp/space-idle-native472/space_native.gdextension`及bin/libspace_native.so；项目generated/config.json保持原件。DISPLAY=:99现存X服务器（无Xvfb命令），ffmpeg可用。environment.md未找到，已告根，不杜撰。

运行隔离参数：SPACE_IDLE_SETTINGS_PATH=/tmp/space-idle-workbench-rebuild/inline-settings.json；SPACE_IDLE_NATIVE_EXTENSION同上；XDG_DATA_HOME=/tmp/space-idle-runtime472/data，XDG_CONFIG_HOME=/tmp/space-idle-runtime472/config，XDG_CACHE_HOME=/tmp/space-idle-runtime472/cache。GUI参数--path space-battleship --rendering-method gl_compatibility --audio-driver Dummy --position 0,0 --resolution 1440x900 --borderless --script /tmp/space-idle-workbench-rebuild/inline-native.gd。隔离存档在inline-native-save，未改旧存档。

收尾时没有Godot/ffmpeg/导出后台进程。所有原untracked导入元数据保全，不reset/clean，不新工作区/子任务/Library。当前停止原因是实际平台压缩交接，不是等用户，不是任务完成。
