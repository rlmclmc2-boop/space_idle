shader_type canvas_item;
render_mode unshaded, blend_add;

uniform int module_kind = 0;
uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform vec4 tint : source_color = vec4(0.95, 0.65, 0.32, 1.0);

float glass_mask(vec2 uv) {
	if (module_kind == 0) {
		float left_edge = 0.04 + 0.045 * uv.y * uv.y;
		float right_edge = 0.965 - 0.02 * uv.y * uv.y;
		float sides = smoothstep(left_edge, left_edge + 0.035, uv.x) * (1.0 - smoothstep(right_edge - 0.035, right_edge, uv.x));
		return sides * smoothstep(0.025, 0.07, uv.y) * (1.0 - smoothstep(0.91, 0.98, uv.y));
	}
	if (module_kind == 1) {
		float left_edge = 0.035 + 0.02 * uv.y;
		float right_edge = 0.93 - 0.015 * uv.y;
		float lower_edge = 1.03 - 0.16 * uv.x;
		float sides = smoothstep(left_edge, left_edge + 0.03, uv.x) * (1.0 - smoothstep(right_edge - 0.035, right_edge, uv.x));
		return sides * smoothstep(0.025, 0.07, uv.y) * (1.0 - smoothstep(lower_edge - 0.04, lower_edge + 0.015, uv.y));
	}
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
	float motion = 0.0;
	if (module_kind == 0) {
		float rail = min(abs(UV.y - 0.28), min(abs(UV.y - 0.50), abs(UV.y - 0.72)));
		float channels = 1.0 - smoothstep(0.015, 0.075, rail);
		float packet = fract(UV.x * 2.4 + phase * 0.85);
		float leading = 1.0 - smoothstep(0.04, 0.29, packet);
		motion = channels * (0.24 + leading * 0.76);
	} else if (module_kind == 1) {
		vec2 grid = UV * vec2(7.0, 4.0);
		grid.x += 0.5 * mod(floor(grid.y), 2.0);
		vec2 cell = abs(fract(grid) - 0.5);
		float wall = max(cell.x * 0.866 + cell.y * 0.5, cell.y);
		float mesh = 1.0 - smoothstep(0.018, 0.07, abs(wall - 0.43));
		float sweep = 0.5 + 0.5 * sin(phase * 2.0 - UV.x * 10.0);
		motion = mesh * (0.35 + sweep * 0.65);
	} else if (module_kind == 2) {
		float grate = 1.0 - smoothstep(0.08, 0.24, abs(fract(UV.x * 6.0) - 0.5));
		float heat = 0.5 + 0.5 * sin(phase * 3.0 - UV.y * 12.0 + floor(UV.x * 6.0) * 1.4);
		motion = grate * (0.24 + heat * 0.76);
	} else {
		vec2 convergence = vec2(0.56, 0.40);
		float diagonal_a = 1.0 - smoothstep(0.025, 0.09, abs(UV.y - (convergence.y + (UV.x - convergence.x) * 0.55)));
		float diagonal_b = 1.0 - smoothstep(0.025, 0.09, abs(UV.y - (convergence.y - (UV.x - convergence.x) * 0.55)));
		float focus = 1.0 - smoothstep(0.04, 0.19, length((UV - convergence) * vec2(1.0, 1.8)));
		float gather = 0.78 + 0.22 * sin(phase * 2.4 + length(UV - convergence) * 12.0);
		motion = max(max(diagonal_a, diagonal_b) * 0.75, focus * 1.5) * gather;
	}
	float vertical_fade = smoothstep(0.01, 0.10, UV.y) * (1.0 - smoothstep(0.90, 1.0, UV.y));
	COLOR = vec4(tint.rgb, strength * motion * 0.86 * vertical_fade * glass_mask(UV));
}
