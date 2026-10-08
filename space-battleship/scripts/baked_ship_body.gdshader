shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D body_texture : source_color, filter_linear, repeat_disable;

void fragment() {
	vec4 body = texture(body_texture, UV);
	ALBEDO = body.rgb;
	ALPHA = body.a;
	ALPHA_SCISSOR_THRESHOLD = 0.01;
}

// Self-lighting and self-shadow are already in the asset. Do not apply another
// light/shadow response to its color; that darkened the original candidate.
