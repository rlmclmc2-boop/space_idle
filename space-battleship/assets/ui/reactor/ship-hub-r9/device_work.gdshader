shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform int module_kind = 0;
uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform vec4 tint : source_color = vec4(0.9, 0.6, 0.25, 1.0);

float glass_mask(vec2 uv) {
	if (module_kind == 0) {
		float top_axis = 0.20 + 0.16 * uv.x;
		float lower_axis = 0.72 + 0.17 * uv.x;
		float top = (1.0 - smoothstep(0.065, 0.115, abs(uv.y - top_axis))) * smoothstep(0.08, 0.15, uv.x) * (1.0 - smoothstep(0.70, 0.76, uv.x));
		float lower = (1.0 - smoothstep(0.065, 0.115, abs(uv.y - lower_axis))) * smoothstep(0.07, 0.14, uv.x) * (1.0 - smoothstep(0.72, 0.78, uv.x));
		return max(top, lower);
	}
	if (module_kind == 1) {
		float left_edge = 0.32 + 0.01 * uv.y;
		float right_edge = 0.74 - 0.01 * uv.y;
		float lower_edge = 1.03 - 0.16 * uv.x;
		float sides = smoothstep(left_edge, left_edge + 0.03, uv.x) * (1.0 - smoothstep(right_edge - 0.035, right_edge, uv.x));
		return sides * smoothstep(0.025, 0.07, uv.y) * (1.0 - smoothstep(lower_edge - 0.04, lower_edge + 0.015, uv.y));
	}
	if (module_kind == 2) {
		float lower_edge = 0.97 - 0.73 * uv.x;
		return smoothstep(0.0, 0.04, uv.x) * (1.0 - smoothstep(0.80, 0.89, uv.x)) * (1.0 - smoothstep(lower_edge - 0.045, lower_edge + 0.025, uv.y));
	}
	if (module_kind == 3) {
		float crystal = smoothstep(0.48, 0.52, uv.x) * (1.0 - smoothstep(0.71, 0.75, uv.x));
		return crystal * (1.0 - smoothstep(0.66, 0.75, uv.y));
	}
	return 1.0;
}

void fragment() {
	float strength = pow(clamp(power, 0.0, 1.0), 0.35);
	float structure = 0.0;
	if (module_kind == 0) {
		float top_axis = 0.20 + 0.16 * UV.x;
		float lower_axis = 0.72 + 0.17 * UV.x;
		float rail = min(abs(UV.y - top_axis), abs(UV.y - lower_axis));
		structure = 1.0 - smoothstep(0.025, 0.08, rail);
	} else if (module_kind == 1) {
		// The artwork already contains the physical hex lattice. Light its glass,
		// leaving those real cell edges intact instead of drawing a second lattice.
		structure = 0.22 + 0.40 * (1.0 - smoothstep(0.12, 0.53, length((UV - vec2(0.53, 0.48)) * vec2(1.0, 0.75))));
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
