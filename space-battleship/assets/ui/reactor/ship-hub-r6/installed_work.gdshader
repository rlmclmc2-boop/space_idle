shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform int module_kind = 0;
uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform vec4 tint : source_color = vec4(0.9, 0.6, 0.25, 1.0);

void fragment() {
	float strength = pow(clamp(power, 0.0, 1.0), 0.35);
	float detail = 0.0;
	if (module_kind == 0) {
		float packet = fract(UV.x * 3.0 - phase * 0.9);
		detail = (1.0 - smoothstep(0.04, 0.22, packet)) * (1.0 - smoothstep(0.12, 0.48, abs(UV.y - 0.5)));
	} else if (module_kind == 1) {
		vec2 cell = abs(fract(UV * vec2(6.0, 4.0)) - 0.5);
		detail = (1.0 - smoothstep(0.28, 0.46, max(cell.x, cell.y))) * (0.4 + 0.6 * sin(phase * 2.1 + UV.x * 8.0));
	} else if (module_kind == 2) {
		float ribs = 1.0 - smoothstep(0.14, 0.37, abs(fract(UV.x * 7.0) - 0.5));
		detail = ribs * (0.42 + 0.58 * sin(phase * 2.0 - UV.y * 10.0));
	} else {
		float ring = abs(fract(length(UV - vec2(0.5)) * 5.0 + phase * 0.58) - 0.5);
		detail = 1.0 - smoothstep(0.07, 0.22, ring);
	}
	float shade = 0.72 * (1.0 - strength);
	float flare = strength * (0.20 + max(0.0, detail) * 0.50);
	vec3 filter_color = mix(vec3(0.015, 0.055, 0.075), tint.rgb, flare);
	COLOR = vec4(filter_color, shade + flare * 0.60);
}
