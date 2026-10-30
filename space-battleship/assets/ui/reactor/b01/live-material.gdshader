shader_type canvas_item;
render_mode unshaded;

uniform sampler2D active_plate : source_color, filter_linear;
uniform float core_load = 0.0;
uniform float weapons_load = 0.0;
uniform float defence_load = 0.0;
uniform float smelting_load = 0.0;
uniform float condensation_load = 0.0;
uniform float phase = 0.0;

float ellipse(vec2 uv, vec2 center, vec2 radius, float feather) {
	float d = length((uv - center) / radius);
	return 1.0 - smoothstep(1.0 - feather, 1.0 + feather, d);
}

float segment(vec2 uv, vec2 a, vec2 b, float width) {
	vec2 ab = b - a;
	float t = clamp(dot(uv - a, ab) / dot(ab, ab), 0.0, 1.0);
	return 1.0 - smoothstep(width * 0.6, width, distance(uv, a + ab * t));
}

void fragment() {
	vec2 uv = UV;
	vec4 idle = texture(TEXTURE, uv);
	vec4 active = texture(active_plate, uv);
	float core = ellipse(uv, vec2(0.5, 0.255), vec2(0.19, 0.17), 0.10);
	core = max(core, ellipse(uv, vec2(0.5, 0.095), vec2(0.047, 0.09), 0.15));
	float weapon = max(ellipse(uv, vec2(0.16, 0.145), vec2(0.17, 0.10), 0.16), segment(uv, vec2(0.32, 0.17), vec2(0.41, 0.215), 0.024));
	float shield = max(ellipse(uv, vec2(0.90, 0.145), vec2(0.14, 0.11), 0.17), segment(uv, vec2(0.69, 0.215), vec2(0.78, 0.17), 0.024));
	float iron = max(ellipse(uv, vec2(0.15, 0.385), vec2(0.17, 0.11), 0.17), segment(uv, vec2(0.32, 0.335), vec2(0.42, 0.29), 0.025));
	float crystal = max(ellipse(uv, vec2(0.86, 0.385), vec2(0.15, 0.12), 0.17), segment(uv, vec2(0.68, 0.29), vec2(0.78, 0.34), 0.025));
	float p = max(core * core_load, max(weapon * weapons_load, max(shield * defence_load, max(iron * smelting_load, crystal * condensation_load))));
	p = p > 0.0 ? min(1.0, 0.70 + p * 0.30) * min(1.0, p * 8.0) : 0.0;
	vec3 color = mix(idle.rgb, active.rgb, p);
	float live = step(0.0001, core_load);
	float radial = length((uv - vec2(0.5, 0.255)) / vec2(0.18, 0.16));
	float ring = exp(-pow((radial - (0.48 + 0.13 * sin(phase * 1.8))) * 7.0, 2.0));
	float swirl = sin(atan(uv.y - 0.255, uv.x - 0.5) * 4.0 + radial * 13.0 - phase * 2.7);
	float pulse = core * live * (0.045 + 0.055 * ring + 0.035 * swirl) * (0.6 + 0.4 * core_load);
	color += vec3(0.13, 0.72, 1.0) * pulse;
	float packet = 0.5 + 0.5 * sin(phase * 6.0 - uv.x * 65.0 - uv.y * 22.0);
	color += vec3(0.08, 0.55, 0.92) * packet * 0.045 * max(weapon * weapons_load, max(shield * defence_load, max(iron * smelting_load, crystal * condensation_load)));
	COLOR = vec4(color, idle.a);
}
