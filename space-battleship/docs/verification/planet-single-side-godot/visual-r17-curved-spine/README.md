# R17 星球整体结构：当前制作入口

本页只保留当前依据、动作和证据。旧局部图与说明已从制作树迁出；不据旧候选宣称当前版本通过。

## 批准依据与完成判据

按用户已认可的[实体环带完整态 8136cef8](../../../game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png)制作装甲承力脊与四设施共同形体；[闭环分步 1eda07fd](../../../game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-stages-closed.png)约束独立建造累积。环须贯入各设施承力节点；球与环独转、探索船另轨、真实球后遮挡、前弧暗缝和四段独立 owned 归属保持。原尺寸完整态及受影响侧角应读出站／炉低位连续通道、炉双料斗和接收口、工坊工作口、船坞停靠艇及站顶运动件。不得出现飞碟、暗盘、浅方壳、外挂三件、假垫层或仅改色／环宽替代资产制作。**整体尚未通过，继续制作。**

## 当前具体动作

当前源码 `2709cb92` 在四段 owned 承力截面、站低位通道、工坊工作口和船坞实穿口基础上，把炉原压力舱改为一件从两侧承力墙拱起的闭合网格，并在同一网格开热井；双料斗与接收口保留。默认、25°、70° 图中拱面和炉中间通道可辨。四设施与环的共同主剪影、材质协调仍不足，整体未通过；下一步继续实体衔接，按受影响处补原尺寸图。

## 最新同版证据边界

`2709cb92` 的炉受影响完整态默认、25°、70° 原图、脚本、构建／导入／取图日志固定于[独立归档 2709cb92](https://github.com/rlmclmc2-boop/space_idle/tree/2709cb92)；11 件文件逐件从 Git blob 复核 SHA256。其余六类默认与站单建侧角沿用[上一版归档 1d4e07ad](https://github.com/rlmclmc2-boop/space_idle/tree/1d4e07ad)，不扩称本轮新全套验证。built 状态及角度由脚本模拟，不代表自然施工、自然转动、整圈或整体通过。

## 有效契约与持续交付

四设施业务领取、人员及建造状态继续读现有已接纳快照；星球余额原位读 Economy balance_rows()。资源整数接口已按 Owner f9244a30 逐方法消费至本分支，定向证据在[归档 65b689a4](https://github.com/rlmclmc2-boop/space_idle/tree/65b689a4ed17fc8f38d6b0cc807fe7abc77df55f)，不称完整玩法验收；炉页既有 presentation_model 缺口归原组，不阻塞星球形体。保存去 configHash 绑定的本分支方法整合见[归档 1ac375fa](https://github.com/rlmclmc2-boop/space_idle/tree/1ac375fa7ba7061d512eabef3e7da6f512e7b060)，不重改规则。公共控件／图标由项目源维护，不等待 Figma 或公共壳。

局部提交、归档、推送和进度报告只是检查点，之后立即做原范围下一项。协调父线程发送 final 或显示 completed 仅结束协调回报，**不是**制作终点或交接信号。只有本执行者实际发生上下文压缩时，才保全 HEAD、WIP、最新图路径并在同工作区停止交接；真实不可继续阻塞须准确记录动作与结果。完整版本已交用户而某特定项确需其决策时，只暂停该项，其他可做项继续。

