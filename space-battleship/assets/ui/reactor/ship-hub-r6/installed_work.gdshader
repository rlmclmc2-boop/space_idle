shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform int module_kind = 0;
uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform vec4 tint : source_color = vec4(0.9, 0.6, 0.25, 1.0);

float glass_mask(vec2 uv) {
	if (module_kind == 2) {
		float lower_edge = 0.97 - 0.73 * uv.x;
		return smoothstep(0.0, 0.04, uv.x) * (1.0 - smoothstep(0.80, 0.89, uv.x)) * (1.0 - smoothstep(lower_edge - 0.045, lower_edge + 0.025, uv.y));
	}
	if (module_kind == 3) {
		float lower_edge = 0.23 + 0.72 * uv.x;
		return smoothstep(0.12, 0.20, uv.x) * (1.0 - smoothstep(lower_edge - 0.04, lower_edge + 0.025, uv.y));
	}
	return 1.0;
}

void fragment() {
	float strength = pow(clamp(power, 0.0, 1.0), 0.35);
	float structure = 0.0;
	if (module_kind == 0) {
		float rail = min(abs(UV.y - 0.28), min(abs(UV.y - 0.50), abs(UV.y - 0.72)));
		structure = 1.0 - smoothstep(0.018, 0.07, rail);
	} else if (module_kind == 1) {
		vec2 grid = UV * vec2(7.0, 4.0);
		grid.x += 0.5 * mod(floor(grid.y), 2.0);
		vec2 cell = abs(fract(grid) - 0.5);
		float wall = max(cell.x * 0.866 + cell.y * 0.5, cell.y);
		structure = 1.0 - smoothstep(0.025, 0.08, abs(wall - 0.43));
	} else if (module_kind == 2) {
		structure = 1.0 - smoothstep(0.08, 0.24, abs(fract(UV.x * 6.0) - 0.5));
	} else {
		vec2 focus = vec2(0.56, 0.40);
		float inward = 1.0 - smoothstep(0.10, 0.32, abs(UV.x - focus.x));
		float lens = 1.0 - smoothstep(0.07, 0.24, length((UV - focus) * vec2(1.0, 1.7)));
		structure = max(inward * 0.55, lens);
	}
	float alpha = strength * (0.10 + structure * 0.25) * glass_mask(UV);
	vec3 lit = mix(vec3(0.025, 0.09, 0.12), tint.rgb, 0.34 + structure * 0.36);
	COLOR = vec4(lit, alpha);
}
