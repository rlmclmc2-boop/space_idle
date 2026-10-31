# R17 星球整体结构：当前制作入口

本页只保留当前依据、动作和证据。旧局部图与说明已从制作树迁出；不据旧候选宣称当前版本通过。

## 批准依据与完成判据

按用户已认可的[实体环带完整态 8136cef8](../../../game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png)制作装甲承力脊与四设施共同形体；[闭环分步 1eda07fd](../../../game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-stages-closed.png)约束独立建造累积。环须贯入各设施承力节点；球与环独转、探索船另轨、真实球后遮挡、前弧暗缝和四段独立 owned 归属保持。原尺寸完整态及受影响侧角应读出站／炉低位连续通道、炉双料斗和接收口、工坊工作口、船坞停靠艇及站顶运动件。不得出现飞碟、暗盘、浅方壳、外挂三件、假垫层或仅改色／环宽替代资产制作。**整体尚未通过，继续制作。**

## 当前具体动作

当前源码 `082e2e2e` 在四段 owned 承力截面基础上，让炉原压力舱一体拱起、冠部高于双料斗内缘、同网格切热井；两只原料斗侧墙外张、蓝色下壳和浅色料块分层，接收口保留，炉节点中心已移入本段承力弧。R48 将两只料斗内各三块方料改为两块不规则矿石；原尺寸默认／25°仅局部可辨，70°受口沿遮挡，不能把矿石当成整体形体改进。船坞原停靠艇沿发射轨前移微抬，船首露出泊位端；工坊侧窗后的遮挡内墙收成上下承力边，侧角可读内部工具行程。站指挥冠承力盘和运动环扩大，原下承力颊渐缩并压入 owned 环截面；站下缘重复箱体改成连续装甲侧壳，节点中心落在本段甲板中部，低位通道保持。站下暗色块仍显，四设施与环的共同主剪影、材质协调仍不足，整体未通过。下一步须继续重做站节点与环的共同轮廓，不以局部调高／收窄代替。

## 最新同版证据边界

`082e2e2e` 的炉受影响完整态默认和70°原图、脚本、导入／取图日志固定于[独立归档 ac4ce0be](https://github.com/rlmclmc2-boop/space_idle/tree/ac4ce0be)；7 件文件逐件从 Git blob 复核 SHA256。炉料斗25°及构建图证仍见[归档 72bb3c81](https://github.com/rlmclmc2-boop/space_idle/tree/72bb3c81)，70°图不能证明矿石可辨。站受影响完整态默认、单建25°和完整态25°原图见[归档 40b4d44b](https://github.com/rlmclmc2-boop/space_idle/tree/40b4d44b)，站模型构建及下侧图见[归档 8a15ec7d](https://github.com/rlmclmc2-boop/space_idle/tree/8a15ec7d)；两归档分别复核 8／9 件文件。工坊默认／70° 沿用[归档 0c6474eb](https://github.com/rlmclmc2-boop/space_idle/tree/0c6474eb)，船坞默认／25° 沿用[归档 1f5c63e0](https://github.com/rlmclmc2-boop/space_idle/tree/1f5c63e0)，其余六类默认沿用[归档 1d4e07ad](https://github.com/rlmclmc2-boop/space_idle/tree/1d4e07ad)。built 状态及角度由脚本模拟，不代表自然施工、自然转动、整圈或整体通过。

四段 owned 的站、站＋炉、站＋炉＋工坊、完整态默认角模拟累积图固定于[独立归档 0ffa7e4e](https://github.com/rlmclmc2-boop/space_idle/tree/0ffa7e4e)；6 件文件从 Git blob 复核 SHA256。此后只改炉料斗和站节点／其 owned 甲板截面，不改变环段归属；图证仍不能当作自然建造流程。

## 有效契约与持续交付

四设施业务领取、人员及建造状态继续读现有已接纳快照；星球余额原位读 Economy balance_rows()。资源整数接口已按 Owner f9244a30 逐方法消费至本分支，定向证据在[归档 65b689a4](https://github.com/rlmclmc2-boop/space_idle/tree/65b689a4ed17fc8f38d6b0cc807fe7abc77df55f)，不称完整玩法验收；炉页既有 presentation_model 缺口归原组，不阻塞星球形体。保存去 configHash 绑定的本分支方法整合见[归档 1ac375fa](https://github.com/rlmclmc2-boop/space_idle/tree/1ac375fa7ba7061d512eabef3e7da6f512e7b060)，不重改规则。公共控件／图标由项目源维护，不等待 Figma 或公共壳。

局部提交、归档、推送和进度报告只是检查点，之后立即做原范围下一项。协调父线程发送 final 或显示 completed 仅结束协调回报，**不是**制作终点或交接信号。只有本执行者实际发生上下文压缩时，才保全 HEAD、WIP、最新图路径并在同工作区停止交接；真实不可继续阻塞须准确记录动作与结果。完整版本已交用户而某特定项确需其决策时，只暂停该项，其他可做项继续。

