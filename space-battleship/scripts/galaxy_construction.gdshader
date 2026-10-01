shader_type spatial;
render_mode cull_back;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 lamp : source_color = vec3(0.0);
uniform float roughness_value = 0.6;
uniform float metallic_value = 0.1;
uniform bool vertex_tint = false;
instance uniform float construction_height = 1000.0;
varying float world_height;
void vertex() {
	world_height=(MODEL_MATRIX*vec4(VERTEX,1.0)).y;
}
void fragment() {
	if(world_height>construction_height)discard;
	ALBEDO=tint.rgb*(vertex_tint ? COLOR.rgb : vec3(1.0));
	EMISSION=lamp;
	ROUGHNESS=roughness_value;
	METALLIC=metallic_value;
}
