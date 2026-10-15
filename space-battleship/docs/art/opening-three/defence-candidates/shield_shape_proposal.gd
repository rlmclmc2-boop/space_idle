extends "res://scripts/enemy_recognition_visual.gd"
## Review-only paint proposal. No entity updates, timing, or envelope changes.
func draw_protection(surface: CanvasItem, enemy: Dictionary, width: float, packet: Dictionary, status: Dictionary, shield_clock: float, opening_readability := false) -> PackedVector2Array:
	var result=super.draw_protection(surface,enemy,width,packet,status,shield_clock,opening_readability)
	if not status.alive or not status.active:return result
	var kind=int(enemy.get("shieldType",0))
	if kind not in [1,2]:return result
	var hull_visible:bool=status.show_hull and int(enemy.get("armourType",0)) in [1,2]
	var outline:PackedVector2Array=packet.outer if hull_visible else packet.inner
	var span=maxf(2.4/packet.scale,minf(width*0.085,5.0/packet.scale))
	var stroke=maxf(1.1/packet.scale,packet.shield_stroke)
	var color=Color(shield_color(kind),0.9)
	for side in [-1,1]:
		var edge=(outline[1]+outline[2])*0.5 if side==1 else (outline[4]+outline[5])*0.5
		var center=edge-Vector2(side*(span+stroke),0)
		if kind==2:
			for offset in [-0.65,0.65]:
				surface.draw_line(center+Vector2(-span,offset*span),center+Vector2(span,offset*span),color,stroke,true)
		else:
			surface.draw_polyline(PackedVector2Array([center+Vector2(0,-span),center+Vector2(span,0),center+Vector2(0,span),center+Vector2(-span,0),center+Vector2(0,-span)]),color,stroke,true)
	return result
