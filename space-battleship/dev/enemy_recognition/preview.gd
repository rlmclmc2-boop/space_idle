extends Node2D
## Review-only rendering. Reads source rows; never instantiates BattleGame or writes saves.
const BG := Color("080e1b")
const PANEL := Color("101c2c")
const INK := Color("e0ecf4")
const MUTED := Color("8195ac")
const METAL := Color("986f52")
const ENERGY := Color("64b5ff")
const REPAIR := Color("ffaf61")
const ENVELOPE := preload("res://envelope.gd")
var data: Dictionary
var visuals: Dictionary
var textures: Dictionary = {}
var hull_boundaries: Dictionary = {}
var font: Font
var clock := 0.0
var mode := "board"
var output := ""
var frame := 0
var capture_frames := 0
var grayscale := false
var protection_gap := 2.0
var protection_layer_gap := 2.5
var coverage_report: Dictionary = {}

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))
	visuals = JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_weapon_visuals.json"))
	font = load("res://assets/fonts/NotoSansSC.ttf")
	for key in visuals.ships:
		if str(key).begins_with("enemy_"):
			textures[key] = load(visuals.ships[key].texture)
			hull_boundaries[key] = Geometry2D.convex_hull(ENVELOPE.alpha_boundary(textures[key].get_image()))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):mode=argument.trim_prefix("--mode=")
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
		if argument.begins_with("--frames="):capture_frames=int(argument.trim_prefix("--frames="))
		if argument=="--gray":grayscale=true
	protection_gap=float(ProjectSettings.get_setting("visuals/enemy_protection_gap_pixels",2.0))
	protection_layer_gap=float(ProjectSettings.get_setting("visuals/enemy_protection_layer_gap_pixels",2.5))
	if grayscale:
		var shader := Shader.new()
		shader.code="shader_type canvas_item; void fragment(){ float l=dot(COLOR.rgb,vec3(0.299,0.587,0.114)); COLOR=vec4(vec3(l),COLOR.a); }"
		var gray_material := ShaderMaterial.new()
		gray_material.shader=shader
		material=gray_material
	DisplayServer.window_set_size(Vector2i(1373,883))
	get_viewport().size=Vector2i(1373,883)
	if mode=="coverage":coverage_report=check_coverage()
	if not output.is_empty():capture.call_deferred()

func _process(dt: float) -> void:
	if output.is_empty():clock+=dt
	queue_redraw()

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	if mode=="coverage":
		var report_file := FileAccess.open(output.path_join("coverage-check.json"),FileAccess.WRITE)
		report_file.store_string(JSON.stringify(coverage_report,"\t"))
	var count := maxi(1,capture_frames)
	for i in count:
		clock=float(i)/10.0 if capture_frames>0 else 1.8
		queue_redraw()
		await RenderingServer.frame_post_draw
		var path := output.path_join("%s%s-%03d.png" % [mode,"-gray" if grayscale else "",i])
		get_viewport().get_texture().get_image().save_png(path)
		frame+=1
	print("VISUAL_CAPTURE_OK mode=%s frames=%d output=%s" % [mode,frame,output])
	get_tree().quit()

func label(value: String, point: Vector2, size := 18, color := INK) -> void:
	draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func card(rect: Rect2) -> void:
	draw_style_box(panel_style(),rect)

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=PANEL
	style.border_color=Color("26384b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style

func _draw() -> void:
	draw_rect(Rect2(0,0,1373,883),BG)
	if mode=="small":draw_small();return
	if mode=="recovery":draw_recovery();return
	if mode=="weapons":draw_weapons();return
	if mode=="coverage":draw_coverage();return
	label("敌人识别样板 · 防御看舰体，进攻看炮口",Vector2(28,40),27)
	label("复用现有 Toon 舰体 / 独立预览 / 代表样本，待视觉认可",Vector2(28,68),16,MUTED)
	var titles := ["厚物理装甲 → 激光","小型群聚 → 导弹","大型能量盾 → 磁轨","持续恢复盾 → 光束"]
	var ids := [1046,1007,1088,1017]
	var cues := ["橙色六边防护轮廓","小轮廓 · 重复群体 · 细翼","蓝色六边盾 · 舰首再加一层","分片防护轮廓 · 向内回补"]
	for i in 4:
		var x := 24.0+float(i)*337.0
		card(Rect2(x,92,314,402))
		label(titles[i],Vector2(x+14,121),20)
		label(cues[i],Vector2(x+14,147),14,MUTED)
		var row: Dictionary=data.enemies[str(ids[i])]
		if i==1:
			for j in 5:ship(row,Vector2(x+72+float(j%3)*73,225+float(j/3)*72),56,"laser_mon",false)
		else:ship(row,Vector2(x+157,247),102,"laser_mon",false)
		label("正常窗口尺寸（1373 × 883）",Vector2(x+14,355),14,MUTED)
		if i==1:
			for j in 5:ship(row,Vector2(x+72+float(j%3)*59,396+float(j/3)*46),normal_width(row),"laser_mon",false)
		else:ship(row,Vector2(x+157,412),normal_width(row),"laser_mon",false)
		label("读取敌人 %s" % ids[i],Vector2(x+14,477),13,MUTED)
	label("进攻提示 · 以下保持同一中性舰体，单独比较武器",Vector2(28,529),20)
	for i in 2:
		var x := 24.0+float(i)*674
		card(Rect2(x,548,651,245))
		var physical := int(data.equipment["cannon-mon" if i==0 else "laser_mon"][0].dmgtype)==2
		label("物理火炮 → 物理防御" if physical else "能量激光 → 能量防御",Vector2(x+18,580),22)
		label("厚单管 / 黑色膛口 / 短闪与实体弹" if physical else "双叉导轨 / 发光透镜 / 细脉冲",Vector2(x+18,608),16,MUTED)
		ship(data.enemies["1019"],Vector2(x+110,699),66,"cannon-mon" if physical else "laser_mon",true)
		weapon(Vector2(x+286,676),57,physical,0.9)
		shot(Vector2(x+286,728),physical,1.0)
		ship(data.enemies["1019"],Vector2(x+480,692),normal_width(data.enemies["1019"]),"cannon-mon" if physical else "laser_mon",true)
		label("正常尺寸",Vector2(x+441,770),14,MUTED)
	label("炮口仅依据 equipment → dmgtype；舰体仅依据 size / armourType / shield 字段。中性组不附加克制标记。",Vector2(28,829),16,MUTED)
	label("上排近看辅助结构；下排正常观看尺寸才用于识别审查。护盾无常驻大片光晕。",Vector2(28,857),16,MUTED)

func normal_width(row: Dictionary) -> float:
	# Same main.gd width cap/formula at front depth=1, variance=1, Frigate baseline.
	var size := int(row.size)
	var boss := size>=5
	var tier := 1.85 if boss else 1.5 if size>=4 else 1.0+float(size-1)*0.08
	var limit := 78.0 if boss else 66.0 if size>=4 else 54.0
	var base := minf(limit/(1.12*1.08),887.0*1.2*0.061*1.25*0.34*tier)
	return base*float(data.config.get("enemyVisualScaleSize"+str(size),1.0))*1.12*(1373.0/1952.0)

func check_coverage() -> Dictionary:
	var failures: Array = []
	var cases := 0
	var min_hull_gap := INF
	var min_nested_gap := INF
	var min_front_gap := INF
	var settings := {"gap_pixels":protection_gap,"layer_gap_pixels":protection_layer_gap,"alpha_threshold":0,"weapon_aim_degrees":[-180,-90,-60,0,60,90,180],"hull_rotation_degrees":[-6,0,6],"scale_factors":[0.659,1.0,1.08]}
	for key in visuals.ships:
		if not str(key).begins_with("enemy_"):continue
		for hardpoint in visuals.ships[key].hardpoints:
			for endpoint in [-int(hardpoint.rotation_limit),int(hardpoint.rotation_limit)]:
				if not settings.weapon_aim_degrees.has(endpoint):settings.weapon_aim_degrees.append(endpoint)
	settings.weapon_aim_degrees.sort()
	for size in range(1,7):
		var row := {"size":size}
		for physical in [false,true]:
			for factor in settings.scale_factors:
				var width := normal_width(row)*float(factor)
				for aim in settings.weapon_aim_degrees:
					var points := visible_bounds(row,width,physical,deg_to_rad(float(aim)),true)
					var outlines := protection_outlines(points,width)
					for rotation in settings.hull_rotation_degrees:
						var angle := PI+deg_to_rad(float(rotation))
						var rotated_points := PackedVector2Array()
						var rotated_inner := PackedVector2Array()
						var rotated_outer := PackedVector2Array()
						var rotated_front := PackedVector2Array()
						for point in points:rotated_points.append(point.rotated(angle))
						for point in outlines[0]:rotated_inner.append(point.rotated(angle))
						for point in outlines[1]:rotated_outer.append(point.rotated(angle))
						for point in outlines[2]:rotated_front.append(point.rotated(angle))
						var hull_gap: float=ENVELOPE.min_clearance(rotated_points,rotated_inner)-maxf(1.3,width*0.026)*0.5-0.5
						var nested_gap: float=ENVELOPE.min_clearance(rotated_inner,rotated_outer)-maxf(1.3,width*0.026)-0.5
						var front_gap: float=ENVELOPE.min_clearance(rotated_outer,rotated_front)-maxf(1.3,width*0.026)-0.5
						min_hull_gap=minf(min_hull_gap,hull_gap)
						min_nested_gap=minf(min_nested_gap,nested_gap)
						min_front_gap=minf(min_front_gap,front_gap)
						cases+=1
						if hull_gap<protection_gap-0.001 or nested_gap<protection_layer_gap-0.001 or front_gap<protection_layer_gap-0.001:
							failures.append({"size":size,"physical":physical,"scale":factor,"aim":aim,"rotation":rotation,"hull_gap":hull_gap,"nested_gap":nested_gap,"front_gap":front_gap})
	var report := {"status":"passed" if failures.is_empty() else "failed","cases":cases,"settings":settings,"min_visible_hull_gap_pixels":min_hull_gap,"min_visible_nested_gap_pixels":min_nested_gap,"min_visible_front_gap_pixels":min_front_gap,"failures":failures,"scope":"all six PNG alpha silhouettes, fixed weapon body and repair nodes; excludes firing VFX/projectiles"}
	print("ENVELOPE_CHECK "+JSON.stringify(report))
	return report

func draw_coverage() -> void:
	label("防護包覆修正 · 完整舰体、炮口和挂件",Vector2(28,42),26)
	label("各六边斜边按实际可见轮廓求包络；间隙2px，嵌套间隙2.5px；舰体尺寸不变。",Vector2(28,74),17,MUTED)
	var ids := [1007,1017,1088]
	var names := ["小型 · 蓝色能防","中型 · 橙色恢复盾","大型 · 物甲 + 能盾 + 前层"]
	for i in 3:
		var x := 24.0+float(i)*449
		card(Rect2(x,108,425,655))
		var row: Dictionary=data.enemies[str(ids[i])]
		var width := normal_width(row)
		var limit := 0.0
		for hardpoint in visuals.ships["enemy_"+str(int(row.size))].hardpoints:limit=maxf(limit,float(hardpoint.rotation_limit))
		label(names[i],Vector2(x+16,143),20)
		ship(row,Vector2(x+121,253),width,"cannon-mon",false)
		ship(row,Vector2(x+304,253),width,"laser_mon",false)
		label("同尺寸正常姿态",Vector2(x+16,385),16,MUTED)
		ship(row,Vector2(x+121,525),width,"cannon-mon",false,false,-1,true,deg_to_rad(-6),deg_to_rad(-limit))
		ship(row,Vector2(x+304,525),width,"laser_mon",false,false,-1,true,deg_to_rad(6),deg_to_rad(limit))
		label("舰体±6° / 炮口±%.0f°极限" % limit,Vector2(x+16,676),16,MUTED)
		label("左物理 / 右能量 · 舰宽%.1fpx" % width,Vector2(x+16,724),15,MUTED)
	label("几何包覆检查：%s · %d组 · 全6种舰体与两类炮口" % [coverage_report.get("status","未运行"),int(coverage_report.get("cases",0))],Vector2(28,803),18)
	label("恢复分片/颜色/炮口形状保持；斜边包覆结果见 coverage-check.json，实战识别仍须看图。",Vector2(28,846),16,MUTED)

func visible_bounds(row: Dictionary, width: float, physical: bool, weapon_angle: float, repair: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	var key := "enemy_"+str(clampi(int(row.size),1,6))
	for point in hull_boundaries[key]:points.append(point*width)
	var weapon_width := maxf(15,width*0.31)
	for point in ENVELOPE.weapon_bounds(weapon_width,physical):
		points.append(Vector2(0,-width*0.12)+point.rotated(PI+weapon_angle))
	if repair:
		for i in 3:
			var a := -PI/2+float(i)*TAU/3
			var center := Vector2(cos(a)*width*0.45,sin(a)*width*0.55)
			for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:points.append(center+corner*width*0.075)
	return points

func protection_outlines(points: PackedVector2Array, width: float, nested := true) -> Array[PackedVector2Array]:
	var hull_stroke := maxf(1.1,width*0.020)
	var shield_stroke := maxf(1.3,width*0.026)
	var base_stroke := maxf(hull_stroke,shield_stroke)
	var inner := ENVELOPE.fit(points,protection_gap+base_stroke*0.5+0.5)
	var outer := ENVELOPE.fit(inner,protection_layer_gap+(base_stroke+shield_stroke)*0.5+0.5) if nested else inner
	var front := ENVELOPE.fit(outer,protection_layer_gap+shield_stroke+0.5)
	return [inner,outer,front]

func ship(row: Dictionary, point: Vector2, width: float, attack: String, fire: bool, neutral := false, shield_fraction := -1.0, recovering := true, hull_angle := 0.0, weapon_angle := 0.0) -> void:
	var physical := int(data.equipment[attack][0].dmgtype)==2
	var has_shield := float(row.get("shield",0))>0
	var repair := has_shield and float(row.get("shieldRecovery",0))>0
	var show_hull_defense := not has_shield or shield_fraction==0.0 or int(row.armourType)!=int(row.get("shieldType",0))
	var outlines := protection_outlines(visible_bounds(row,width,physical,weapon_angle,repair),width,has_shield and show_hull_defense and int(row.armourType) in [1,2])
	draw_set_transform(point,PI+hull_angle)
	var dimensions := Vector2(width,width*2)
	draw_texture_rect(textures["enemy_"+str(clampi(int(row.size),1,6))],Rect2(-dimensions/2,dimensions),false)
	if not neutral:
		if int(row.armourType)==2 and show_hull_defense:armor(width,outlines[0])
		elif int(row.armourType)==1 and show_hull_defense:armor(width,outlines[0],ENERGY)
		if has_shield:
			var fraction := shield_fraction if shield_fraction>=0 else 0.6+0.3*fposmod(clock*float(row.get("shieldRecovery",0)),1.0)
			shield(width,repair,fraction,recovering,int(row.get("shieldType",0)),int(row.size),outlines[1],outlines[2])
	draw_set_transform(point+Vector2(0,width*0.12).rotated(hull_angle),hull_angle+weapon_angle)
	weapon(Vector2.ZERO,maxf(15,width*0.31),physical,0.7 if fire else 0.0)
	draw_set_transform(Vector2.ZERO)
	if fire:shot(point+Vector2(0,width*0.45).rotated(hull_angle),physical,width/66.0)

func armor(w: float, outline: PackedVector2Array, color := REPAIR) -> void:
	var closed := outline.duplicate()
	closed.append(closed[0])
	draw_polyline(closed,Color(color,0.8),maxf(1.1,w*0.020),true)

func shield(w: float, repair: bool, fraction: float, recovering: bool, defense_type: int, size: int, outline: PackedVector2Array, front: PackedVector2Array) -> void:
	var color := REPAIR if defense_type==2 else ENERGY
	if fraction>0:
		for i in 6:
			# Keep the approved segment fill starting edge/direction after refitting.
			var start := outline[(i+2)%6]
			var end := outline[(i+3)%6]
			if repair:
				draw_line(start.lerp(end,0.08),start.lerp(end,0.92),Color(color,0.18),maxf(1,w*0.024),true)
				var filled := clampf(fraction*6-float(i),0,1)
				if filled>0:draw_line(start.lerp(end,0.08),start.lerp(end,0.08+0.84*filled),Color(color,0.9),maxf(1.3,w*0.026),true)
			else:draw_line(start,end,Color(color,0.65),maxf(1.3,w*0.022),true)
	if fraction>0 and defense_type==1 and size>=4:
		# Bow-facing local cap only, not a second full hull glow.
		draw_polyline(PackedVector2Array([front[5],front[0],front[1]]),Color(ENERGY,0.85),maxf(1.4,w*0.026),true)

	for i in (3 if repair else 0):
		var a := -PI/2+float(i)*TAU/3 if repair else float(i)*PI
		var node := Vector2(cos(a)*w*0.45,sin(a)*w*0.55)
		draw_rect(Rect2(node-Vector2.ONE*w*0.075,Vector2.ONE*w*0.15),Color("303c45"))
		draw_rect(Rect2(node-Vector2.ONE*w*0.05,Vector2.ONE*w*0.10),Color(color,0.85 if fraction>0 else 0.22),false,maxf(1,w*0.02))
		if repair and recovering and fraction>0 and fraction<1:
			var toward := -node.normalized()
			var pulse := fposmod(clock*1.4+float(i)*0.33,1.0)
			var p := node+toward*w*(0.12+0.17*pulse)
			var cross := toward.orthogonal()*w*0.035
			draw_polyline(PackedVector2Array([p-toward*w*0.045+cross,p,p-toward*w*0.045-cross]),Color(color,1.0-pulse*0.55),maxf(1,w*0.025),true)

func weapon(p: Vector2, w: float, physical: bool, flash: float) -> void:
	var edge := maxf(1,w*0.035)
	draw_rect(Rect2(p+Vector2(-w*0.24,-w*0.22),Vector2(w*0.48,w*0.42)),Color("36424b"))
	if physical:
		draw_rect(Rect2(p+Vector2(-w*0.16,-w*0.15),Vector2(w*0.32,w*0.84)),Color("ac886a"))
		draw_rect(Rect2(p+Vector2(-w*0.23,w*0.48),Vector2(w*0.46,w*0.25)),Color("6e594a"))
		draw_rect(Rect2(p+Vector2(-w*0.15,w*0.57),Vector2(w*0.30,w*0.14)),Color("080d13"))
		if flash>0:
			var nose := p+Vector2(0,w*0.76)
			draw_colored_polygon(PackedVector2Array([nose+Vector2(-w*0.16,0),nose+Vector2(-w*0.06,w*0.20),nose+Vector2(0,w*0.11),nose+Vector2(w*0.08,w*0.19),nose+Vector2(w*0.16,0)]),Color("ffd7a0"))
	else:
		for side in [-1,1]:
			# Solid, outward shoulders and two separated short prongs form a wide fork.
			var fork := PackedVector2Array([p+Vector2(side*w*0.17,-w*0.18),p+Vector2(side*w*0.60,-w*0.08),p+Vector2(side*w*0.60,w*0.45),p+Vector2(side*w*0.41,w*0.45),p+Vector2(side*w*0.41,w*0.07),p+Vector2(side*w*0.17,0)])
			draw_colored_polygon(fork,Color("aabfc6"))
			draw_line(p+Vector2(side*w*0.49,w*0.20),p+Vector2(side*w*0.49,w*0.44),ENERGY,maxf(1,w*0.10),true)
		draw_rect(Rect2(p+Vector2(-w*0.13,w*0.02),Vector2(w*0.26,w*0.16)),ENERGY)
		if flash>0:draw_arc(p+Vector2(0,w*0.38),w*0.20,0,PI,10,ENERGY,edge,true)

func draw_weapons() -> void:
	label("进攻炮口第二版 · 同舰体、同尺寸、静态"+(" · 灰度" if grayscale else ""),Vector2(28,42),26)
	label("物理：居中长单管 / 黑膛；能量：外露宽双叉 / 中间留空。只改挂件，不增大敌舰。",Vector2(28,74),17,MUTED)
	var rows := [data.enemies["1007"],data.enemies["1019"]]
	for tier in 2:
		var y := 110.0+float(tier)*350
		for kind in 2:
			var x := 24.0+float(kind)*674
			card(Rect2(x,y,651,325))
			var physical := int(data.equipment["cannon-mon" if kind==0 else "laser_mon"][0].dmgtype)==2
			label(("物理火炮" if physical else "能量激光")+(" · 最小舰体" if tier==0 else " · 中型舰体"),Vector2(x+18,y+34),21)
			var row: Dictionary=rows[tier]
			var width := normal_width(row)
			for j in 3:
				ship(row,Vector2(x+110+float(j)*215,y+128),width,"cannon-mon" if physical else "laser_mon",false,true)
			label("正常窗口尺寸 · 舰宽 %.1fpx · 相同原舰体" % width,Vector2(x+18,y+207),16,MUTED)
			weapon(Vector2(x+326,y+270),49,physical,0)
			label("独立挂件近看",Vector2(x+18,y+294),14,MUTED)
	label("无开火闪光、弹道或盾光圈辅助识别；比较居中的窄长轮廓与两侧分开的宽短轮廓。",Vector2(28,852),17,MUTED)

func shot(p: Vector2, physical: bool, scale_value: float) -> void:
	var length := 33.0*scale_value
	if physical:
		draw_line(p,p+Vector2(0,length),Color("94765b"),maxf(1,2*scale_value),true)
		draw_style_box(projectile_style(),Rect2(p+Vector2(-2.7*scale_value,length),Vector2(5.4,11)*scale_value))
		for i in 3:draw_circle(p+Vector2((i-1)*4*scale_value,-float(i)*5*scale_value),maxf(0.6,(3-i)*scale_value),Color("a4a5a5",0.25))
	else:
		draw_line(p,p+Vector2(0,length),Color(ENERGY,0.25),maxf(2,5*scale_value),true)
		draw_line(p,p+Vector2(0,length),Color("c7f6ff"),maxf(1,1.5*scale_value),true)
		draw_line(p+Vector2(0,length+5*scale_value),p+Vector2(0,length+13*scale_value),ENERGY,maxf(1,2.5*scale_value),true)

func projectile_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=Color("ffc184")
	style.set_corner_radius_all(2)
	return style

func draw_small() -> void:
	label("正常窗口识别检查 · 1373 × 883",Vector2(28,40),26)
	label("左侧沿用 572 × 960 逻辑战场缩放；原组1002的5列3行，未改阵型。",Vector2(28,70),17,MUTED)
	var origin := Vector2(28,105)
	var screen_scale := 1373.0/1952.0
	card(Rect2(origin,Vector2(572,960)*screen_scale))
	var slots: Array=data.groups["1002"].slots
	for i in slots.size():
		if slots[i]==null:continue
		var row: Dictionary=data.enemies[str(int(slots[i]))]
		var point := Vector2(66+float(i%5)*110,94+float(i/5)*144)*screen_scale+origin
		ship(row,point,normal_width(row),"laser_mon",false)
	label("原群聚组 · 正常尺寸",origin+Vector2(18,649),16,MUTED)
	var ids := [1046,1088,1017,1019]
	var names := ["橙色物理防护","大型能量盾","恢复盾回补中","中性舰体"]
	for i in 4:
		var x := 476.0+float(i%2)*435
		var y := 105.0+float(i/2)*330
		card(Rect2(x,y,403,304))
		label(names[i],Vector2(x+18,y+33),20)
		var row: Dictionary=data.enemies[str(ids[i])]
		ship(row,Vector2(x+112,y+164),normal_width(row),"laser_mon",false,i==3)
		ship(row,Vector2(x+288,y+164),normal_width(row),"cannon-mon",false,i==3)
		label("能量炮口",Vector2(x+76,y+265),15,MUTED)
		label("物理炮口",Vector2(x+252,y+265),15,MUTED)
	label("右侧以同一防御体型搭配两种进攻挂件；无颜色也应从单管/双叉与肩甲/盾节点识别。",Vector2(476,810),16,MUTED)
	label("恢复分片见关键状态图；正式战斗节奏仍需验收。",Vector2(476,844),16,MUTED)

func draw_recovery() -> void:
	label("恢复盾关键状态 · 读取敌人1017的延迟与恢复率",Vector2(28,40),26)
	label("预览内存时间线：受击失盾 → 等待 → 回补 → 满盾；不运行战斗，不改任何表。",Vector2(28,72),17,MUTED)
	var row: Dictionary=data.enemies["1017"]
	var fraction := clampf(0.4+maxf(0,clock-float(row.shieldDelay))*float(row.shieldRecovery),0,1)
	var healing := clock>=float(row.shieldDelay) and fraction<1
	var stages := ["刚受击 / 分片等待","延迟结束 / 向内回补","满盾 / 动态停止","破盾 / 保留物甲"]
	for i in 4:
		var x := 24.0+float(i)*337
		card(Rect2(x,110,314,623))
		label(stages[i],Vector2(x+16,146),18)
		var f := 0.4 if i==0 else fraction if i==1 else 1.0 if i==2 else 0.0
		ship(row,Vector2(x+157,326),108,"laser_mon",false,false,f,healing if i==1 else false)
		label("正常窗口尺寸",Vector2(x+16,490),16,MUTED)
		ship(row,Vector2(x+157,583),normal_width(row),"laser_mon",false,false,f,healing if i==1 else false)
		label("盾量 %d%%" % roundi(f*100),Vector2(x+16,704),17,REPAIR)
	label("分段轮廓填充对应盾量；节点向舰体流动只在实际回补时出现，等待/满盾/破盾停止。",Vector2(28,787),19)
	label("示意时间 %.1fs · shieldDelay=%.1fs · shieldRecovery=%.1f/s" % [clock,float(row.shieldDelay),float(row.shieldRecovery)],Vector2(28,828),17,MUTED)
