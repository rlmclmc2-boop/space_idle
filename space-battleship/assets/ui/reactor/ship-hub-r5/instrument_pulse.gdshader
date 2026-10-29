shader_type canvas_item;
render_mode unshaded, blend_add;

uniform int module_kind = 0;
uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform vec4 tint : source_color = vec4(0.95, 0.65, 0.32, 1.0);

void fragment() {
	float strength = pow(clamp(power, 0.0, 1.0), 0.43);
	float motion = 0.0;
	float gate = smoothstep(0.05, 0.18, UV.x) * (1.0 - smoothstep(0.82, 0.95, UV.x));
	if (module_kind == 0) {
		float sweep = fract(UV.x * 2.4 - phase * 0.95);
		motion = (1.0 - smoothstep(0.02, 0.19, sweep)) * (1.0 - smoothstep(0.12, 0.45, abs(UV.y - 0.5)));
	} else if (module_kind == 1) {
		float front = abs(fract(length((UV - vec2(0.5)) * vec2(1.3, 1.0)) * 3.2 - phase * 0.54) - 0.5);
		motion = (1.0 - smoothstep(0.04, 0.22, front)) * gate;
	} else if (module_kind == 2) {
		float rib = 1.0 - smoothstep(0.12, 0.34, abs(fract(UV.x * 6.0) - 0.5));
		motion = rib * (0.5 + 0.5 * sin(phase * 2.4 - UV.y * 9.0));
	} else {
		float converge = abs(fract(length(UV - vec2(0.5)) * 4.0 + phase * 0.65) - 0.5);
		motion = (1.0 - smoothstep(0.04, 0.20, converge)) * gate;
	}
	float aperture = smoothstep(0.03, 0.13, UV.y) * (1.0 - smoothstep(0.87, 0.97, UV.y));
	float opacity = strength * aperture * (0.12 + motion * 0.45);
	COLOR = vec4(tint.rgb, opacity);
}
