# 反应炉 R4 × 当前共享宿主：实际组合候选

代码`design/shared-host-shell@db94845ab79eda10a318b7cfa3524aefe5730d5e`，沿已限定关闭P2/裁取问题的47a910a0宿主。反应炉来源ae0508ee，[原组同版入口](https://github.com/rlmclmc2-boop/space_idle/blob/ae0508ee/space-battleship/docs/verification/reactor-centered-godot/evidence/ship-hub-r4/README.md)。未合main；原模块Astra正在审核，**本组合不宣称模块视觉通过**。

## 接入边界

- 继续使用现有唯一公共资源/导航与reactor路由；原组分支的旧黑色main顶部没有导入。main/shared_host、装备/星球、GameSession、Reactor/Economy领域文件相对47a逐字节不变，所有已关闭门禁/预览/快照修复保持。
- 外根仍(0,0)/808×900，R4内部SubViewportContainer与工作层内容根为(0,65)/808×835。原三/四设备背景、核心纹理、两个shader及reactor_stage共7文件逐字节来自ae0508ee；没有接入旧centered-v1品质板或侧框填空。
- reactor_scene原布局、局部等级/容量/费用/主控/反馈、滑杆及数据/命令方法保持。只新增四个最小共享视图端口与自有caption回收，在原_show_current_readings/_unknown旁同步共享96×26“反应炉N级/反应炉”上下文。主控区局部等级是原内部读数，保留其(30,761)位置，不按旧顶部标签处理而删除。
- set_shared_host仅管理模块自有caption，不删除slot或宿主其他子节点；backdrop不使用。R4无自有模态，has_exclusive_ui=false；滑杆焦点由现有宿主共同门禁持有。prepare_host_hide只撤离本模块焦点，普通切换保留原草稿；显隐/时钟/工作层停更仍原组逻辑。
- 原bind_presentation、bind_purchase_quote、game_time/paused/running上下文、presentation_changed/budget_changed和command_finished接线全部复用，不新建领域DTO、计算或事件消费。

## 1440×900同版实机与必要观察

[三设备命令前](evidence/three-before-command.png) · [三设备运行](evidence/three-active.png) · [四设备运行](evidence/four-active.png) · [四设备收起](evidence/four-collapsed.png) · [四设备恢复](evidence/four-restored.png)。三/四运行及恢复图已实际view_image；这是现有共享顶部下的正式main/Session/native画面，未把模板顶部拼贴进原分支图。

[16项必要接入记录](evidence/observations.json)全部通过：[真实日志](evidence/godot-live.txt)无脚本/资源错误，仅既有Xorg VSync警告；[4.7.2解析](evidence/godot-check.txt)、资源导入及Git diff检查通过。[源身份/环境/哈希](evidence/environment.json)。

覆盖外根/内容根与原战场投影、三/四设备和凝聚显隐、共享上下文/原局部等级、原均分预览/确认回调、时钟驱动、滑杆焦点与G门禁/战场撤焦鼠标、跨路由实例/草稿保持、隐藏停工作层、收起静态与恢复、真实钱包文本。

验证沿原任务隔离/tmp存档，用公开Campaign存取和Reactor refresh临时开放反应炉/凝聚。没有注入预算、购买升级、强推游戏时钟或改配置；三/四态各一次均分/确认只证明宿主沿原命令接线。不是自然开放/收入证据，也没有重跑原组超容量/购级/长金额/全运行或连续视频检查。

## 状态与后续

仅共享接入候选完成，交原根审/Astra核组合净空与边界；模块内部视觉仍等原反应堆Astra，星球后续造型仍原组负责。本次不改模型、不扩大全窗口/DPI/自然全流程/V0或整屏美术结论。无权限或运行阻塞，候选不合main。
