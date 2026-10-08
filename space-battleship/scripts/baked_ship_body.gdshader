shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, ambient_light_disabled, specular_disabled;
uniform sampler2D body_texture : source_color, filter_linear, repeat_disable;

void fragment() {
	vec4 body = texture(body_texture, UV);
	ALBEDO = body.rgb;
	ALPHA = body.a;
	ALPHA_SCISSOR_THRESHOLD = 0.01;
}

void light() {
	// The texture already contains the fixed key light and self-shadow.
	// Receive live turret/formation shadows without lighting the image twice.
	DIFFUSE_LIGHT += ALBEDO * mix(0.35, 1.0, ATTENUATION);
}
