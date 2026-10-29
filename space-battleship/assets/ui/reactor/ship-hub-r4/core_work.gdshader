shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;

void fragment() {
	vec2 canvas = vec2(264.0, 264.0);
	vec2 center = vec2(132.0, 132.0);
	vec2 p = (UV * canvas - center) / 132.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float border = 1.0 - smoothstep(0.88, 0.98, r);
	float spin = 0.032 * sin(phase * 0.9 + r * 5.0);
	float ca = cos(spin);
	float sa = sin(spin);
	vec2 moved = vec2(p.x * ca - p.y * sa, p.x * sa + p.y * ca);
	moved += 0.017 * vec2(sin(phase * 1.1 + p.y * 9.0), cos(phase * 0.8 + p.x * 7.0)) * (1.0 - r);
	vec2 sample_uv = (center + moved * 132.0) / canvas;
	vec3 art = texture(TEXTURE, sample_uv).rgb;
	float river = pow(max(0.0, sin(angle * 5.0 - phase * 1.65 + r * 13.0)), 7.0) * 0.28;
	float counter = pow(max(0.0, sin(angle * 7.0 + phase * 1.12 - r * 10.0)), 8.0) * 0.23;
	float heart = exp(-r * r * 20.0) * (0.13 + 0.05 * sin(phase * 2.0));
	float orbit = exp(-pow(r - 0.51 - 0.027 * sin(angle * 4.0 - phase), 2.0) * 190.0) * (0.07 + 0.08 * sin(angle * 3.0 + phase * 1.4));
	vec3 energy = art + vec3(0.18, 0.77, 0.98) * (river + counter + orbit) + vec3(0.50, 0.45, 0.18) * heart;
	COLOR = vec4(energy, border * pow(clamp(power, 0.0, 1.0), 0.55));
}
