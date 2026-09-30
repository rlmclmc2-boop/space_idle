shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float engine_emission : hint_range(0.0, 4.0) = 1.4;
uniform float phase = 0.0;

void fragment() {
	float width = abs(UV.x - 0.5) * 2.0;
	float envelope = pow(max(0.0, 1.0 - width), 1.6) * pow(1.0 - UV.y, 1.4);
	float pulse = 0.88 + sin(TIME * 12.0 + phase) * 0.07;
	ALBEDO = mix(vec3(0.015, 0.25, 0.72), vec3(0.25, 0.86, 1.0), envelope);
	EMISSION = ALBEDO * 0.5;
	ALPHA = envelope * pulse * clamp(engine_emission * 0.65, 0.0, 1.0);
}
