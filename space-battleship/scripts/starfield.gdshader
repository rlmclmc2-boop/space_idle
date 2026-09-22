shader_type canvas_item;
render_mode unshaded;
uniform float travel = 0.0;
uniform float streak = 0.0;
uniform float speed = 1.0;
varying vec2 local_pos;
varying float radius;
varying float tail;
varying float opacity;

void vertex() {
	float depth = COLOR.r;
	radius = depth * 1.35;
	tail = depth * 9.0 * speed * streak;
	opacity = 0.2 + depth * 0.5;
	local_pos = vec2(mix(-radius - 0.5, max(radius, tail) + 0.5, UV.x),
		mix(-radius - 0.5, radius + 0.5, UV.y));
	VERTEX = vec2(mod(COLOR.g * 1440.0 - travel * depth * 4.0, 1440.0),
		COLOR.b * 810.0) + local_pos;
}
void fragment() {
	float dot_alpha = (1.0 - smoothstep(radius - 0.35, radius + 0.35, length(local_pos))) * opacity;
	float line_alpha = (1.0 - smoothstep(0.25, 0.75, abs(local_pos.y))) *
		step(0.0, local_pos.x) * step(local_pos.x, tail) * opacity * 0.3 * streak;
	float a = line_alpha + dot_alpha * (1.0 - line_alpha);
	vec3 rgb = (vec3(0.5,0.8,1.0) * line_alpha + vec3(0.7,0.83,1.0) * dot_alpha * (1.0-line_alpha)) / max(a,0.0001);
	COLOR = vec4(rgb,a);
}
