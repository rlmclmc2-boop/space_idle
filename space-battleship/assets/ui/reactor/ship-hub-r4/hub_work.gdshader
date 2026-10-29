shader_type canvas_item;
render_mode unshaded, blend_add;

uniform int kind = 0; // 0 core, 1 port, 2 conduit
uniform int module_kind = 0; // stable reactor module order
uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform vec4 tint : source_color = vec4(0.2, 0.78, 0.9, 1.0);

void fragment() {
	float strength = clamp(power, 0.0, 1.0);
	if (strength <= 0.001) {
		COLOR = vec4(0.0);
	} else if (kind == 0) {
		vec2 p = (UV - vec2(0.5)) * 2.0;
		float r = length(p);
		float edge = 1.0 - smoothstep(0.87, 0.98, r);
		float angle = atan(p.y, p.x);
		float swirl = sin(angle * 4.0 + r * 12.0 - phase * 1.7 + sin(r * 8.0 + phase) * 0.7);
		float counter = sin(angle * 7.0 - r * 10.0 + phase * 1.05);
		float nested = sin(r * 19.0 - phase * 1.3 + swirl * 1.2);
		float filament = pow(max(0.0, swirl * counter), 2.0) * 0.43 + pow(max(0.0, nested), 5.0) * 0.30;
		float inner_flow = exp(-pow(r - 0.47 - 0.055 * swirl, 2.0) * 95.0) * 0.28;
		float halo = (1.0 - smoothstep(0.10, 0.96, r)) * 0.54;
		float heart = exp(-r * r * 27.0) * 0.68;
		vec3 color = mix(vec3(0.06, 0.42, 0.56), vec3(0.55, 0.96, 1.0), clamp(filament + heart, 0.0, 1.0));
		color += vec3(0.37, 0.22, 0.07) * heart;
		COLOR = vec4(color, edge * strength * (halo + filament + inner_flow + heart));
	} else if (kind == 1) {
		vec2 p = UV - vec2(0.5);
		float envelope = (1.0 - smoothstep(0.37, 0.49, length(p))) * (1.0 - smoothstep(0.43, 0.50, abs(p.x)));
		float detail = 0.0;
		if (module_kind == 0) {
			float recoil = fract(UV.x * 4.0 - phase * 1.1);
			detail = (1.0 - smoothstep(0.07, 0.20, recoil)) * (1.0 - smoothstep(0.23, 0.40, abs(p.y)));
		} else if (module_kind == 1) {
			vec2 grid = abs(fract(UV * vec2(5.0, 4.0)) - 0.5);
			float cells = 1.0 - smoothstep(0.28, 0.46, max(grid.x, grid.y));
			detail = cells * (0.45 + 0.55 * sin(phase * 2.4 + UV.x * 9.0));
		} else if (module_kind == 2) {
			float bars = 1.0 - smoothstep(0.17, 0.34, abs(fract(UV.x * 6.0) - 0.5));
			detail = bars * (0.5 + 0.5 * sin(phase * 2.6 - UV.y * 13.0));
		} else {
			float ring = abs(fract(length(p) * 5.0 + phase * 0.7) - 0.5);
			detail = 1.0 - smoothstep(0.08, 0.25, ring);
		}
		float pulse = 0.53 + 0.14 * sin(phase * 1.8 + p.y * 8.0);
		COLOR = vec4(tint.rgb, envelope * sqrt(strength) * (pulse + detail * 0.46));
	} else {
		float width = 1.0 - smoothstep(0.22, 0.49, abs(UV.y - 0.5));
		float ends = smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.92, 1.0, UV.x));
		float head = fract(UV.x * 3.0 - phase * 0.92);
		float packet = 1.0 - smoothstep(0.04, 0.22, head);
		float underglow = 0.34 + 0.14 * sin(UV.x * 14.0 - phase * 2.2);
		COLOR = vec4(tint.rgb, width * ends * sqrt(strength) * (underglow + packet * 1.18));
	}
}
