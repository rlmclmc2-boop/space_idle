# 整数计数展示最小修正：真实档正常窗口验证

候选补丁 `44c4d0d4ae32c8360dd0643e14c7ff846f9ab1d8`，分支 `review/hyperspace-integer-count-labels-845`，基于原845。两个文件共三个展示表达式、四个字段增加int再转字符串：改造摘要挂设槽和改造版本，挂设管理容量与模块等级。没有改存档、请求构造、command_seq、revision值、事务指纹、配置、费用或文案表。

原版845真实图显示“挂设槽1.0个、改造版本2.0/5.0”，来源是JSON读入的合法整数计数被保留为浮点，UI直接str展示。本补丁只在展示参数边界转换；修改点为 `space-battleship/scripts/hyperspace_panel.gd:refresh_details()` 与 `hyperspace_commands.gd:show_modules()`。仍使用既有put比较更新同一个控件，没有节点重建或刷新范围扩张。

## 已有真实档画面

- 原真实双核心周期档的白色究极space:1:2、等级10、改造版本2：页面显示“词条0项 · 挂设槽1个 · 改造版本2”。
- 原生打开挂设管理：显示“挂设0 / 1（同架不可重复）”；五个真实未解锁模块显示等级0、经验0，没有0.0。
- 打开/关闭页面后仍复用原forge_details控件，整数文字保持。
- 复用此前实际已完成支付后导出的再究极档，等级20、改造版本5：显示挂设槽1个、改造版本5。
- 两个输入文件SHA不变；全部异空间状态包括核心、材料、原last_command指纹保持。此次没有调用forge付款，没有再次验证支付链或复跑28项星系/路线UI检查。

[真实原版本2](native/01-real-revision2-integer-summary-screen.png) · [挂设管理整数计数](native/02-real-integer-module-dialog-screen.png) · [真实支付后版本5](native/03-real-revision5-integer-summary-screen.png)

9项直接检查通过，正常图形进程退出码0。干净候选自建887文件，指纹 `afc0a60bf03e7bfa5eaa297b8bc901ad014a75a8ae3a83382b4b414a248b0a99`；Godot4.6.3导入仅改变16个.import，其余清单代码/数据哈希一致。正常Xorg :90/llvmpipe窗口，不以截图FPS推导RTX3090性能。沿用正式load_progress_data/resume恢复和内存时间重基准隔离离线收益，暂停后只做原生UI动作。

## 边界与保留

两个输入分别来自父真实845双核心周期档及本线程此前真实付费链导出档；不是合成存档，未改值。本次源码候选与原845区分，不热合父当前845运行，不合main。原正常UI28项与究极生命周期原始结果及失败观察器证据保留。

父星系尚在真实建造，后续只等其真实全满档核完成展示；本次没有造30×5全满档或启动长跑。整数展示修正已可供父审阅挑选，不影响父当前运行。
