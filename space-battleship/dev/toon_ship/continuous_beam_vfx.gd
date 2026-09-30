extends RefCounted
## Presentation-only sustained beam. Call from a CanvasItem draw callback.
## The caller owns validity, charge/ticks gating, actual moving muzzle/target,
## and beam_style width/power/pulse. No targeting, timing, damage or RNG here.
const ENERGY := Color("66efd9")
const CORE := Color("edfff9")

static func charge(surface: CanvasItem, muzzle: Vector2, target: Vector2, amount: float, clock: float) -> void:
	if not muzzle.is_finite() or not target.is_finite() or not is_finite(amount) or not is_finite(clock):
		return
	var progress := clampf(amount, 0.0, 1.0)
	var direction := (target - muzzle).normalized()
	if direction.length_squared() < 0.5:
		direction = Vector2.UP
	var across := direction.orthogonal()
	var radius := lerpf(14.0, 6.0, progress)
	# Energy converges at the actual emitter. No target contact before first hit.
	surface.draw_circle(muzzle, 4.0 + progress * 3.0, Color(ENERGY, 0.12 + progress * 0.16))
	surface.draw_circle(muzzle, 1.3 + progress * 1.3, Color(CORE, 0.45 + progress * 0.5))
	for side in [-1.0, 1.0]:
		var start: Vector2 = muzzle + across * side * radius - direction * 4.0
		var bend: Vector2 = muzzle + across * side * radius * 0.5 + direction * 2.0
		surface.draw_polyline(PackedVector2Array([start, bend, muzzle]), Color(ENERGY, 0.3 + progress * 0.5), 1.3, true)
	var angle := clock * 1.2
	surface.draw_arc(muzzle, radius, angle, angle + PI * (0.3 + progress * 0.6), 16, Color(ENERGY, 0.45), 1.2, true)

static func active(surface: CanvasItem, muzzle: Vector2, target: Vector2, clock: float, width: float, power: float, pulse: float = 0.0) -> void:
	if not muzzle.is_finite() or not target.is_finite() or not is_finite(clock):
		return
	if not is_finite(width) or not is_finite(power) or not is_finite(pulse) or width <= 0.0:
		return
	var delta := target - muzzle
	var distance := delta.length()
	if distance < 0.5:
		return
	var direction := delta / distance
	var across := direction.orthogonal()
	var intensity := clampf(power, 0.0, 1.0)
	var hit_pulse := clampf(pulse, 0.0, 1.0)
	# Width is derived by the existing renderer from actual ramp state.
	var body_width := maxf(1.0, width)
	var core_width := maxf(0.8, body_width * 0.28)
	# Stable, unbroken core distinguishes this from finite short laser packets.
	# Low-alpha envelopes stay narrow so several beams do not wash out the hull.
	surface.draw_line(muzzle, target, Color(ENERGY, 0.075 + intensity * 0.035), body_width * 2.1, true)
	surface.draw_line(muzzle, target, Color(ENERGY, 0.34 + intensity * 0.13), body_width, true)
	surface.draw_line(muzzle, target, Color(CORE, 0.8 + hit_pulse * 0.16), core_width, true)
	# Sparse internal energy flow, never stored flight ribbons or random impacts.
	var segment_length := minf(14.0, distance * 0.07)
	for index in 3:
		var phase := fposmod(clock * 0.85 + float(index) / 3.0, 1.0)
		var along := phase * maxf(0.0, distance - segment_length)
		var offset := across * sin(clock * 2.0 + float(index) * 2.1) * body_width * 0.22
		var start: Vector2 = muzzle + direction * along + offset
		surface.draw_line(start, start + direction * segment_length, Color(CORE, 0.16), maxf(0.7, core_width * 0.55), true)
	surface.draw_circle(muzzle, body_width * 0.63, Color(ENERGY, 0.27))
	surface.draw_circle(muzzle, core_width * 0.75, Color(CORE, 0.85))
	_contact(surface, target, direction, body_width, intensity, hit_pulse, clock)

static func _contact(surface: CanvasItem, point: Vector2, direction: Vector2, width: float, power: float, pulse: float, clock: float) -> void:
	var across := direction.orthogonal()
	# This is sustained contact energy, not a synthetic per-frame hit event.
	# Only the supplied real hit pulse changes its emphasis.
	var radius := 3.5 + width * 0.38 + power * 1.0 + pulse * 1.8
	surface.draw_circle(point, radius * 1.25, Color(ENERGY, 0.11 + pulse * 0.07))
	var ring := PackedVector2Array()
	for index in 25:
		var angle := TAU * float(index) / 24.0
		ring.append(point + across * cos(angle) * radius + direction * sin(angle) * radius * 0.42)
	surface.draw_polyline(ring, Color(ENERGY, 0.56 + pulse * 0.18), 1.2, true)
	surface.draw_circle(point, 1.7 + width * 0.12 + pulse * 0.65, Color(CORE, 0.92))
	# Two short, slowly moving contact filaments keep the endpoint localized.
	for side in [-1.0, 1.0]:
		var shift := sin(clock * 3.0 + side) * 0.8
		var tip: Vector2 = point + across * side * radius * 1.3 - direction * (1.5 + shift)
		surface.draw_line(point + across * side * radius * 0.65, tip, Color(ENERGY, 0.4 + pulse * 0.25), 1.0, true)
