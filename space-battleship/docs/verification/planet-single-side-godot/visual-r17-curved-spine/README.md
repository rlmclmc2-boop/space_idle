# R17 星球整体结构：当前制作入口

本页只保留当前依据、动作和证据。旧局部图与说明已从制作树迁出；不据旧候选宣称当前版本通过。

## 批准依据与完成判据

按用户已认可的[实体环带完整态 8136cef8](../../../game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png)制作装甲承力脊与四设施共同形体；[闭环分步 1eda07fd](../../../game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-stages-closed.png)约束独立建造累积。环须贯入各设施承力节点；球与环独转、探索船另轨、真实球后遮挡、前弧暗缝和四段独立 owned 归属保持。原尺寸完整态及受影响侧角应读出站／炉低位连续通道、炉双料斗和接收口、工坊工作口、船坞停靠艇及站顶运动件。不得出现飞碟、暗盘、浅方壳、外挂三件、假垫层或仅改色／环宽替代资产制作。**整体尚未通过，继续制作。**

## 当前具体动作

当前源码 cf0b04ec 保留炉体下凹热井、船坞压力龙骨和环段接缝；船坞停靠艇沿发射方向前移 0.27 且在坞内上抬 0.05，站体原有内侧承力网格拓宽低位通道并使入口外扩；炉体两料斗底板与矿块降入已有围壁，形成可见内腔；工坊移动滑座分为同一枢轴上的两条承力轨，露出工作口。默认、25° 与 70° 原尺寸图已复看，仍需继续四节点共同体量、材质与剪影协调，优先在设施同网格与已有 owned 承力截面中修形；任何候选先看原尺寸再决定保留。

## 最新同版证据边界

工坊开放滑座的第三阶段及完整态默认／70° 原尺寸图、脚本和日志见[独立归档 f206eec2](https://github.com/rlmclmc2-boop/space_idle/tree/f206eec25a1b8b76cf567b193a948379d9d02ebf)，11 件证据文件已从 Git blob 复核 SHA256；工作口在所见角度可辨。炉体料斗内腔的第二阶段及完整态默认／70° 原尺寸图、脚本和日志见[独立归档 fd882c1f](https://github.com/rlmclmc2-boop/space_idle/tree/fd882c1f02cebf6a9bf124c128e4ca97b1966f72)，11 件证据文件已从 Git blob 复核 SHA256；双料斗井口在所见角度可辨。船坞小艇上抬后的 2048×768 默认／70° 完整体图、脚本及日志见[独立归档 3a73a52c](https://github.com/rlmclmc2-boop/space_idle/tree/3a73a52c89dffea2515117469baf9df4cf4b9834)，8 件证据文件已从 Git blob 复核 SHA256；原尺寸图显示小艇仍在坞内。48bd506b 的 2048×768 站单建与四设施完整态默认／25°／70°图、脚本、导入和检查日志固定于[独立归档 0aaacd61](https://github.com/rlmclmc2-boop/space_idle/tree/0aaacd6121a13b0a0dd77677699d54dabca60ab9)；14 件证据文件已从 Git blob 复核 SHA256。已亲看六张原图：站体低位口仍开放、前移小艇仍留在坞内；这不代表整体通过、自然施工或整圈。炉体热井改动前的局部模拟片段与取图边界仍固定于[独立归档 adb5e9fb](https://github.com/rlmclmc2-boop/space_idle/tree/adb5e9fb77ae77c392c93f5f457c11e7929cc9ce)，其中 advance(0.25, false) 是模拟步进。以后仅补实际改动影响的建造态、侧角与必要连续片段，不另开独立复测。

## 有效契约与持续交付

四设施业务领取、人员及建造状态继续读现有已接纳快照；星球余额原位读 Economy balance_rows()。资源整数接口已按 Owner f9244a30 逐方法消费至本分支，定向证据在[归档 65b689a4](https://github.com/rlmclmc2-boop/space_idle/tree/65b689a4ed17fc8f38d6b0cc807fe7abc77df55f)，不称完整玩法验收；炉页既有 presentation_model 缺口归原组，不阻塞星球形体。保存去 configHash 绑定的本分支方法整合见[归档 1ac375fa](https://github.com/rlmclmc2-boop/space_idle/tree/1ac375fa7ba7061d512eabef3e7da6f512e7b060)，不重改规则。公共控件／图标由项目源维护，不等待 Figma 或公共壳。

局部提交、归档、推送和进度报告只是检查点，之后立即做原范围下一项。协调父线程发送 final 或显示 completed 仅结束协调回报，**不是**制作终点或交接信号。只有本执行者实际发生上下文压缩时，才保全 HEAD、WIP、最新图路径并在同工作区停止交接；真实不可继续阻塞须准确记录动作与结果。完整版本已交用户而某特定项确需其决策时，只暂停该项，其他可做项继续。

