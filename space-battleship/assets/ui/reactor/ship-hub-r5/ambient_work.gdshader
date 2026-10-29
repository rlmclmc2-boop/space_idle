shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.05, 1.18);
	float radial = exp(-dot(p, p) * 5.0);
	float spoke = exp(-pow(abs(abs(p.x) - abs(p.y)) * 10.0, 2.0)) * smoothstep(0.18, 0.42, length(p));
	float activity = 0.88 + 0.12 * sin(phase * 1.3);
	float glow = sqrt(clamp(power, 0.0, 1.0)) * activity * (radial * 0.22 + spoke * radial * 0.11);
	COLOR = vec4(vec3(0.22, 0.71, 0.86), glow);
}
