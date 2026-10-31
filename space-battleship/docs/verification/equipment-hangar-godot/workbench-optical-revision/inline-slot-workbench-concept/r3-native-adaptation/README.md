# R3 已认可方向：同项原生适配进行中

用户已认可14:52实际送达的42ea4ffc R3共同方向并要求解决图标底色；本轮恢复原任务，保2fe87f93的16px字号、共享数字角色、费用同排／逐费不足、原裁剪和武器→防御顺序，不main、不新工作区或独立复测线程。本人未实际平台压缩。此页仅当前调查，不把旧22395运行证据称R3新实机。

已读共同最新681a07fd入口、42ea4ffc原R3绘制源和完整晚图。**图标方底的直接来源是把旧整屏图裁区当成图标**：equipment_row第78行装备、第92／96行资源都用source截图draw_texture_rect_region；导弹42×48裁区2016像素alpha全255且角点为旧卡RGB(220,226,215)，双费19×19裁区361像素alpha全255且角点为旧选中卡RGB(210,221,211)。这比原PNG角点透明更直接；原图透明不代表截图裁片透明。具体源SHA／范围／alpha统计见[诊断JSON](icon-source-diagnosis.json)。

统一路径应由稳定装备／资源ID直接绘制原alpha Texture2D或ResourceVisuals.icon；不手工逐图裁原图、不为每图造mask、不每帧去底、不把modulate或导入开关当去不透明底。当前真实装备控件已经用manifest透明纹理和缓存ResourceVisuals.icon，不使用整屏截图图标；正式R3接入将保留这一路径。原资源图集裁区属于已有共同身份源，本组未擅改其边界。Godot导入配置仍alpha通道、lossless、premult_alpha=false；官方[导入说明](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html#process-fix-alpha-border)指出Fix Alpha Border处理滤波边缘，不能消除已烘入的不透明底。

整体正在固定最小R3材质源；本组需精确plate／card九宫格源矩形与边距、ordinary／primary／select各normal／hover／pressed／disabled／focus和选中态材质／文字角色。当前可用数字角色190a已接；不整棵覆盖BridgeTheme或从设计截图提纹理。源到后在原EquipmentSurface、原card、原select和原buttons替换材质，不新增层盖旧控件，复用现有真实2／5／8及长MAX／双费／不足／tooltip／边界驱动采同版完整图与动作。

后台a83最新共同入口称奖励恢复校验和chrono分帧仍待修，不把它称最终全局整数源。本分支此前仅接装备报价／钱包支付必要域，未接上述奖励／chrono方法；该窄接事实和原运行证据保持，新后台源由父／原组固定后再核本组必要范围，不自主扩整棵Owner树。
