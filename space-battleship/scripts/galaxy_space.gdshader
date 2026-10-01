shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D explored : filter_linear, repeat_disable;
uniform sampler2D field : source_color, filter_linear, repeat_disable;
varying vec2 space_position;
void vertex() { space_position=VERTEX.xz; }
void fragment() {
	// One static opaque field replaces per-pixel trigonometry, powers and star noise.
	// Compact fog remains compatibility presentation, never a placement authority.
	vec2 field_uv=space_position/420.0+vec2(0.5);
	vec2 map_uv=space_position/260.0+vec2(0.5);
	float control=texture(explored,map_uv).r;
	ALBEDO=texture(field,field_uv).rgb+vec3(0.006,0.012,0.014)*control;
}
