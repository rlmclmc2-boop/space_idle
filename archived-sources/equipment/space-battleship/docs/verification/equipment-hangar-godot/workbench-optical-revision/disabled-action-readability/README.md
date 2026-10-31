# 禁用主动作可读性窄修（原整体质感继续，待原审）

源码 `e52e72c36df55f89b3caa70cccf9b66874947d96`，基线 `4d56ad55f2fcb68cd665ddd9e19750e805b28e47`／材质源码a8467d65。根对组合6e49c51a的原审指出禁用“购买1级”灰蓝字弱于金属边高光；本SOL先核原art分支实际HEAD4d56/运行源a846、tracked干净后修正，没有用旧基线覆盖组合或本组源。当前整体质感尚未通过，这只是沿原整体任务的可读性窄项，不将局部材质接纳当原目标完成。

## 同版图与原生状态

[正常可支付整屏](01-affordable.png)／[原像素局部](01-affordable-local.png)、[资源不足整屏](02-unaffordable.png)／[局部](02-unaffordable-local.png)、[换装冷却整屏](03-cooldown.png)／[局部](03-cooldown-local.png)全部实际view_image。正常金色购买键保留原主层级；不足时冷暗键面、浅灰动作字和克制轮廓保持可辨，费用1600铁/10简并与红色不足原因完整。冷却图中正常购买保持暖金可用，安装为冷暗禁用、文字“换装冷却中”清楚，冷却剩余10秒仍就地可见。

Godot4.7.2当前main.tscn/Session/native同版必要视觉取图进程exit0，`EQUIPMENT_DISABLED_INK_VISUAL_COMPLETE failures=0`。[原视觉状态记录](visual-state-records.json)、[驱动](capture-driver.gd.txt)、[日志](runtime.log.txt)保留。场景沿用受控Lv19/availability/钱包；冷却是Owner接受的10秒switch_ready_at受控fixture，并消费真实comparison.switch_admission=EquipmentSwitchLocked，**不是本轮真实换装或自然计时冷却测试**。没有新装备/交易动作来制造状态。

不足时Native Button.disabled=true；在同一次视觉取图里点击该禁用键后，槽事实/预算/last_result前后完全一致，未触发动作。该窄记录只支持本状态未触发，不冒称交易四保护或全链复测。

## 实际修法

原生禁用字色原为8da5ac，冷键纹理又受state tint和kind disabled双重乘暗，抗锯齿字边弱于亮边。现在主动作的font_disabled_color显式为不透明浅灰ccd6d0；字号、字重、阴影、排版和点击区均不改，不加文字光晕或描边。

初始化从既有navy漆面缓存一份disabled finish，亮度高于0.24的材料像素用`0.24+(light−0.24)×0.28`压缩高光，保RGB比例与alpha/轮廓。该处理只有一次，不每帧扫描；材质纹理内没有文字，动作字不随纹理压暗。禁用state仍用原0.72/0.77/0.80冷色调制，但移除额外0.66/0.73/0.76第二次乘暗。正常/hover/pressed/focus和金色执行面不改，禁用仍冷暗、不带暖金主操作吸引力；这次没有把整批按钮同亮化。

只改equipment_panel14增2删，无新资产批/Panel/框层/公共样式。source-boundaries.json核：除禁用finish初始化、禁用纹理选择/调制、主键disabled字色三处归一后，equipment_panel整文件逐字前版。12项宿主/Owner/资源helper/正式机库与原壳/控件材质/资源图集逐字前版；保持当前结构/字号/两键/切角/资源原色/Owner精准刷新。前[完整材质与原生状态证据](../coherent-material-polish/README.md)继续按a846的原版本口径，不能把其中旧disabled图当本轮图。

4.7.2 check-only及非raw源码/文档diff-check通过；Godot原始check.log尾空行原样保留。旧36运行仍只属于89ac5d0a，本轮没有扩36、独立矩阵、交易全链、宿主或main。没有新视频，当前必要三状态原尺寸图只服务本禁用可读性审查。

原整体质感目标仍未闭合，继续原Astra/根原项判断；不得再次写成没有未完事项、默认收工。原工作区/美术分支/cache/未跟踪/tmp/既有源证据全保留；本SOL截至本自然项归档未实际上下文压缩，无运行任务或权限阻塞，只普通push非main，不Library/Space/新任务/子代理/工作区。
