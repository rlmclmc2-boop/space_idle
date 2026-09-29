shader_type canvas_item;
render_mode blend_add;

uniform float phase = 0.0;
uniform float power : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x), blend.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float vapor = noise(p * 7.0 + vec2(phase * 0.26, -phase * 0.19));
	float fine = noise(p * 16.0 + vec2(-phase * 0.43, phase * 0.37));
	float filament = pow(max(0.0, sin(angle * 11.0 + radius * 22.0 - phase * 2.7 + vapor * 4.0)), 9.0);
	float sphere = 1.0 - smoothstep(0.59, 0.70, radius);
	float rim = exp(-pow((radius - 0.61) / 0.052, 2.0));
	float heart = exp(-radius * radius * 20.0);
	float highlight = exp(-dot(p - vec2(-0.22, -0.25), p - vec2(-0.22, -0.25)) * 17.0);
	float plasma = sphere * (0.34 + vapor * 0.40 + fine * 0.18 + filament * 0.42);
	float alpha = clamp(plasma + rim * 0.67 + heart * 0.72 + exp(-radius * radius * 2.0) * 0.12, 0.0, 1.0);
	vec3 deep = vec3(0.025, 0.23, 0.63);
	vec3 bright = vec3(0.41, 0.86, 1.0);
	vec3 color = mix(deep, bright, clamp(vapor * 0.6 + filament * 0.8 + rim * 0.32, 0.0, 1.0));
	color += vec3(0.61, 0.94, 1.0) * (heart * 0.83 + highlight * 0.31);
	COLOR = vec4(color * (0.78 + power * 0.48), alpha);
}
