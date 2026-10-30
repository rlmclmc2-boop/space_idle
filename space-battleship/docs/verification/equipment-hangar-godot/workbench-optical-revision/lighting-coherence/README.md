# 装备共同受光与承托返修候选（整体待原审）

原审退回 `9625564c/79e48f10`：字阶、轮廓及焦点趋同保留，但仪表/候选上缘大片近白亮面像薄片，金购买/安装/Batch键面与承托区分弱。原唯一目录/美术分支继续，本轮源码 `fc361675131aa59ce21ec270a5aaa7e9715f9746`；**不自判整体艺术通过，原整体品质目标仍待根/原Astra实际判断**。

[常态整屏](01-normal.png)／[原像素局部](01-normal-local.png)、[异候选整屏](02-comparison.png)／[局部](02-comparison-local.png)、[不足整屏](03-disabled.png)／[局部](03-disabled-local.png)、[Batch整屏](04-batch.png)／[局部](04-batch-local.png)均为固定源码后的同版真实Godot 1440×900根viewport。4整屏、4区域局部及[主键焦点](focus-primary-local.png)、[候选焦点](focus-candidate-local.png)、[弱操作焦点](focus-quiet-local.png)共11张均已实际view_image，没有缩放拼贴或合成界面。

## 实际替换的材质关系

先实看旧完整整屏、原机库与原control-materials/painted-console-shell源。仍使用原同一EquipmentSurface及同一内漆面，替换其共同明暗/截面：

- 原底材亮度 `clamp(0.48+1.8*luma,0.60,1.02)` 改为 `clamp(0.44+1.60*luma,0.71,0.94)`，保留原磨痕/漫反射起伏，限制峰值。事实面由近白改灰绿漆色，不再跨整个上缘提亮。
- 同一连续受光截面细分为窄肩、宽漫反射面、下侧回边；顶灯方向保持一致。仪表与候选嵌入承托，顶缘接触遮蔽、下缘细受光；执行键从承托抬起，窄亮肩、较暗朝下回边和下落接触影形成同材质的不同安装关系。
- 金购买/安装/Batch共用上述键截面与同一漆面，暖赭金仅承担执行强调；数量/次操作沿用蓝灰，同截面；禁用仍冷暗面及不透明ccd6d0文字。不是额外金属框皮、盖片或新Panel，也没有重排和加噪。

自然预览曾把原漆面变化压得太平，已在最终版保回中频差异并限制亮度峰值；原两轮tmp预览均保留，不冒充最终图。以上是作者说明具体实现，不能以同源或去白替代整体观感通过。

## 边界和实际验证

只改equipment_panel；[源码边界](source-boundaries.json)核61个其余顶层函数逐字79e48，包括构造、布局、选择/两键、Owner消费、精准局部刷新、资源icon_modulate及舰船几何。变化仅_setup_materials（含原EquipmentSurface类）与_surface_material；12个既有宿主/业务/机库/壳/资源helper/材质图文件逐字原版。无新源资产、节点、公共宿主或规范改动。标题沿壳切角、原266/288结构、纯空位/无记录保持；大幅压缩/详情重排提案仅历史存档。

[环境](runtime-environment.json)为保留原4.7.2/main.tscn/Session/native、DISPLAY=:99、gl_compatibility。解析exit0；必要视觉过程exit0，`EQUIPMENT_LIGHTING_COHERENCE_VISUAL_COMPLETE failures=0`。受控开放、Lv19及有限钱包只用于原有常态/异候选/不足/Batch采图，没有购买或新36/全链复测。记录确认6角色同底材、3个Native焦点has_focus、Native禁用与Owner不足报价；不把它当交易或艺术验收。未新测按下/hover图、冷却计时、全舰满装、极端MAX、Windows-DPI或共享宿主组合；旧证据保持各自版本。

本轮实看可确认近白大片反光已收窄、动作有下侧回边且文字保留，但是否与机库厚实漆面统一、金键承托是否足够自然，由原整体审裁定。公共顶栏/右战场仍由整体组负责。本次未实际上下文压缩，无在跑任务/已知权限阻塞，未写main/Library/Space；只普通push原非main分支。
