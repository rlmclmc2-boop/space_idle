shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float power : hint_range(0.0, 1.0) = 0.0;
uniform int kind = 0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float interior = 1.0 - smoothstep(0.72, 0.96, length(p));
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	float cyan_emission = smoothstep(0.32, 0.72, max(source.g, source.b))
		* smoothstep(0.08, 0.25, source.b - source.r);
	float amber_emission = smoothstep(0.48, 0.82, source.r)
		* smoothstep(0.13, 0.35, source.r - source.b)
		* smoothstep(0.08, 0.25, source.g - source.b);
	float chroma = max(source.r, max(source.g, source.b)) - min(source.r, min(source.g, source.b));
	float white_emission = smoothstep(0.48, 0.84, dot(source, vec3(0.21, 0.72, 0.07)))
		* (1.0 - smoothstep(0.12, 0.28, chroma));
	float emission = max(max(cyan_emission, amber_emission), white_emission * float(kind == 0));
	float attenuation = (kind == 0 ? 0.72 : 0.88) * (1.0 - smoothstep(0.0, 0.20, power));
	COLOR = vec4(source * (1.0 - emission * attenuation), interior);
}
