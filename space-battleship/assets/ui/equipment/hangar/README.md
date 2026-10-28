# 装备机库静态背景

最新局部费用/图标窄修：下文来源与旧布局记录保留为历史。当前 `c22735c3` 只删原 `upgrade-console.svg`四条固定费用横分隔；左台按真实资源行数局部收缩42/16px，标题/主值/小框及右台保持。主图标按可见alpha区域与光学重心留内边距，正式PNG/manifest不改；背景PNG保持原始字节，仅运行时分段显示。具体位置、同版实图和待原审边界见[定向交接](../../../../docs/verification/equipment-hangar-godot/workbench-focused/README.md)，当前源hash追加于sources.json，不把历史台身252px或旧支承用途当作现行全部布局。

图04确认后授权的Godot装备实施素材。`hangar-console.png`仅包含空机库、停泊台和留白实体操作台，不含舰船、炮台、文字、按钮或数值。工具原PNG完整复制，提示词、输入与输出hash见`sources.json`；原输出保留在其记录路径。

Godot在左808×900模块内，将此图作为(0,85,808,815)的背景显示；这是材质显示变换，不是舰体/挂点/战斗几何。正式舰体仍消费`assets/ui/ships/manifest.json`，四种武器消费`assets/weapons/fleet_20261019/manifest.json`及PNG，防御图标沿用既有SVG。本图不提供canonical武器身份、控制、报价或业务。

2026-10-28 装备专属视觉修订新增 `terminal-housing.png` 与 `support-arm.png`（原ImageGen输出完整复制；提示词及hash见sources.json）。前者用整张作槽终端、上640px Atlas作按钮/批量机壳；后者用三个Atlas区域连接终端底部插座和正式manifest挂点，关节中心对准端点，末端在舰体/武器下方。没有烘焙文字、装备身份、数值或业务响应。

当前背景改为上下两段显示：原(0,0,1188,845)→(0,85,808,485)，原(0,845,1188,479)→(0,570,808,330)。该显示变换只扩充操作台，与Battle坐标、正式舰体/武器/挂点规则无关。装备专属Theme以数值OpenType轴400/600绘字；真实栅格/指标证据见验证目录visual-pass/font-raster.json及PNG。共享宿主和其他模块字体未改。

当前清理修订改用新建 `terminal-clean.svg`：220×82、干净连续轮廓、宽象牙装甲面与深蓝承重底座，socket中心(110,73)。SVG为新写几何/渐变源，不是程序清洗或裁掉原PNG白点。原PNG保留来源，已退出所有运行控件；普通按钮和竖候选分别使用native材质，按初始化缓存normal/hover/pressed/disabled/focus与选中变体，不复用宽机壳。支承原PNG不变。一次ImageGen清理尝试仍有外部白点，实际检查后未采用，输出路径/hash/原因记于sources.json。

用户退回后的升级台打磨新增 `upgrade-console.svg`，原位置(24,606,452,252)沿已有金属内缘作设备面材，分对象梁、主值浅凹区、资源账区和动作台沿；不含数值/文字/交互。新写SVG源/hash见sources.json。顶部不再绘制任何标题贴片，舰名字样直接放在原机库梁上。武器仍依正式manifest；2/4炮舰按左右挂点对布卡，5炮大舰第三防御卡与UI标记独立。原支承与槽机壳保持。
