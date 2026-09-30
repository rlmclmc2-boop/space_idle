shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform float shield_opacity : hint_range(0.0, 0.6) = 0.12;
uniform float impact_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 hit_direction = vec3(-0.45, 0.65, -0.6);
varying vec3 local_point;

void vertex() { local_point = normalize(VERTEX); }

void fragment() {
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.2);
	float distance_to_hit = length(normalize(local_point) - normalize(hit_direction));
	float cap = 1.0 - smoothstep(0.06, 0.64, distance_to_hit);
	float ring = 1.0 - smoothstep(0.02, 0.08, abs(distance_to_hit - (1.0 - impact_strength) * 0.65));
	float impact = impact_strength * (cap * 0.5 + ring * 0.8);
	ALBEDO = mix(vec3(0.06, 0.38, 0.66), vec3(0.45, 0.83, 0.93), impact);
	EMISSION = ALBEDO * 0.3;
	ALPHA = clamp(shield_opacity * (0.06 + edge * 1.6) + impact * shield_opacity * 2.6, 0.0, 0.55);
}
