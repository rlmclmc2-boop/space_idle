extends RefCounted

# Presentation only. Cooldowns and projectile positions remain owned by BattleGame.
var charge_time := 0.24
var arc_intensity := 0.65
var rail_glow := 0.7
var muzzle_flash := 0.8
var trail_length := 52.0
var trail_lifetime := 0.065
var impact_intensity := 0.8
var player_charge_time := 0.9

func configure(db) -> void:
	player_charge_time=db.weapon_motion_value("rail_charge_seconds",player_charge_time)

func player_charge(remaining: float, cooldown_multiplier: float, base_period: float) -> float:
	var window := minf(player_charge_time,base_period)*cooldown_multiplier
	return clampf(1.0-remaining/maxf(0.001,window),0.0,1.0) if remaining>0.0 else 0.0

const ICE := Color("9eeaff")

func charge(remaining: float, speed: float) -> float:
	return clampf(1.0-remaining/maxf(0.001,charge_time*speed),0.0,1.0) if remaining>0.0 else 0.0

func draw_rails(surface: CanvasItem, width: float, progress: float, afterglow: float, time: float, seed_value: int, screen_scale: float) -> void:
	var energy := clampf(rail_glow,0.0,1.5)
	var hairline := 0.65/maxf(0.01,screen_scale)
	for side in [-1.0,1.0]:
		for segment in 6:
			var phase := float(segment)/6.0
			var lit := smoothstep(phase,phase+0.17,progress)
			var a := Vector2(lerpf(-0.23,0.40,phase),side*0.065)*width
			var b := a+Vector2(width*0.075,0)
			var alpha := minf(0.86,(0.14+lit*0.56+afterglow*0.4)*energy)
			surface.draw_line(a,b,Color(ICE,alpha),maxf(width*0.018,hairline),true)
	# Hash-based flicker never consumes the combat random stream.
	var tick := int(time*27.0)
	var noise := posmod(hash(Vector2i(tick,seed_value)),997)/997.0
	if noise<clampf(arc_intensity,0.0,1.0)*(progress*0.5+afterglow*0.22):
		var x := width*lerpf(-0.17,0.40,progress*0.8+noise*0.2)
		var a := Vector2(x,-width*0.07)
		var b := Vector2(x+width*0.025,width*0.07)
		surface.draw_polyline(PackedVector2Array([a,a.lerp(b,0.35)+Vector2(width*0.04,0),a.lerp(b,0.7)-Vector2(width*0.025,0),b]),Color(ICE,0.65),maxf(hairline,width*0.012),true)
	if progress>0.82:
		var focus := (progress-0.82)/0.18
		var points := PackedVector2Array()
		for i in 17:
			var angle := float(i)*TAU/16.0
			points.append(Vector2(width*0.43+cos(angle)*width*0.027,sin(angle)*width*lerpf(0.14,0.07,focus)))
		surface.draw_polyline(points,Color(ICE,focus*0.7),maxf(hairline,width*0.012),true)

func draw_flight(surface: CanvasItem, pos: Vector2, heading: Vector2, distance: float, speed: float) -> void:
	var length := minf(distance,minf(clampf(trail_length,0.0,90.0),speed*clampf(trail_lifetime,0.01,0.12)))
	for i in 7:
		var a := float(i)/7.0
		var b := float(i+1)/7.0
		surface.draw_line(pos-heading*length*a,pos-heading*length*b,Color(ICE,pow(1.0-a,2)*0.65),1.15,true)
	# A small solid core, never a persistent muzzle-to-target beam.
	surface.draw_line(pos-heading*3.0,pos+heading*2.0,Color("effcff"),0.85,true)

func draw_contact(surface: CanvasItem, pos: Vector2, age: float, direction: Vector2) -> void:
	var strength := clampf(impact_intensity,0.0,1.5)
	if age<0.04:
		var fade := 1.0-age/0.04
		surface.draw_line(pos-direction*3.0,pos+direction*5.0,Color(ICE,fade),2.2*strength,true)
		surface.draw_circle(pos,1.7*strength,Color(1,1,1,fade))
	elif age<0.18:
		var t := (age-0.04)/0.14
		for i in 3:
			var ray := direction.rotated((float(i)-1.0)*0.6)
			var end := pos+ray*(3.0+t*13.0)*strength
			surface.draw_line(end-ray*3.0,end,Color(Color("c7dce7") if i!=1 else ICE,1.0-t),0.9,true)
		var a := pos+direction.orthogonal()*4.0*strength
		var b := pos-direction.orthogonal()*4.0*strength
		surface.draw_polyline(PackedVector2Array([a,pos+direction*(2.0+sin(age*180.0)*2.0),b]),Color(ICE,(1.0-t)*0.5),0.7,true)
		# Two tiny broken arcs communicate a local shock without an explosion disc.
		for side in 2:
			surface.draw_arc(pos,(3.0+t*5.0)*strength,float(side)*PI+0.3,float(side)*PI+1.1,6,Color(ICE,(1.0-t)*0.28),0.7,true)

static func sound(kind: String) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format=AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate=22050
	var duration := 0.1 if kind=="charge" else 0.14 if kind=="release" else 0.12
	var count := int(duration*wav.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed=1729
	for i in count:
		var t := float(i)/wav.mix_rate
		var value := 0.0
		if kind=="charge":
			value=sin(TAU*620.0*t)*0.24+sin(TAU*1240.0*t)*0.07
		else:
			var attack := minf(1.0,t/0.001)
			var decay := exp(-t*(42.0 if kind=="release" else 48.0))*(1.0-t/duration)
			var tone := sin(TAU*(2100.0*t-4800.0*t*t))*0.25 if kind=="release" else (sin(TAU*1730.0*t)+sin(TAU*2873.0*t))*0.16
			value=attack*decay*(tone+rng.randf_range(-1,1)*0.38*exp(-t*140.0)+sin(TAU*140.0*t)*0.12)
		bytes.encode_s16(i*2,int(clampf(value,-0.95,0.95)*32767.0))
	wav.data=bytes
	if kind=="charge":
		wav.loop_mode=AudioStreamWAV.LOOP_FORWARD
		wav.loop_end=count
	return wav
